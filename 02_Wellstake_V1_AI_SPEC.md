# Wellstake V1 — AI / Code Agent Implementation Specification

**Version:** 1.0  
**Source of truth:** `01_Wellstake_V1_SRS.docx`  
**Test specification:** `03_Wellstake_V1_TEST_SPEC.md`  
**Chain:** Optimism  
**Settlement asset:** USDC  
**Share token:** WSK

---

## 1. Purpose

This document translates the Wellstake V1 SRS into an implementation-oriented specification for an AI coding agent or Solidity developer.

The agent must implement the externally observable behavior defined here and in the SRS.

When an implementation detail is not explicitly required, choose a simple, auditable, secure implementation rather than adding unnecessary architecture.

Do not introduce new product behavior without an explicit requirement.

---

# 2. V1 Architecture

V1 consists of three contracts:

1. `WellstakeToken`
2. `WellstakeVault`
3. `PendingRequestNFT`

The Vault is the only WSK minter/burner.

The Vault owns the request/epoch accounting.

The Pending NFT is a claim-ticket representation and is not the source of economic truth.

---

# 3. Fixed V1 Configuration

## 3.1 Token

- Name: `Wellstake`
- Symbol: `WSK`
- Decimals: `6`

## 3.2 Settlement asset

- USDC on Optimism only.
- USDC decimals: `6`.
- The USDC address is fixed for V1.
- No generic ERC-20 settlement asset abstraction is required.

## 3.3 Initial NAV

Initial NAV:

```solidity
38_462
```

in 6-decimal USDC/WSK units.

This represents:

```text
0.038462 USDC / WSK
```

The initial NAV may be represented as a compile-time constant.

---

# 4. Immutability Requirements

V1 is non-upgradeable.

Do not use:

- Transparent proxy
- UUPS proxy
- Beacon proxy
- Upgradeable implementation
- Upgrade admin

The following configuration values are fixed for V1:

- manager
- USDC
- vaultWallet
- liquidWallet
- feeWallet
- WSK Vault authority

Do not implement setters for these values.

`PendingRequestNFT` is intentionally NOT required to be immutable.

---

# 5. Contract Responsibilities

## 5.1 WellstakeToken

Responsibilities:

- ERC-20 WSK token.
- 6 decimals.
- Vault-only mint.
- Vault-only burn.
- Normal ERC-20 transfer.
- Normal `transferFrom`.
- Normal `approve`.
- Transfers remain enabled after Vault wind-down.

The token must not depend on Vault `paused` state to block normal ERC-20 transfers.

---

## 5.2 WellstakeVault

Responsibilities:

- Hold pending mint USDC.
- Hold pending redeem WSK.
- Create requests.
- Assign requests to epochs.
- Finalize epoch NAV.
- Mint WSK for successful mint claims.
- Burn WSK for successful redeem claims.
- Pay redemption USDC from liquidWallet.
- Transfer redeem fee to feeWallet.
- Create/burn Pending Request NFTs.
- Execute single and batch claims.
- Execute irreversible wind-down.

---

## 5.3 PendingRequestNFT

Responsibilities:

- One shared NFT collection for mint and redeem requests.
- Token ID equals requestId.
- Non-transferable.
- Minted when request is created.
- Burned on successful claim.

The NFT is a claim-ticket UX/indexing layer.

The Vault request record is authoritative.

---

# 6. Suggested Core Data Structures

The exact storage packing is an implementation choice, but the following logical data must exist.

## 6.1 Epoch

```solidity
struct Epoch {
    uint256 navPerToken;
    uint256 startBlock;
    uint256 endBlock;
}
```

An active epoch may have:

```text
endBlock = 0
```

until finalized.

---

## 6.2 Request

The logical request record must contain:

```text
requestId
request type
owner
epoch
amount information required for settlement
claimed status
```

For redeem requests, gross, fee, and net WSK amounts must be recoverable.

The exact struct packing is implementation-defined.

---

