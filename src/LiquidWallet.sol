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
///         is the sole WSK minter/burner, and pays out settlements. The manager sets the fund NAV
///         here; the rate (USDC per WSK) is derived as NAV / totalSupply.
/// @dev Requests are recorded here (not in the Vault). The investment Vault may pull idle USDC via
///      `withdraw` and is expected to return funds later. Claims are permissionless and always pay
///      the current holder of the request NFT.
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

    struct Request {
        RequestType requestType;
        address owner;
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

    /// @notice Fund NAV in USDC (6dp) as reported by the manager.
    uint256 public totalNav;
    /// @notice USDC per WSK (6dp), derived from NAV and total supply.
    uint256 public rate;
    bool public woundDown;

    uint256 public nextRequestId = 1;
    mapping(uint256 => Request) public requests;

    event VaultSet(address indexed vault);
    event NavSet(uint256 totalNav, uint256 rate);
    event MintRequested(uint256 indexed requestId, address indexed user, uint256 usdcAmount);
    event RedeemRequested(
        uint256 indexed requestId, address indexed user, uint256 grossWsk, uint256 feeWsk
    );
    event MintClaimed(uint256 indexed requestId, address indexed user, uint256 wskAmount);
    event RedeemClaimed(uint256 indexed requestId, address indexed user, uint256 usdcAmount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event WoundDown(uint256 finalNav);

    error ZeroAddress();
    error ZeroAmount();
    error OnlyManager();
    error OnlyVault();
    error VaultAlreadySet();
    error AlreadyWoundDown();
    error RequestNotFound();
    error RequestAlreadyClaimed();
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

    constructor(address usdc_, address manager_, address vaultWallet_) {
        if (usdc_ == address(0) || manager_ == address(0) || vaultWallet_ == address(0)) {
            revert ZeroAddress();
        }

        usdc = IERC20(usdc_);
        manager = manager_;
        vaultWallet = vaultWallet_;

        wsk = new WellstakeToken(address(this));
        pendingNFT = new PendingRequestNFT(address(this));

        totalNav = INITIAL_NAV;
        rate = INITIAL_NAV;

        emit NavSet(INITIAL_NAV, INITIAL_NAV);
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

    /// @notice Report the fund NAV (total USDC value). Only the manager may do this.
    ///         The rate is derived as NAV / totalSupply; when supply is zero the prior rate holds.
    function setNav(uint256 nav_) external onlyManager {
        if (woundDown) revert AlreadyWoundDown();
        totalNav = nav_;

        uint256 supply = wsk.totalSupply();
        if (supply > 0) {
            rate = Math.mulDiv(nav_, NAV_SCALE, supply);
        }

        emit NavSet(nav_, rate);
    }

    // ---------------------------------------------------------------------
    // Requests
    // ---------------------------------------------------------------------

    /// @notice Create a mint request. The Vault pulls `amount` USDC from the caller into this
    ///         contract. WSK is not minted until the request is claimed.
    function requestMint(uint256 amount) external nonReentrant returns (uint256 requestId) {
        if (woundDown) revert AlreadyWoundDown();
        if (amount == 0) revert ZeroAmount();

        requestId = nextRequestId++;
        requests[requestId] = Request({
            requestType: RequestType.MINT,
            owner: msg.sender,
            amount: amount,
            fee: 0,
            net: 0,
            claimed: false
        });

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        pendingNFT.mint(msg.sender, requestId);

        emit MintRequested(requestId, msg.sender, amount);
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

        emit RedeemRequested(requestId, msg.sender, grossAmount, fee);
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

    function _claim(uint256 requestId) internal {
        if (requestId == 0 || requestId >= nextRequestId) revert RequestNotFound();

        Request storage request = requests[requestId];
        if (request.owner == address(0)) revert RequestNotFound();
        if (request.claimed) revert RequestAlreadyClaimed();

        address beneficiary = pendingNFT.ownerOf(requestId);
        request.claimed = true;

        // The LiquidWallet is the NFT authority, so it can burn the ticket directly. Settlement
        // is paid to the current holder; no approval from the holder is required.
        pendingNFT.burn(requestId);

        if (request.requestType == RequestType.MINT) {
            if (rate == 0) revert ZeroSettlement();
            uint256 wskOut = Math.mulDiv(request.amount, NAV_SCALE, rate);
            if (wskOut == 0) revert ZeroSettlement();

            wsk.mint(beneficiary, wskOut);
            emit MintClaimed(requestId, beneficiary, wskOut);
        } else {
            uint256 usdcOut = Math.mulDiv(request.net, rate, NAV_SCALE);
            if (usdcOut == 0) revert ZeroSettlement();
            if (usdc.balanceOf(address(this)) < usdcOut) revert InsufficientLiquidity();

            wsk.burn(address(this), request.net);
            usdc.safeTransfer(beneficiary, usdcOut);
            emit RedeemClaimed(requestId, beneficiary, usdcOut);
        }
    }
}
