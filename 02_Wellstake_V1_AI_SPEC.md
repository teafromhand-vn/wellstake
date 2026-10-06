# Wellstake V1 — AI / Code Agent Implementation Specification

**Version:** 2.0
**Source of truth:** the deployed contracts in `src/`
**Test specification:** `03_Wellstake_V1_TEST_SPEC.md`
**Chain:** EVM (reference deployment: Arc Testnet, chain 5042002; target: Optimism)
**Settlement asset:** ERC-20 quote token, 6 decimals (USDC or a test quote token)
**Share token:** WSK / tWSK (deploy-time configurable name + symbol)
**Frontend:** `frontend/` (Vite + React + wagmi, deployable to Vercel)

---

## 1. Purpose

This document describes the **as-built** Wellstake V1 system implemented in `src/`, so that an AI agent
or developer can extend, audit, or redeploy it consistently.

It reflects the current architecture, which supersedes the earlier V1 draft. Where this document and
the code disagree, **the code is authoritative**.

---

## 2. Architecture Overview

V1 consists of four contracts and one off-chain role:

1. `LiquidWallet` — the primary, user-facing contract. Handles **all** mint/redeem activity.
2. `WellstakeVault` — a thin **investment pool**. Moves idle USDC out to strategy and back.
3. `WellstakeToken` (WSK / tWSK) — the ERC-20 share token.
4. `PendingRequestNFT` — a **transferable** claim ticket per request.
5. `manager` (EOA) — configures the fund (finalizes epochs, winds down).
6. `vaultWallet` (EOA) — operates the investment pool.

### 2.1 Deployment / linkage

- `LiquidWallet` is deployed first. In its constructor it **deploys** `WellstakeToken` and
  `PendingRequestNFT`, both with authority = the `LiquidWallet`. It also reads the settlement ERC-20 and
  the `manager` / `vaultWallet` addresses.
- `WellstakeVault` is deployed with `(usdc, liquidWallet, vaultWallet)`.
- The `LiquidWallet` is then linked to the Vault once via `setVault(vault)` (manager-only), enabling the
  Vault to `withdraw` idle USDC from the LiquidWallet.

```
LiquidWallet ──deploys──▶ WellstakeToken (authority = LiquidWallet)
             ──deploys──▶ PendingRequestNFT (authority = LiquidWallet)
             ──setVault─▶ WellstakeVault ──withdraw()──▶ (pull USDC) ──▶ strategy → returnFunds()
```

The Vault plays **no** role in mint/redeem accounting.

---

## 3. Fixed Configuration

### 3.1 Share token

- Name / symbol: deploy-time (`WellstakeToken(name_, symbol_)`); reference test values:
  `testWellstake` / `tWSK`.
- Decimals: `6`.
- Mint/burn authority: `LiquidWallet` only.

### 3.2 Settlement asset

- Any standard ERC-20 with **6 decimals** (USDC, or a `TestQuoteToken` / `MockUSDC` on testnets).
- Address is fixed at deploy time (immutable on `LiquidWallet` and `WellstakeVault`).
- `NAV_SCALE = 1e6` assumes 6 decimals; a token with different decimals requires code change.

### 3.3 Constants (`LiquidWallet`)

```solidity
uint256 public constant INITIAL_NAV   = 38_462; // 0.038462 USDC per share, 6dp
uint256 public constant FEE_BPS       = 50;     // 0.5% redeem fee
uint256 public constant BPS_DENOMINATOR = 10_000;
uint256 public constant NAV_SCALE     = 1e6;    // 6-decimal fixed point
```

---

## 4. Immutability

V1 is non-upgradeable. No proxy, no upgrade admin.

Immutable / fixed:

- `usdc`, `manager`, `vaultWallet`, `wsk`, `pendingNFT` (set in constructor).
- No setters for any of these.
- `vault` is set **once** via `setVault` (guard: `VaultAlreadySet`).

---

## 5. Contract Responsibilities

### 5.1 LiquidWallet (primary)

- Holds settlement USDC and pending/redeem WSK.
- Records all requests (`mapping requests`) and epochs (`mapping epochs`).
- Is the sole WSK minter/burner (`WellstakeToken.authority`).
- Issues and burns `PendingRequestNFT` per request.
- Derives and locks the per-epoch rate; settles claims.
- Accepts manager NAV configuration; supports irreversible wind-down.
- Lets the linked `WellstakeVault` pull idle USDC via `withdraw`.

### 5.2 WellstakeVault (investment pool)

- `pull(amount)` — withdraw idle USDC from the LiquidWallet to this pool (Vault calls
  `LiquidWallet.withdraw`).