# 7. Request IDs

Use one global counter for both request types.

Rules:

- First valid request = `1`.
- `0` is invalid.
- Every successful request increments by exactly one.
- Mint and redeem share the same counter.
- IDs are never reused.
- Failed transactions must not consume an ID.

NFT token ID must equal request ID.

---

# 8. Epoch Lifecycle

## 8.1 Deployment

Deployment creates the following logical state:

```text
Epoch 0:
    NAV       = 38_462
    startBlock = deployment block
    endBlock   = deployment block
    finalized  = yes

currentEpoch = 1
```

No request belongs to Epoch 0.

---

## 8.2 Active epoch

Epoch N remains active until:

```solidity
transitionEpoch(navPerToken)
```

or:

```solidity
pause(finalNAV)
```

is executed.

Epoch duration is NOT enforced on-chain.

---

## 8.3 transitionEpoch

Only manager may call.

Logical sequence:

```text
1. Validate transition.
2. Finalize current epoch NAV.
3. Record current epoch endBlock.
4. Increment currentEpoch.
5. Record new epoch startBlock.
6. New epoch has no finalized NAV yet.
```

The transition may occur:

- with no requests;
- with pending mint requests;
- with pending redeem requests;
- with NAV equal to previous NAV;
- with NAV higher than previous NAV;
- with NAV lower than previous NAV, provided the resulting NAV is otherwise valid.

No minimum NAV change is required.

---

# 9. NAV Rules

## 9.1 Manual NAV

The manager supplies NAV.

The Vault does NOT:

- calculate portfolio NAV;
- verify portfolio assets;
- verify solvency;
- query an oracle;
- verify DEX prices;
- verify off-chain positions.

---

## 9.2 Finality

Once epoch N is finalized:

```text
navPerToken[N]
```

must never change.

All requests assigned to Epoch N settle using exactly that NAV.

---

## 9.3 Supply/NAV edge case

If:

```text
totalSupply > 0
```

then finalized NAV must be positive.

If:

```text
totalSupply == 0
```

and the fund is empty, zero NAV is allowed.

When supply is zero, implementation must retain enough prior reference-rate information for future operations.

The exact storage mechanism is implementation-defined.

---

# 10. Mint Request

## 10.1 Preconditions

Require:

- Vault is not wound down.
- `amount > 0`.
- User has sufficient USDC.
- USDC transfer/escrow succeeds.

---

## 10.2 State changes

On successful request:

```text
1. Assign requestId.
2. Record owner = msg.sender.
3. Record epoch = currentEpoch.
4. Escrow USDC in Vault.
5. Create MINT request.
6. Mint PendingRequestNFT(requestId).
7. Emit MintRequested.
```

Do NOT mint WSK at request time.

Do NOT send pending USDC to vaultWallet at request time.

---

# 11. Mint Settlement

A mint request may be claimed only after its epoch is finalized.

Settlement conceptually calculates:

```text
WSK out = floor(pendingUSDC / epochNAV)
```

using the fixed 6-decimal accounting convention.

Implementation must use safe arithmetic.

The implementation should use a well-tested fixed-point multiplication/division utility where appropriate, such as OpenZeppelin `Math.mulDiv`.

Do not divide before multiplying when that would lose required precision.

---

## 11.1 Successful mint claim

Logical sequence:

```text
1. Validate request exists.
2. Validate request type = MINT.
3. Validate not claimed.
4. Validate request epoch is finalized.
5. Calculate WSK amount.
6. Require WSK amount > 0.
7. Mark request claimed / perform protected settlement state transition.
8. Mint WSK to request.owner.
9. Treat escrowed USDC as settled fund capital.
10. Burn PendingRequestNFT(requestId).
11. Emit MintClaimed.
```

The implementation may choose a different internal ordering where required for reentrancy safety, but the transaction must be atomic.

If any step fails, the entire transaction must revert.

---

# 12. Redeem Request

## 12.1 Fee

Redeem fee:

