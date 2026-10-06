// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {WellstakeToken} from "./WellstakeToken.sol";
import {PendingRequestNFT} from "./PendingRequestNFT.sol";

/// @title LiquidWallet
/// @notice Primary user-facing contract. It handles ALL mint and redeem activity:
///         it holds user USDC/WSK and redemption liquidity, issues and burns the PendingRequestNFT,
///         is the sole WSK minter/burner, and pays out settlements.
/// @dev Epoch model: the manager finalizes an epoch with a NAV; the rate (USDC per WSK) is derived
///      as NAV / totalSupply and locked for that epoch. Every request is pinned to the active
///      epoch at creation and settles at that epoch's locked rate once the epoch is finalized.
///      Requests are recorded here (not in the Vault). The investment Vault may pull idle USDC via
///      `withdraw`. Claims are permissionless and always pay the current holder of the request NFT.
contract LiquidWallet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant INITIAL_NAV = 38_462;
    uint256 public constant FEE_BPS = 50;
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant NAV_SCALE = 1e6;

    enum RequestType {
        MINT,
        REDEEM
    }

    struct Epoch {
        uint256 nav; // total fund value (USDC, 6dp) reported by the manager
        uint256 rate; // USDC per WSK (6dp) locked when finalized
        uint256 startBlock;
        uint256 endBlock;
        bool finalized;
    }

    struct Request {
        RequestType requestType;
        address owner;
        uint256 epoch;
        uint256 amount; // MINT: USDC in. REDEEM: gross WSK in.
        uint256 fee; // REDEEM only: WSK fee to manager.
        uint256 net; // REDEEM only: WSK net of fee.
        bool claimed;
    }

    IERC20 public immutable usdc;
    address public immutable manager;
    address public immutable vaultWallet;
    WellstakeToken public immutable wsk;
    PendingRequestNFT public immutable pendingNFT;

    /// @notice Investment vault allowed to pull idle USDC. Set once after deployment.
    address public vault;

    /// @notice Active epoch index. Epoch 0 is finalized at deployment; epoch 1 is active.
    uint256 public currentEpoch;
    /// @notice Latest manager-reported NAV and derived rate (for the open epoch).
    uint256 public totalNav;
    uint256 public rate;
    bool public woundDown;

    uint256 public nextRequestId = 1;
    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => Request) public requests;

    event VaultSet(address indexed vault);
    event EpochFinalized(uint256 indexed epoch, uint256 nav, uint256 rate, uint256 endBlock);
    event MintRequested(
        uint256 indexed requestId, address indexed user, uint256 usdcAmount, uint256 indexed epoch
    );
    event RedeemRequested(
        uint256 indexed requestId,
        address indexed user,
        uint256 grossWsk,
        uint256 feeWsk,
        uint256 indexed epoch
    );
    event MintClaimed(uint256 indexed requestId, address indexed user, uint256 wskAmount);
    event RedeemClaimed(uint256 indexed requestId, address indexed user, uint256 usdcAmount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event WoundDown(uint256 indexed epoch, uint256 finalNav, uint256 endBlock);

    error ZeroAddress();
    error ZeroAmount();
    error OnlyManager();
    error OnlyVault();
    error VaultAlreadySet();
    error AlreadyWoundDown();
    error RequestNotFound();
    error RequestAlreadyClaimed();
    error EpochNotFinalized();
    error InvalidBatch();
    error ZeroSettlement();
    error InsufficientLiquidity();

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager();
        _;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(
        address usdc_,
        address manager_,
        address vaultWallet_,
        string memory tokenName_,
        string memory tokenSymbol_
    ) {
        if (usdc_ == address(0) || manager_ == address(0) || vaultWallet_ == address(0)) {
            revert ZeroAddress();
        }

        usdc = IERC20(usdc_);
        manager = manager_;
        vaultWallet = vaultWallet_;

        wsk = new WellstakeToken(address(this), tokenName_, tokenSymbol_);
        pendingNFT = new PendingRequestNFT(address(this));

        totalNav = INITIAL_NAV;
        rate = INITIAL_NAV;

        currentEpoch = 1;
        // Epoch 0 is finalized at deployment with the initial NAV.
        epochs[0] = Epoch({
            nav: INITIAL_NAV,
            rate: INITIAL_NAV,
            startBlock: block.number,
            endBlock: block.number,
            finalized: true
        });
        // Epoch 1 is open and not yet finalized.
        epochs[1] = Epoch({
            nav: INITIAL_NAV,
            rate: INITIAL_NAV,
            startBlock: block.number,
            endBlock: 0,
            finalized: false
        });

        emit EpochFinalized(0, INITIAL_NAV, INITIAL_NAV, block.number);
    }

    // ---------------------------------------------------------------------
    // Configuration
    // ---------------------------------------------------------------------

    /// @notice Set the investment vault once. Only the manager may do this.
    function setVault(address vault_) external onlyManager {
        if (vault_ == address(0)) revert ZeroAddress();
        if (vault != address(0)) revert VaultAlreadySet();
        vault = vault_;
        emit VaultSet(vault_);
    }

    /// @notice Finalize the open epoch (locking its NAV and rate) and open the next epoch.
    /// @dev The only way to set a NAV. The rate is derived as NAV / totalSupply; with zero supply
    ///      the prior rate is carried over.
    function finalizeEpoch(uint256 nav_) external onlyManager {
        if (woundDown) revert AlreadyWoundDown();
        _finalize(nav_);

        currentEpoch += 1;
        epochs[currentEpoch] = Epoch({
            nav: totalNav, rate: rate, startBlock: block.number, endBlock: 0, finalized: false
        });
    }

    /// @notice Irreversibly wind down. Finalizes the open epoch and blocks new requests.
    ///         Existing requests remain claimable.
    function pause(uint256 finalNav) external onlyManager {
        if (woundDown) revert AlreadyWoundDown();
        _finalize(finalNav);
        woundDown = true;

        emit WoundDown(currentEpoch, finalNav, block.number);
    }

    // ---------------------------------------------------------------------
    // Requests
    // ---------------------------------------------------------------------

    /// @notice Create a mint request. `amount` USDC is pulled from the caller. WSK is not minted
    ///         until the request is claimed (after its epoch is finalized).
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

    /// @notice Create a redeem request. The 0.5% fee is forwarded to the manager immediately and
    ///         the net WSK is held for settlement. WSK is not burned until claim.
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

        IERC20(address(wsk)).safeTransferFrom(msg.sender, address(this), grossAmount);
        if (fee > 0) {
            IERC20(address(wsk)).safeTransfer(manager, fee);
        }
        pendingNFT.mint(msg.sender, requestId);

        emit RedeemRequested(requestId, msg.sender, grossAmount, fee, currentEpoch);
    }

    // ---------------------------------------------------------------------
    // Claims (permissionless)
    // ---------------------------------------------------------------------

    /// @notice Settle a single request. Pays the current holder of the request NFT.
    function claim(uint256 requestId) external nonReentrant {
        _claim(requestId);
    }

    /// @notice Settle multiple requests atomically, preserving caller order.
    function claimMany(uint256[] calldata requestIds) external nonReentrant {
        uint256 len = requestIds.length;
        if (len == 0) revert InvalidBatch();
        for (uint256 i = 0; i < len; ++i) {
            _claim(requestIds[i]);
        }
    }

    // ---------------------------------------------------------------------
    // Investment vault
    // ---------------------------------------------------------------------

    /// @notice Withdraw idle funds to the investment vault. Only the configured vault may call.
    function withdraw(address token, uint256 amount) external onlyVault {
        IERC20(token).safeTransfer(vault, amount);
        emit Withdrawn(token, vault, amount);
    }

    // ---------------------------------------------------------------------
    // Internal
    // ---------------------------------------------------------------------

    function _finalize(uint256 nav_) internal {
        totalNav = nav_;
        uint256 supply = wsk.totalSupply();
        if (supply > 0) {
            rate = Math.mulDiv(nav_, NAV_SCALE, supply);
        }

        Epoch storage epoch = epochs[currentEpoch];
        epoch.nav = nav_;
        epoch.rate = rate;
        epoch.endBlock = block.number;
        epoch.finalized = true;

        emit EpochFinalized(currentEpoch, nav_, rate, block.number);
    }

    function _claim(uint256 requestId) internal {
        if (requestId == 0 || requestId >= nextRequestId) revert RequestNotFound();

        Request storage request = requests[requestId];
        if (request.owner == address(0)) revert RequestNotFound();
        if (request.claimed) revert RequestAlreadyClaimed();

        Epoch storage epoch = epochs[request.epoch];
        if (!epoch.finalized) revert EpochNotFinalized();

        address beneficiary = pendingNFT.ownerOf(requestId);
        request.claimed = true;

        // The LiquidWallet is the NFT authority, so it can burn the ticket directly. Settlement
        // is paid to the current holder; no approval from the holder is required.
        pendingNFT.burn(requestId);

        uint256 lockedRate = epoch.rate;

        if (request.requestType == RequestType.MINT) {
            if (lockedRate == 0) revert ZeroSettlement();
            uint256 wskOut = Math.mulDiv(request.amount, NAV_SCALE, lockedRate);
            if (wskOut == 0) revert ZeroSettlement();

            wsk.mint(beneficiary, wskOut);
            emit MintClaimed(requestId, beneficiary, wskOut);
        } else {
            uint256 usdcOut = Math.mulDiv(request.net, lockedRate, NAV_SCALE);
            if (usdcOut == 0) revert ZeroSettlement();
            if (usdc.balanceOf(address(this)) < usdcOut) revert InsufficientLiquidity();

            wsk.burn(address(this), request.net);
            usdc.safeTransfer(beneficiary, usdcOut);
            emit RedeemClaimed(requestId, beneficiary, usdcOut);
        }
    }
}