- `invest(amount)` — forward USDC from the pool to `vaultWallet` for external deployment.
- `returnFunds(amount)` — send USDC back to the LiquidWallet to restore redemption liquidity.
- All functions are `onlyManager` (i.e. `vaultWallet`).

### 5.3 WellstakeToken

- ERC-20, 6 decimals, name/symbol from constructor.
- `mint` / `burn` restricted to `authority` (the LiquidWallet).
- Normal `transfer` / `transferFrom` / `approve` at all times.

### 5.4 PendingRequestNFT

- ERC-721, **transferable**.
- `tokenId == requestId`.
- `mint` / `burn` restricted to `authority` (the LiquidWallet).
- Whoever holds the ticket at claim time receives the settlement.

---

## 6. Data Structures (`LiquidWallet`)

```solidity
enum RequestType { MINT, REDEEM }

struct Epoch {
    uint256 nav;         // total fund value in USDC (6dp) reported by the manager
    uint256 rate;        // USDC per WSK (6dp), locked when the epoch is finalized
    uint256 startBlock;
    uint256 endBlock;    // 0 until finalized
    bool    finalized;
}

struct Request {
    RequestType requestType;
    address owner;       // creator
    uint256 epoch;       // epoch pinned at creation
    uint256 amount;      // MINT: USDC in. REDEEM: gross WSK in.
    uint256 fee;         // REDEEM only: WSK fee to manager
    uint256 net;         // REDEEM only: gross - fee
    bool    claimed;
}
```

---

## 7. Request IDs

- One global counter (`nextRequestId`), shared by mint and redeem.
- First request = `1`; `0` is invalid.
- Increments by exactly one on each successful request; never reused.
- Failed transactions do not consume an ID.
- NFT `tokenId == requestId`.

---

## 8. Epoch Lifecycle

### 8.1 Deployment

- `currentEpoch = 1`.
- Epoch 0: `nav = rate = INITIAL_NAV`, `startBlock = endBlock = deployment block`,
  `finalized = true`.
- Epoch 1: open (`finalized = false`), `startBlock = deployment block`, `endBlock = 0`.

### 8.2 Finalize

`finalizeEpoch(nav)` (manager-only):

1. Computes the rate: if `totalSupply > 0`, `rate = floor(nav * 1e6 / totalSupply)`; otherwise the
   previous rate is carried over.
2. Locks epoch `currentEpoch`: sets `nav`, `rate`, `endBlock = block.number`, `finalized = true`.
3. Increments `currentEpoch` and opens a new epoch (`finalized = false`).

Epoch duration is not enforced on-chain.

### 8.3 Wind-down

`pause(finalNav)` (manager-only, irreversible):

1. Finalizes `currentEpoch` with `finalNav` (same math as above).
2. Sets `woundDown = true`; **does not** increment `currentEpoch`.

After wind-down: no new mint/redeem requests; existing requests remain claimable.

---

## 9. NAV / Rate Rules

- The manager supplies a single number: **total fund NAV in USDC**.
- The rate is derived, not supplied: `rate = NAV * 1e6 / totalSupply`.
- When `totalSupply == 0`, the previously stored rate is retained (initial `INITIAL_NAV`).
- A finalized epoch's `rate` is immutable; all requests in that epoch settle at that rate.
- There is **no** `setNav` function. Setting NAV and finalizing are the same action
  (`finalizeEpoch` / `pause`). This guarantees an already-finalized epoch can never be mutated.

---

## 10. Mint Request

`requestMint(amount)`:

Preconditions: not wound down; `amount > 0`; caller approved `amount` USDC.

Sequence:

1. Assign `requestId = nextRequestId++`.
2. Store `Request{MINT, owner = msg.sender, epoch = currentEpoch, amount, claimed = false}`.
3. `usdc.transferFrom(msg.sender → LiquidWallet, amount)`.
4. Mint `PendingRequestNFT(requestId)` to the owner.
5. Emit `MintRequested(requestId, user, amount, epoch)`.

WSK is **not** minted at request time.

---

## 11. Mint Settlement

`claim(requestId)` (permissionless). Requires the request's epoch to be `finalized`.

- `wskOut = floor(amount * 1e6 / epoch.rate)`; require `wskOut > 0` (else `ZeroSettlement`).
- Mark `claimed = true`.
- `beneficiary = pendingNFT.ownerOf(requestId)`; burn the NFT.
- `wsk.mint(beneficiary, wskOut)`.
- Emit `MintClaimed(requestId, beneficiary, wskOut)`.

The escrowed USDC stays in the LiquidWallet as fund capital.

---

## 12. Redeem Request

`requestRedeem(grossAmount)`:

Preconditions: not wound down; `grossAmount > 0`; caller approved `grossAmount` WSK.