```text
0.5%
```

The fee is paid in WSK.

The fee is NOT burned.

---

## 12.2 Amounts

For gross WSK amount:

```text
fee = floor(gross * 0.5%)
net = gross - fee
```

The exact fixed-point implementation must preserve the specified round-down behavior.

---

## 12.3 State changes

On successful request:

```text
1. Assign requestId.
2. Record owner = msg.sender.
3. Record epoch = currentEpoch.
4. Calculate fee.
5. Transfer fee WSK to feeWallet.
6. Escrow net WSK in Vault.
7. Record gross, fee, and net.
8. Mint PendingRequestNFT(requestId).
9. Emit RedeemRequested.
```

Do NOT burn WSK at request time.

Do NOT pay USDC at request time.

---

# 13. Redeem Settlement

After epoch finalization:

```text
USDC out = floor(netWSK * epochNAV / 10^6)
```

subject to the defined 6-decimal fixed-point convention.

The USDC must come from `liquidWallet`.

---

## 13.1 Successful redeem claim

Logical behavior:

```text
1. Validate request.
2. Validate not claimed.
3. Validate request epoch finalized.
4. Calculate USDC output.
5. Require output > 0.
6. Require liquidWallet can provide required USDC.
7. Burn net WSK.
8. Transfer USDC from liquidWallet to request.owner.
9. Mark request claimed.
10. Burn PendingRequestNFT(requestId).
11. Emit RedeemClaimed.
```

The exact ordering must be hardened against reentrancy.

---

## 13.2 Insufficient liquidity

If liquidWallet has insufficient USDC:

```text
claim() reverts
```

and:

- WSK is not burned.
- USDC is not paid.
- request remains unclaimed.
- NFT remains.

After the manager replenishes liquidWallet, the user can retry.

No partial redemption is allowed.

---

# 14. Pending Accounting

Pending operations must not prematurely affect settled accounting.

## Pending mint

Before claim:

- USDC remains escrowed.
- WSK is not minted.
- settled WSK supply does not increase.
- pending USDC is excluded from NAV fund assets.

## Pending redeem

Before claim:

- net WSK remains escrowed.
- WSK is not burned.
- settled supply does not decrease.

The request's economic settlement rate is determined by its finalized epoch NAV.

Claim is the on-chain settlement action, not a second price-discovery event.

---

# 15. Pending Request NFT

The NFT must be:

- shared by mint and redeem requests;
- non-transferable;
- tokenId = requestId.

The NFT should not duplicate all request data.

The Vault remains authoritative.

On successful claim:

```text
request.claimed = true
NFT(requestId) = burned
```

Both actions must occur atomically.

---

# 16. Claim

## 16.1 Permissionless

Any address may call:

```solidity
claim(requestId)
```

The caller is not the beneficiary.

Settlement always goes to:

```text
request.owner
```

---

## 16.2 Already claimed

A claimed request must revert if claimed again.

---

## 16.3 Request ID zero

`requestId == 0` is invalid.

---

## 16.4 Request persistence

Do not delete the request record after claim.

Retain historical request data.

Only claimed state needs to change.

This is intentional for transparency and auditability.

---

# 17. claimMany

The Vault must support:

```solidity
claimMany(uint256[] calldata requestIds)
```

Requirements:

- Empty array reverts.
- Any number of request IDs is allowed by contract logic.
- Frontend may split large batches for gas reasons.
- Mint and redeem requests may be mixed.
- Caller-supplied order is preserved.
- Duplicate IDs cause the whole batch to revert.
- Already-claimed IDs cause the whole batch to revert.
- Any individual settlement failure causes the whole batch to revert.
- No partial batch settlement.

Do not add sorting or prioritization.

---

# 18. Wind-Down / Pause

`pause(finalNAV)` is NOT a temporary pause.

It is final V1 wind-down.

Only manager may call it.

---

## 18.1 Wind-down sequence

Logical behavior:

