// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {WellstakeToken} from "./WellstakeToken.sol";
import {PendingRequestNFT} from "./PendingRequestNFT.sol";

/// @title WellstakeVault
/// @notice Core V1 accounting contract. Non-upgradeable. Holds pending mint USDC and pending
///         redeem WSK, assigns requests to epochs, finalizes manual NAV, and settles requests
///         permissionlessly after their epoch is finalized.
contract WellstakeVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum RequestType {
        MINT,
        REDEEM
    }

    struct Epoch {
        uint256 navPerToken;
        uint256 startBlock;
        uint256 endBlock;
        bool finalized;
    }

    struct Request {
        RequestType requestType;
        address owner;
        uint256 epoch;
        uint256 amount; // MINT: escrowed USDC. REDEEM: gross WSK.
        uint256 fee; // REDEEM only: WSK paid to feeWallet.
        uint256 net; // REDEEM only: WSK escrowed for settlement.
        bool claimed;
    }

    uint256 public constant INITIAL_NAV = 38_462;
    uint256 public constant FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant NAV_SCALE = 1e6;

    IERC20 public immutable usdc;
    WellstakeToken public immutable wsk;
    PendingRequestNFT public immutable pendingNFT;
    address public immutable manager;
    address public immutable vaultWallet;
    address public immutable liquidWallet;
    address public immutable feeWallet;

    uint256 public currentEpoch;
    uint256 public nextRequestId = 1;
    uint256 public lastNavPerToken;
    bool public woundDown;

    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => Request) public requests;

    event MintRequested(
        uint256 indexed requestId, address indexed user, uint256 usdcAmount, uint256 indexed epoch
    );
    event RedeemRequested(
        uint256 indexed requestId,
        address indexed user,
        uint256 wskAmount,
        uint256 feeAmount,
        uint256 indexed epoch
    );
    event EpochTransitioned(uint256 indexed epoch, uint256 navPerToken, uint256 endBlock);
    event MintClaimed(uint256 indexed requestId, address indexed user, uint256 wskAmount);
    event RedeemClaimed(
        uint256 indexed requestId, address indexed user, uint256 wskAmount, uint256 usdcAmount
    );

    error ZeroAddress();
    error ZeroAmount();
    error InvalidNav();
    error OnlyManager();
    error AlreadyWoundDown();
    error RequestNotFound();
    error RequestAlreadyClaimed();
    error EpochNotFinalized();
    error ZeroSettlement();
    error InsufficientLiquidity();
    error InvalidBatch();

    constructor(
        address usdc_,
        address manager_,
        address vaultWallet_,
        address liquidWallet_,
        address feeWallet_
    ) {
        if (
            usdc_ == address(0) || manager_ == address(0) || vaultWallet_ == address(0)
                || liquidWallet_ == address(0) || feeWallet_ == address(0)
        ) {
            revert ZeroAddress();
        }

        usdc = IERC20(usdc_);
        manager = manager_;
        vaultWallet = vaultWallet_;
        liquidWallet = liquidWallet_;
        feeWallet = feeWallet_;

        wsk = new WellstakeToken(address(this));
        pendingNFT = new PendingRequestNFT(address(this));

        currentEpoch = 1;
        lastNavPerToken = INITIAL_NAV;

        epochs[0] = Epoch({
            navPerToken: INITIAL_NAV,
            startBlock: block.number,
            endBlock: block.number,
            finalized: true
        });
        epochs[1] = Epoch({navPerToken: 0, startBlock: block.number, endBlock: 0, finalized: false});
    }

    // ---------------------------------------------------------------------
    // Requests
    // ---------------------------------------------------------------------

    /// @notice Create a mint request, escrowing `amount` USDC in the Vault.
    function requestMint(uint256 amount) external nonReentrant returns (uint256 requestId) {
        if (woundDown) revert AlreadyWoundDown();
        if (amount == 0) revert ZeroAmount();

        requestId = nextRequestId++;
        requests[requestId] = Request({
            requestType: RequestType.MINT,
            owner: msg.sender,
            epoch: currentEpoch,
            amount: amount,
            fee: 0,
            net: 0,
            claimed: false
        });

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        pendingNFT.mint(msg.sender, requestId);

        emit MintRequested(requestId, msg.sender, amount, currentEpoch);
    }

    /// @notice Create a redeem request. The 0.5% fee is paid to feeWallet immediately and the
    ///         net WSK is escrowed in the Vault.
    function requestRedeem(uint256 grossAmount) external nonReentrant returns (uint256 requestId) {
        if (woundDown) revert AlreadyWoundDown();
        if (grossAmount == 0) revert ZeroAmount();

        uint256 fee = Math.mulDiv(grossAmount, FEE_BPS, BPS_DENOMINATOR);
        uint256 net = grossAmount - fee;

        requestId = nextRequestId++;
        requests[requestId] = Request({
            requestType: RequestType.REDEEM,
            owner: msg.sender,
            epoch: currentEpoch,
            amount: grossAmount,
            fee: fee,
            net: net,
            claimed: false
        });

        if (fee > 0) {
            IERC20(address(wsk)).safeTransferFrom(msg.sender, feeWallet, fee);
        }
        IERC20(address(wsk)).safeTransferFrom(msg.sender, address(this), net);

        pendingNFT.mint(msg.sender, requestId);

        emit RedeemRequested(requestId, msg.sender, grossAmount, fee, currentEpoch);
    }

    // ---------------------------------------------------------------------
    // Epoch lifecycle
    // ---------------------------------------------------------------------

    /// @notice Finalize the current epoch with `navPerToken` and open the next epoch.
    function transitionEpoch(uint256 navPerToken) external {
        if (msg.sender != manager) revert OnlyManager();
        if (woundDown) revert AlreadyWoundDown();

        _validateNav(navPerToken);
        _finalizeCurrentEpoch(navPerToken);

        currentEpoch += 1;
        epochs[currentEpoch] =
            Epoch({navPerToken: 0, startBlock: block.number, endBlock: 0, finalized: false});
    }

    /// @notice Irreversibly wind down V1. Finalizes the current epoch and blocks all new fund
    ///         operations. Existing requests remain claimable.
    function pause(uint256 finalNAV) external {
        if (msg.sender != manager) revert OnlyManager();
        if (woundDown) revert AlreadyWoundDown();

        _validateNav(finalNAV);
        _finalizeCurrentEpoch(finalNAV);
        woundDown = true;
    }

    // ---------------------------------------------------------------------
    // Settlement
    // ---------------------------------------------------------------------

    /// @notice Settle a single request. Permissionless; always pays `request.owner`.
    function claim(uint256 requestId) external nonReentrant {
        _settle(requestId);
    }

    /// @notice Settle multiple requests atomically, in caller-supplied order.
    function claimMany(uint256[] calldata requestIds) external nonReentrant {
        uint256 len = requestIds.length;
        if (len == 0) revert InvalidBatch();
        for (uint256 i = 0; i < len; ++i) {
            _settle(requestIds[i]);
        }
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    function _validateNav(uint256 navPerToken) internal view {
        if (wsk.totalSupply() > 0 && navPerToken == 0) revert InvalidNav();
    }

    function _finalizeCurrentEpoch(uint256 navPerToken) internal {
        Epoch storage epoch = epochs[currentEpoch];
        epoch.navPerToken = navPerToken;
        epoch.endBlock = block.number;
        epoch.finalized = true;
        lastNavPerToken = navPerToken;

        emit EpochTransitioned(currentEpoch, navPerToken, block.number);
    }

    function _settle(uint256 requestId) internal {
        if (requestId == 0 || requestId >= nextRequestId) revert RequestNotFound();

        Request storage request = requests[requestId];
        if (request.owner == address(0)) revert RequestNotFound();
        if (request.claimed) revert RequestAlreadyClaimed();

        Epoch storage epoch = epochs[request.epoch];
        if (!epoch.finalized) revert EpochNotFinalized();

        if (request.requestType == RequestType.MINT) {
            _settleMint(requestId, request, epoch);
        } else {
            _settleRedeem(requestId, request, epoch);
        }
    }

    function _settleMint(uint256 requestId, Request storage request, Epoch storage epoch) internal {
        if (epoch.navPerToken == 0) revert ZeroSettlement();
        uint256 wskOut = Math.mulDiv(request.amount, NAV_SCALE, epoch.navPerToken);
        if (wskOut == 0) revert ZeroSettlement();

        request.claimed = true;
        wsk.mint(request.owner, wskOut);
        pendingNFT.burn(requestId);

        emit MintClaimed(requestId, request.owner, wskOut);
    }

    function _settleRedeem(uint256 requestId, Request storage request, Epoch storage epoch)
        internal
    {
        uint256 usdcOut = Math.mulDiv(request.net, epoch.navPerToken, NAV_SCALE);
        if (usdcOut == 0) revert ZeroSettlement();
        if (usdc.balanceOf(liquidWallet) < usdcOut) revert InsufficientLiquidity();

        request.claimed = true;
        wsk.burn(address(this), request.net);
        usdc.safeTransferFrom(liquidWallet, request.owner, usdcOut);
        pendingNFT.burn(requestId);

        emit RedeemClaimed(requestId, request.owner, request.net, usdcOut);
    }
}