1. `fee = floor(grossAmount * 50 / 10000)`; `net = grossAmount - fee`.
2. Assign `requestId`; store `Request{REDEEM, owner, epoch, amount = gross, fee, net, claimed=false}`.
3. `wsk.transferFrom(msg.sender → LiquidWallet, grossAmount)`.
4. If `fee > 0`: `wsk.transfer(LiquidWallet → manager, fee)` (fee is **not** burned).
5. Mint `PendingRequestNFT(requestId)`.
6. Emit `RedeemRequested(requestId, user, gross, fee, epoch)`.

WSK is **not** burned at request time; no USDC is paid.

---

## 13. Redeem Settlement

After the request's epoch is finalized:

- `usdcOut = floor(net * epoch.rate / 1e6)`; require `usdcOut > 0` (else `ZeroSettlement`).
- Require `usdc.balanceOf(LiquidWallet) >= usdcOut` (else `InsufficientLiquidity`).
- Mark `claimed = true`; burn the NFT.
- `wsk.burn(LiquidWallet, net)`.
- `usdc.transfer(beneficiary, usdcOut)`.
- Emit `RedeemClaimed(requestId, beneficiary, usdcOut)`.

If liquidity is insufficient the whole tx reverts; the request stays claimable after the manager
replenishes the LiquidWallet (via the Vault `returnFunds` or a direct USDC transfer).

---

## 14. Claims

- **Permissionless**: any address may call `claim` / `claimMany`.
- Settlement always pays the **current holder** of the request NFT.
- `requestId == 0` or `>= nextRequestId` → `RequestNotFound`.
- Already claimed → `RequestAlreadyClaimed`.
- Epoch not finalized → `EpochNotFinalized`.
- The NFT is burned on successful claim (atomic with settlement).
- The request record is retained after claim (historical data).

### 14.1 claimMany

- Empty array → `InvalidBatch`.
- Caller order preserved; mint/redeem may be mixed.
- Duplicate or already-claimed IDs revert the **entire** batch.
- Any individual failure reverts the whole batch (atomic, no partial settlement).

---

## 15. PendingRequestNFT

- Transferable ERC-721, `tokenId == requestId`.
- Minted on request creation; burned by the LiquidWallet on successful claim.
- Because it is transferable, the settlement beneficiary is the **ticket holder at claim time**, not
  necessarily the original requester.
- No holder approval is required for the LiquidWallet to burn it (authority role).

---

## 16. Investment Vault

- `pull(amount)`: Vault calls `LiquidWallet.withdraw(address(usdc), amount)`; the LiquidWallet sends
  USDC to the Vault. Only the linked `vault` may call `withdraw`.
- `invest(amount)`: Vault sends USDC to `vaultWallet` for external strategy.
- `returnFunds(amount)`: Vault sends USDC back to the LiquidWallet.
- All Vault operations are `onlyManager` (`vaultWallet`).
- The Vault does not mint/burn WSK, hold NFT, or know about requests/epochs.

---

## 17. Access Control

```
manager-only (LiquidWallet):
    setVault
    finalizeEpoch
    pause

vault-only (LiquidWallet):
    withdraw

vaultWallet-only (WellstakeVault):
    pull / invest / returnFunds

permissionless:
    claim / claimMany

user:
    requestMint / requestRedeem
```

---

## 18. Events

```solidity
// LiquidWallet
event VaultSet(address indexed vault);
event EpochFinalized(uint256 indexed epoch, uint256 nav, uint256 rate, uint256 endBlock);
event MintRequested(uint256 indexed requestId, address indexed user, uint256 usdcAmount, uint256 indexed epoch);
event RedeemRequested(uint256 indexed requestId, address indexed user, uint256 grossWsk, uint256 feeWsk, uint256 indexed epoch);
event MintClaimed(uint256 indexed requestId, address indexed user, uint256 wskAmount);
event RedeemClaimed(uint256 indexed requestId, address indexed user, uint256 usdcAmount);
event Withdrawn(address indexed token, address indexed to, uint256 amount);
event WoundDown(uint256 indexed epoch, uint256 finalNav, uint256 endBlock);

// WellstakeVault
event Pulled(uint256 amount);
event Returned(uint256 amount);
event Invested(address indexed to, uint256 amount);
```

---

## 19. Errors

```solidity
// LiquidWallet
ZeroAddress, ZeroAmount, OnlyManager, OnlyVault, VaultAlreadySet, AlreadyWoundDown,
RequestNotFound, RequestAlreadyClaimed, EpochNotFinalized, InvalidBatch,
ZeroSettlement, InsufficientLiquidity

// WellstakeVault
ZeroAddress, ZeroAmount, OnlyManager

// WellstakeToken / PendingRequestNFT
ZeroAddress, NotAuthority
```