```text
1. Require not already wound down.
2. Finalize current epoch with finalNAV.
3. Record current epoch endBlock.
4. Set permanently wound-down state.
5. Do NOT increment currentEpoch.
```

---

## 18.2 After wind-down

Block:

- new mint requests;
- new redeem requests;
- `transitionEpoch`;
- any other new fund operation.

Allow:

- claims for requests created before wind-down;
- mint settlement for pre-wind-down mint requests;
- redeem settlement for pre-wind-down redeem requests;
- normal WSK ERC-20 transfers;
- `transferFrom`;
- `approve`.

This distinction is critical:

> Wind-down blocks NEW fund operations, not settlement of existing obligations.

Do not put a global `whenNotPaused` restriction around internal WSK mint/burn paths if that would prevent valid pre-wind-down claims.

---

# 19. Wallet Semantics

## 19.1 vaultWallet

EOA.

Used for:

- portfolio assets;
- investment capital;
- strategy execution;
- swaps;
- LP;
- farming;
- perps;
- other external fund activities.

The Vault does not need to enforce investment strategy.

---

## 19.2 liquidWallet

Contract address.

Used for:

- redemption liquidity.

Redeem claims pay USDC from liquidWallet.

Insufficient liquidity causes claim to revert.

---

## 19.3 feeWallet

EOA.

Receives:

```text
0.5% redeem fee in WSK
```

WSK held by feeWallet is ordinary WSK:

- included in total supply;
- included in NAV denominator;
- no special exclusion;
- if redeemed, normal fee applies.

---

# 20. Direct Transfers

## 20.1 Direct USDC to Vault

Do not create a request.

Do not refund automatically.

Do not create a Pending NFT.

The USDC remains part of fund assets and is included in NAV accounting.

---

## 20.2 Direct WSK to Vault

Do not create a redeem request.

Do not automatically burn.

The Vault simply holds WSK like any other ERC-20 asset.

The WSK remains part of total supply.

No rescue mechanism is required.

---

# 21. Access Control

V1 does not require a role framework.

At minimum:

```text
manager-only:
    transitionEpoch
    pause/final wind-down

permissionless:
    claim
    claimMany

user:
    requestMint
    requestRedeem
```

The exact function names may differ, but semantics must match.

---

# 22. Security Requirements

Use established audited patterns where appropriate.

Recommended:

- OpenZeppelin ERC-20 implementation
- OpenZeppelin ERC-721 implementation or minimal equivalent for Pending NFT
- OpenZeppelin `SafeERC20`
- OpenZeppelin `Math.mulDiv`
- OpenZeppelin reentrancy protection where external calls exist

These are implementation recommendations, not new product requirements.

---

## 22.1 Reentrancy

Protect:

- request functions involving token transfers;
- claim;
- claimMany;
- any function that performs external token calls and mutates settlement state.

A malicious token/mock must not be able to:

- claim the same request twice;
- burn/mint twice;
- withdraw the same USDC twice;
- bypass claimed state;
- bypass request ownership.

---

## 22.2 Checks-effects-interactions

Settlement must be structured so that external calls cannot cause duplicate settlement.

If state is updated before an external call and that external call fails, the entire transaction must revert and restore the previous state.

---

# 23. ERC-20 Approval / Transfer Behavior

WSK must behave as a normal ERC-20 except that:

- only Vault can mint;
- only Vault can burn.

After wind-down:

- `transfer` remains enabled;
- `transferFrom` remains enabled;
- `approve` remains enabled.

The token must not become frozen merely because Vault is wound down.

---

# 24. Event Requirements

Recommended event declarations:

```solidity
event MintRequested(
    uint256 indexed requestId,
    address indexed user,
    uint256 usdcAmount,
    uint256 indexed epoch
);

event RedeemRequested(
    uint256 indexed requestId,
    address indexed user,
    uint256 wskAmount,
    uint256 feeAmount,
    uint256 indexed epoch
);

event EpochTransitioned(
    uint256 indexed epoch,
    uint256 navPerToken,
    uint256 endBlock
);

event MintClaimed(
    uint256 indexed requestId,
    address indexed user,
    uint256 wskAmount
);

event RedeemClaimed(
    uint256 indexed requestId,
    address indexed user,
    uint256 wskAmount,
    uint256 usdcAmount
);
```

Events should be emitted only for successful state transitions.

Do not emit success events for transactions that ultimately revert.

---

# 25. Important State Invariants

The implementation must preserve these invariants.

## INV-001

Request IDs are unique, positive, monotonically increasing.

## INV-002

A request's epoch never changes.

## INV-003

A request's owner never changes.

## INV-004

Finalized epoch NAV never changes.

## INV-005

Pending mint does not mint WSK.

## INV-006

Pending redeem does not burn WSK.

## INV-007

Redeem fee is transferred to feeWallet and is not burned.

## INV-008

Successful claim cannot happen twice.

## INV-009

Failed claim does not consume the request.

## INV-010

Failed claim does not permanently burn the NFT.

## INV-011

Batch claim is atomic.

## INV-012

Settlement beneficiary is request.owner.

## INV-013

Wind-down blocks new requests.

## INV-014

Wind-down does not block valid pre-wind-down claims.

## INV-015

WSK remains transferable after wind-down.

## INV-016

V1 configuration addresses cannot be replaced.

---

# 26. Error Handling

The implementation may define custom errors.

Recommended logical error categories:

```text
ZeroAmount
InvalidRequest
RequestNotFound
RequestAlreadyClaimed
EpochNotFinalized
InvalidEpoch
OnlyManager
AlreadyWoundDown
ZeroSettlement
InsufficientLiquidity
InvalidBatch
DuplicateRequest
NonTransferablePendingNFT
```

Exact names are implementation-defined.

Prefer custom errors over long revert strings where appropriate.

---

# 27. No Cancellation / Rescue

Do not implement:

- request cancellation;
- request ownership transfer;
- request rescue;
- accidental USDC refund;
- accidental WSK rescue;
- tiny-request rescue;
- NFT transfer.

These are explicitly outside V1.

---

# 28. Tiny Settlement Edge Case

A valid request may theoretically calculate to zero settlement output because of fixed-point rounding.

In this case:

```text
claim reverts
```

The request remains permanently available for retry, but V1 does not require a rescue/cancel mechanism.

Do not add a minimum request amount solely to solve this edge case.

---

# 29. Zero NAV Request Edge Case

A mint request may be created while the current reference NAV is zero under the supply-zero condition.

Do not reject the request solely for this reason.

If the request's finalized epoch NAV results in zero settlement:

```text
claim reverts
```

Do not add a transition-time rule solely to prevent this case.

---

# 30. Dust

Do not require the fund to reach mathematically exact zero assets before an epoch transition.

Small residual/dust assets are allowed.

Do not add dust sweep functionality.

---

# 31. Gas and Storage

Prioritize:

1. correctness;
2. security;
3. auditability;
4. then gas optimization.

Request history should remain stored.

Do not delete request data merely to optimize long-term storage.

Do not introduce complicated packing unless it clearly improves deployment/runtime costs without reducing readability.

---

# 32. Contract API — Logical Surface

The final implementation should expose functionality equivalent to:

```text
requestMint(amount)
requestRedeem(amount)

claim(requestId)
claimMany(requestIds)

transitionEpoch(navPerToken)
pause(finalNAV)

read current epoch
read epoch data
read request data
read configuration
read wound-down state
```

Additional standard ERC-20 / ERC-721 functions are expected where applicable.

Exact public getter names may follow the chosen Solidity design.

---

# 33. Deployment Validation

Deployment scripts/tests should verify:

- correct chain;
- correct Optimism USDC address;
- correct manager;
- correct vaultWallet;
- correct liquidWallet;
- correct feeWallet;
- correct token/vault linkage;
- initial NAV;
- Epoch 0 state;
- active Epoch 1;
- no proxy;
- no upgrade admin.