---

## 20. State Invariants

- INV-001 Request IDs are unique, positive, monotonically increasing.
- INV-002 A request's epoch never changes.
- INV-003 A request's `owner` (recorded) never changes.
- INV-004 A finalized epoch's `rate` and `nav` never change.
- INV-005 Pending mint does not mint WSK until claim.
- INV-006 Pending redeem does not burn WSK until claim.
- INV-007 The redeem fee is transferred to the manager and is not burned.
- INV-008 A successful claim cannot happen twice.
- INV-009 A failed claim does not consume the request.
- INV-010 A failed claim does not burn the NFT.
- INV-011 `claimMany` is atomic.
- INV-012 Claim settlement is paid to the current NFT holder.
- INV-013 Wind-down blocks new requests and epoch transitions.
- INV-014 Wind-down does not block valid pre-wind-down claims.
- INV-015 The redeem fee is paid to `manager` at request time.
- INV-016 V1 configuration (`usdc`, `manager`, `vaultWallet`, token/NFT authority) cannot be replaced.

---

## 21. Rounding

- All settlements round **down** (toward zero) using `Math.mulDiv`.
- Multiplications precede divisions (`floor(a*b/d)`), avoiding precision loss.
- Fee: `floor(gross * 50 / 10000)`.

---

## 22. Edge Cases

- **Zero-supply rate**: while `totalSupply == 0`, the last known rate is retained; the first mint uses
  `INITIAL_NAV`.
- **Zero settlement**: if the calculated output (WSK or USDC) rounds to `0`, `claim` reverts with
  `ZeroSettlement`; the request and NFT remain.
- **Insufficient liquidity**: redeem `claim` reverts with `InsufficientLiquidity`; nothing is burned or
  paid; retry after replenishing.
- **Direct transfers**: sending USDC or WSK directly to the LiquidWallet creates no request and no
  entitlement; the tokens are simply held (USDC counts toward investment liquidity).
- **Tiny requests**: no minimum is enforced; such requests simply may revert at claim.

---

## 23. Security Notes

- `claim` / `claimMany` / `requestMint` / `requestRedeem` are `nonReentrant`.
- State (e.g. `claimed = true`) is set before external calls.
- `SafeERC20` is used for all token movements.
- The LiquidWallet is the sole WSK authority; the Vault cannot mint/burn or move WSK.
- The Vault can only pull USDC from the LiquidWallet (never WSK or NFT).

---

## 24. Deployment Validation

The deploy scripts (`script/Deploy.s.sol`, `script/DeployWithQuoteToken.s.sol`,
`script/DeployTestnet.s.sol`) should verify:

- correct chain id;
- settlement token address (and 6 decimals);
- `manager`, `vaultWallet`;
- token/NFT authority = LiquidWallet;
- `LiquidWallet.vault` linked to the `WellstakeVault`;
- epoch 0 finalized; epoch 1 active; initial NAV.

---

## 25. Reference Deployment (Arc Testnet, chain 5042002)

| Contract | Address |
|---|---|
| LiquidWallet | `0x34EFa1dE4a3f6432d65cBACb1c77783745f6b963` |
| WellstakeVault | `0x464aDcb56298B5226D6a4ee5F9D5ed023fA0EF6A` |
| WellstakeToken (tWSK) | `0x4943e1Add5bAA4caf62c2aAc225445dC9465BE0a` |
| PendingRequestNFT | `0x3C67B98454637ae21B61Df03C38Bd28e124cEb7e` |
| USDC (settlement) | `0x3600000000000000000000000000000000000000` |

Note: the Arc RPC restricts `eth_getLogs` to ~2000-block ranges and has a custom precompile that
breaks `forge script` simulation; drive live flows with `cast`/viem instead.

---

## 26. Frontend

- `frontend/`: Vite + React + TypeScript + Tailwind + wagmi/viem, injected wallet.
- Pages: `/info` (dashboard), `/mint`, `/burn` (redeem), `/docs` (redirects to `/info`),
  `/admin` (manager-only, `noindex`).
- The dashboard currently renders from `src/mock.ts`; wire to chain state via the existing hooks
  (`useVault.ts`, `useHistory.ts`, `useEpochStart.ts`).
- Deployable to Vercel as a static site (`vercel.json` SPA rewrite).

---

## 27. Explicit Non-Goals

Not part of V1: multisig/governance, upgradeability, multi-chain, multi-stablecoin settlement,
oracle-based NAV, automatic NAV calculation, keeper settlement, partial claims, request cancellation,
rescue, dust sweeping, strategy enforcement inside contracts.

---

## End of Wellstake V1 AI / Code Agent Specification (v2.0)