Deployment should fail fast if required configuration is inconsistent.

---

# 34. Test Mapping

The implementation must satisfy:

- `03_Wellstake_V1_TEST_SPEC.md`
- all unit tests;
- all edge-case tests;
- all atomicity tests;
- all access-control tests;
- all invariant tests;
- recommended fuzz tests where practical.

Do not mark the implementation complete while known mandatory tests fail.

---

# 35. Explicit Non-Goals

Do not implement these as part of V1 unless separately requested:

- multisig;
- governance;
- upgradeability;
- multi-chain;
- multi-stablecoin;
- oracle-based NAV;
- automatic NAV calculation;
- automatic settlement keeper;
- partial claims;
- request cancellation;
- rescue;
- migration to V2;
- Velodrome integration inside Vault;
- DeFiLlama adapter;
- portfolio strategy enforcement.

---

# 36. V1 → V2 Boundary

V1 must remain independent.

Future V2 may introduce:

- new Vault;
- new WSKv2;
- migration contract;
- multisig/governance;
- better NAV infrastructure;
- additional integrations.

Do not add V2 migration state or logic to V1.

V1 WSK remains transferable indefinitely, including after wind-down.

---

# 37. Implementation Decision Rule

When implementation choices are unspecified:

1. Preserve SRS behavior.
2. Preserve accounting semantics.
3. Prefer OpenZeppelin audited primitives.
4. Prefer simple state transitions.
5. Prefer atomicity.
6. Prefer explicit custom errors.
7. Avoid unnecessary roles or abstractions.
8. Do not create new user-facing behavior.
9. Do not reinterpret already-settled product decisions.
10. If two implementation choices satisfy the same requirements, choose the simpler and more auditable one.

---

# 38. Final Implementation Checklist

Before considering V1 complete:

- [ ] WSK = 6 decimals.
- [ ] USDC = 6 decimals.
- [ ] Initial NAV = 38,462.
- [ ] Epoch 0 finalized at deployment.
- [ ] Epoch 1 active after deployment.
- [ ] Epochs have no fixed duration.
- [ ] Manager controls transitions.
- [ ] Finalized NAV is immutable.
- [ ] Mint USDC is escrowed in Vault.
- [ ] Pending mint does not mint WSK.
- [ ] Redeem fee = 0.5% WSK.
- [ ] Redeem fee goes to feeWallet.
- [ ] Pending redeem does not burn WSK.
- [ ] Claims use request epoch NAV.
- [ ] Rounding is down.
- [ ] Safe fixed-point arithmetic is used.
- [ ] Pending NFT tokenId = requestId.
- [ ] Pending NFT is non-transferable.
- [ ] Successful claim burns NFT.
- [ ] Failed claim preserves NFT/request.
- [ ] Claims are permissionless.
- [ ] Settlement goes to request.owner.
- [ ] claimMany is atomic.
- [ ] claimMany supports mixed request types.
- [ ] Duplicate claimMany IDs revert.
- [ ] Empty claimMany reverts.
- [ ] Request history remains stored.
- [ ] Wind-down is irreversible.
- [ ] Wind-down finalizes current epoch.
- [ ] Wind-down creates no new epoch.
- [ ] Existing pre-wind-down requests remain claimable.
- [ ] New requests are blocked after wind-down.
- [ ] New epoch transitions are blocked after wind-down.
- [ ] WSK transfers remain active after wind-down.
- [ ] Fixed addresses cannot be changed.
- [ ] V1 is non-upgradeable.
- [ ] Direct USDC transfer creates no entitlement.
- [ ] Direct WSK transfer creates no redemption entitlement.
- [ ] No cancellation/rescue mechanism exists.
- [ ] Mandatory tests pass.
- [ ] Invariants pass.
- [ ] Fuzz/property tests do not expose accounting or settlement violations.

---

## End of Wellstake V1 AI / Code Agent Specification
