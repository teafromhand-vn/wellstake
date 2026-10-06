# Wellstake V1 — Test Specification

**Version:** 1.0  
**System:** Wellstake V1  
**Chain:** Optimism  
**Settlement Asset:** USDC  
**Share Token:** WSK

---

## 1. Purpose

This document defines the acceptance tests, invariants, edge cases, and expected behaviors for Wellstake V1.

It is derived from `01_Wellstake_V1_SRS.docx` and is intended to verify that the Solidity implementation conforms to the product/system requirements.

The test specification is normative for externally observable behavior.

---

## 2. Test Scope

The test suite shall cover:

- Deployment and initial state
- Epoch lifecycle
- Manual NAV finalization
- Mint requests
- Mint settlement
- Redeem requests
- Redeem settlement
- Redemption fee
- Pending Request NFTs
- Request ownership
- Permissionless claims
- Batch claims
- Pause / irreversible wind-down
- Post-wind-down behavior
- Direct transfers
- Zero-supply / zero-NAV edge cases
- Rounding
- Atomicity
- Access control
- Reentrancy-sensitive flows
- Event emission
- Immutability of configured addresses
- V1 non-upgradeability

---

# 3. Test Conventions

Unless a test explicitly states otherwise:

- WSK decimals = 6
- USDC decimals = 6
- Initial NAV = `38_462` raw units = `0.038462 USDC/WSK`
- Redeem fee = `0.5%`
- Mint fee = `0%`
- requestId starts at `1`
- Epoch 0 is finalized at deployment
- Epoch 1 is the first active epoch
- Rounding is toward zero / round down
- Claims pay the recorded request owner
- Claims are permissionless

---

# 4. Deployment Tests

## DEP-001 — Initial token configuration

**Given:** Contract deployment.

**Expected:**

- Token name is `Wellstake`.
- Token symbol is `WSK`.
- WSK decimals are `6`.
- Vault is configured as the WSK mint/burn authority.
- USDC is the Optimism USDC address.
- Manager is configured correctly.
- `vaultWallet`, `liquidWallet`, and `feeWallet` are configured correctly.

---

## DEP-002 — Epoch 0 state

**Expected:**

- Epoch 0 exists.
- Epoch 0 NAV = `38_462`.
- Epoch 0 `startBlock` = deployment block.
- Epoch 0 `endBlock` = deployment block.
- Epoch 0 is already finalized.
- No request belongs to Epoch 0.
- No Pending Request NFT exists for Epoch 0.
- Active epoch = `1`.

---

## DEP-003 — Request counter starts at one

**Expected:**

- Next successful request receives requestId `1`.
- RequestId `0` is invalid for claims/lookups that require an existing request.

---

# 5. Epoch Tests

## EPOCH-001 — Transition active epoch

**Given:**

- Epoch 1 is active.
- No pending requests.

**When:**

- Manager calls `transitionEpoch(newNAV)`.

**Expected:**

- Epoch 1 receives `newNAV`.
- Epoch 1 `endBlock` is recorded.
- Active epoch becomes Epoch 2.
- Epoch 2 `startBlock` is recorded.
- Epoch 2 has no finalized NAV yet.

---

## EPOCH-002 — Transition with pending mint requests

**Given:**

- Epoch 1 is active.
- At least one mint request exists.

**When:**

- Manager calls `transitionEpoch(newNAV)`.

**Expected:**

- Transition succeeds.
- Pending requests remain pending.
- Epoch 1 NAV becomes immutable.
- Requests created in Epoch 1 use Epoch 1 NAV when claimed.

---

## EPOCH-003 — Transition with pending redeem requests

Same expectations as EPOCH-002 for redeem requests.

---

## EPOCH-004 — Transition with no requests

**Expected:**

- Transition succeeds.
- Empty epochs are valid.
- Multiple consecutive empty epochs are valid.

---

## EPOCH-005 — Same NAV transition

**When:**

- Manager transitions using exactly the previous NAV.

**Expected:**

- Transition succeeds.
- No minimum NAV movement is required.

---

## EPOCH-006 — NAV can increase

**Expected:**

- Higher NAV is accepted if otherwise valid.

---

## EPOCH-007 — NAV can decrease

**Expected:**

- Lower positive NAV is accepted if otherwise valid.

---

## EPOCH-008 — Non-manager cannot transition

**When:**

- Any address other than manager calls `transitionEpoch`.

**Expected:**

- Transaction reverts.
- Epoch state remains unchanged.

---

## EPOCH-009 — Finalized NAV is immutable

**When:**

1. Finalize Epoch N.
2. Attempt to modify Epoch N NAV.

**Expected:**

- Previously finalized NAV cannot be changed.

---

## EPOCH-010 — Request after transition belongs to new epoch

**When:**

1. Finalize Epoch N.
2. Create request after transition.

**Expected:**

- New request has `epoch = N + 1`.

---

## EPOCH-011 — Request before transition belongs to old epoch

**When:**

1. Create request while Epoch N is active.
2. Transition to Epoch N+1.

**Expected:**

- Existing request retains `epoch = N`.

---

## EPOCH-012 — Transaction ordering determines boundary

**Expected:**

- A request transaction mined before the transition belongs to the old epoch.
- A request transaction mined after the transition belongs to the new epoch.
- No additional race-resolution mechanism is required.

---

# 6. Mint Request Tests

## MINT-001 — Create valid mint request

**Given:**

- User owns sufficient USDC.
- User approved Vault.

**When:**

- User requests mint with amount > 0.

**Expected:**

- USDC is escrowed by Vault.
- New request is created.
- Request type = MINT.
- Owner = requesting user.
- Request epoch = current epoch.
- Pending NFT is minted.
- NFT tokenId = requestId.
- requestId increments by one.
- WSK total supply does not increase yet.

---

## MINT-002 — Zero mint amount rejected

**When:**

- User requests mint with `amount = 0`.

**Expected:**

- Revert.
- No request.
- No NFT.
- No token movement.

---

## MINT-003 — Insufficient USDC rejected

**Expected:**

- Revert.
- No request.
- No NFT.
- No partial escrow.

---

## MINT-004 — Pending mint USDC remains in Vault

**Expected:**

- USDC is not automatically transferred to `vaultWallet` at request time.
- USDC remains escrowed by the Vault until successful settlement.

---

## MINT-005 — Pending mint excluded from settled supply

**Expected:**

- Pending mint does not mint WSK.
- Total WSK supply remains unchanged before claim.

---

## MINT-006 — Mint request records current epoch

**Expected:**

- Request epoch equals the current active epoch at request execution.

---

## MINT-007 — Mint request NFT is non-transferable

**When:**

- NFT owner attempts ERC-721 transfer.

**Expected:**

- Transfer reverts.

---

## MINT-008 — Mint request owner is fixed

**Expected:**

- NFT cannot be transferred to change economic ownership.
- Request owner remains original requester.

---

# 7. Mint Settlement Tests

## MINT-SET-001 — Claim before epoch finalization rejected

**Expected:**

- Claim reverts.
- Request remains unclaimed.
- NFT remains.
- No WSK minted.

---

## MINT-SET-002 — Claim after epoch finalization

**Given:**

- Mint request belongs to finalized Epoch N.
- Epoch N NAV is positive.

**When:**

- Owner or third party calls claim.

**Expected:**

- WSK amount is calculated using Epoch N NAV.
- WSK is minted to request owner.
- Escrowed USDC becomes fund capital.
- Request becomes claimed.
- Pending NFT is burned.

---

## MINT-SET-003 — Third party can claim for user

**Expected:**

- Non-owner caller may execute claim.
- WSK is still minted to request owner.
- Caller receives no WSK.

---

## MINT-SET-004 — Mint settlement uses locked epoch NAV

**Given:**

- Request created in Epoch 1.
- Epoch 1 NAV finalized at `0.04`.
- Later Epoch 2 NAV = `0.05`.

**Expected:**

- Epoch 1 request settles using `0.04`, not `0.05`.

---

## MINT-SET-005 — Mint rounds down

For:

`wskOut = floor(usdcAmount / navPerToken)`

**Expected:**

- Any fractional WSK remainder is discarded according to round-down rules.
- No rounding-up occurs.

---

## MINT-SET-006 — Zero settlement result

**Given:**

- Valid mint request.
- Finalized NAV causes calculated WSK output to equal zero.

**Expected:**

- Claim reverts.
- Request remains unclaimed.
- NFT remains.
- USDC remains escrowed.

---

## MINT-SET-007 — Failed mint claim is atomic

**Expected:**

If settlement fails:

- WSK is not minted.
- Request is not marked claimed.
- NFT is not burned.
- Escrow state is unchanged.

---

# 8. Redeem Request Tests

## REDEEM-001 — Create valid redeem request

**Given:**

- User owns sufficient WSK.
- User approved Vault.

**When:**

- User requests redemption.

**Expected:**

- Gross WSK is escrowed.
- Fee amount = 0.5% of gross according to defined round-down arithmetic.
- Fee WSK is transferred to `feeWallet`.
- Net WSK = gross - fee.
- Request stores gross, fee, net, owner, and epoch.
- Pending NFT is minted.
- NFT tokenId = requestId.
- Total supply is unchanged by the request.

---

## REDEEM-002 — Redeem fee is not burned

**Expected:**

- Fee WSK belongs to `feeWallet`.
- Fee WSK remains part of total supply.
- Fee WSK is not burned at request time.

---

## REDEEM-003 — Fee wallet behaves as ordinary WSK holder

**Expected:**

- WSK held by feeWallet contributes to total supply and NAV denominator.
- If feeWallet later redeems, normal redeem rules and fee apply.

---

## REDEEM-004 — Zero redeem amount rejected

**Expected:**

- Revert.
- No request.
- No NFT.
- No WSK movement.

---

## REDEEM-005 — Insufficient WSK rejected

**Expected:**

- Revert.
- No partial escrow.
- No fee transfer.
- No request.

---

## REDEEM-006 — Pending redeem does not burn WSK

**Expected:**

- WSK remains part of total supply before successful claim.
- No burn occurs at request creation.

---

# 9. Redeem Settlement Tests

## REDEEM-SET-001 — Claim before epoch finalization rejected

**Expected:**

- Revert.
- Request remains unclaimed.
- NFT remains.
- No WSK burned.
- No USDC transferred.

---

## REDEEM-SET-002 — Successful redeem claim

**Given:**

- Epoch finalized.
- liquidWallet has enough USDC.

**Expected:**

- Net WSK is burned.
- USDC is transferred from liquidWallet to request owner.
- Request becomes claimed.
- NFT is burned.

---

## REDEEM-SET-003 — Settlement uses epoch NAV

Expected redemption:

`usdcOut = floor(netWSK * epochNAV / 10^6)`

subject to the defined 6-decimal accounting convention.

---

## REDEEM-SET-004 — Insufficient liquidWallet liquidity

**Given:**

- liquidWallet does not contain enough USDC.

**Expected:**

- Claim reverts.
- No WSK is burned.
- No USDC is paid.
- Request remains unclaimed.
- NFT remains.

---

## REDEEM-SET-005 — User retries after liquidity is added

**When:**

1. First claim fails due to insufficient liquidity.
2. Manager replenishes liquidWallet.
3. User retries.

**Expected:**

- Second claim succeeds if all other conditions are valid.

---

## REDEEM-SET-006 — Third party can claim redeem request

**Expected:**

- Third party may call claim.
- USDC is paid to request owner.
- Caller receives no USDC.

---

## REDEEM-SET-007 — Zero USDC settlement

**Given:**

- Calculated redemption output is zero.

**Expected:**

- Claim reverts.
- WSK is not burned.
- NFT remains.

---

# 10. Rounding Tests

## ROUND-001 — Mint rounds down

Test values where division produces a fractional result.

**Expected:**

- Output is never rounded up.

---

## ROUND-002 — Redeem rounds down

Test values where multiplication/division produces a fractional USDC result.

**Expected:**

- Output is never rounded up.

---

## ROUND-003 — Multiply before divide

Use values where dividing first would produce a materially different result.

**Expected:**

- Implementation produces mathematically correct floor result under the defined fixed-point convention.

---

## ROUND-004 — Fee rounding

Test small redeem amounts.

**Expected:**

- Fee follows the specified floor/round-down rule.
- No hidden rounding-up occurs.

---

## ROUND-005 — Split redemption behavior

Verify that splitting a redemption into multiple requests can produce a different aggregate fee because of integer rounding.

**Expected:**

- Behavior is accepted and deterministic.
- No special anti-splitting mechanism is required.

---

# 11. Pending NFT Tests

## NFT-001 — Shared NFT for mint and redeem

**Expected:**

- Both request types use the same Pending Request NFT contract.

---

## NFT-002 — Token ID equals request ID

For every successful request:

`NFT tokenId == requestId`

---

## NFT-003 — NFT is burned on successful claim

**Expected:**

- NFT no longer exists after successful settlement.

---

## NFT-004 — NFT survives failed claim

**Expected:**

- NFT remains owned by its current owner representation after failed claim.

---

## NFT-005 — NFT cannot be transferred

**Expected:**

- Transfer attempts revert.

---

# 12. Claim Tests

## CLAIM-001 — Claim exactly once

**When:**

1. Claim succeeds.
2. Same request is claimed again.

**Expected:**

- First claim succeeds.
- Second claim reverts.

---

## CLAIM-002 — Request remains queryable after claim

**Expected:**

- Historical request data remains readable.
- Claimed state indicates settlement.

---

## CLAIM-003 — Request owner cannot be changed

**Expected:**

- There is no transfer/cancel operation that changes request ownership.

---

## CLAIM-004 — Claim caller does not become beneficiary

**Expected:**

- Beneficiary is always stored request owner.

---

# 13. Batch Claim Tests

## BATCH-001 — Multiple successful claims

**Given:**

- Multiple finalized requests.

**Expected:**

- All requests settle in one transaction.
- Each request is processed once.

---

## BATCH-002 — Mixed mint and redeem batch

**Expected:**

- A single batch may contain both request types.
- Each request uses its own epoch/type data.

---

## BATCH-003 — Caller order preserved

**Given:**

`claimMany([5, 2, 9])`

**Expected:**

- Requests are processed in `[5, 2, 9]` order.
- No sorting is required.

---

## BATCH-004 — Empty batch rejected

**Expected:**

- `claimMany([])` reverts.

---

## BATCH-005 — Duplicate request ID

**Given:**

`claimMany([5, 5])`

**Expected:**

- Entire transaction reverts.
- Request 5 is not partially settled.

---

## BATCH-006 — Already claimed request

**Expected:**

- Entire batch reverts.
- No earlier request in the batch remains settled.

---

## BATCH-007 — One request fails

**Expected:**

- Entire batch reverts.
- All requests retain their pre-batch state.
- No NFT is permanently burned.
- No WSK mint/burn remains.
- No USDC transfer remains.

---

## BATCH-008 — Third party executes batch

**Expected:**

- Any address may execute a valid batch.
- Beneficiaries remain request owners.

---

# 14. Pause / Wind-Down Tests

## PAUSE-001 — Manager can wind down

**Expected:**

- Manager can call `pause(finalNAV)`.
- Current epoch is finalized.
- No new epoch is created.

---

## PAUSE-002 — Non-manager cannot wind down

**Expected:**

- Revert.
- State unchanged.

---

## PAUSE-003 — Wind-down is irreversible

**Expected:**

- No unpause operation exists.
- Once wind-down occurs, new fund operations cannot resume.

---

## PAUSE-004 — New mint blocked

After wind-down:

- New mint request reverts.

---

## PAUSE-005 — New redeem blocked

After wind-down:

- New redeem request reverts.

---

## PAUSE-006 — New epoch transition blocked

After wind-down:

- `transitionEpoch()` reverts.

---

## PAUSE-007 — Existing mint can still claim

**Given:**

- Mint request was created before wind-down.
- Its epoch is finalized.

**Expected:**

- Claim succeeds after wind-down.

---

## PAUSE-008 — Existing redeem can still claim

**Given:**

- Redeem request was created before wind-down.
- Its epoch is finalized.
- liquidWallet has sufficient liquidity.

**Expected:**

- Claim succeeds after wind-down.

---

## PAUSE-009 — WSK transfers remain active

After wind-down:

- `transfer()` continues to work.
- `transferFrom()` continues to work.
- `approve()` continues to work.

---

## PAUSE-010 — Wind-down with pending requests

**Expected:**

- Wind-down succeeds.
- Pending requests do not block finalization.
- Existing requests remain claimable.

---

## PAUSE-011 — Wind-down immediately after deployment

**Expected:**

- Wind-down is allowed.
- Current active epoch is finalized with finalNAV.
- No subsequent epoch is created.

---

# 15. Direct Transfer Tests

## DIRECT-001 — Direct USDC transfer to Vault

**When:**

- User sends USDC directly to Vault without a mint request.

**Expected:**

- No request is created.
- No Pending NFT is created.
- No user entitlement is created.
- USDC remains fund property.
- No rescue/refund operation is required.

---

## DIRECT-002 — Direct WSK transfer to Vault

**When:**

- User transfers WSK directly to Vault without a redeem request.

**Expected:**

- No redemption request is created.
- WSK is not automatically burned.
- WSK remains held by Vault.
- Total supply is unchanged.

---

# 16. Supply / NAV Edge Cases

## EDGE-001 — Supply greater than zero requires positive NAV

**Expected:**

- Finalized state with totalSupply > 0 and NAV = 0 is invalid.

---

## EDGE-002 — Zero supply and empty fund

**Expected:**

- NAV may be zero.
- Future minting remains possible.
- The fund is not permanently dead.

---

## EDGE-003 — Previous valid reference rate retained

**Expected:**

- When supply becomes zero, implementation retains sufficient prior reference-rate information to support future operations.
- Exact storage implementation is not prescribed by this test specification.

---

## EDGE-004 — Empty epochs after supply reaches zero

**Expected:**

- Epoch transitions remain possible.
- Multiple empty epochs are valid.

---

## EDGE-005 — Dust assets

**Expected:**

- Small residual/dust assets do not prevent epoch transition.
- No dust sweep mechanism is required.

---

# 17. Access Control Tests

## AUTH-001 — Manager-only transition

Only manager succeeds.

---

## AUTH-002 — Manager-only wind-down

Only manager succeeds.

---

## AUTH-003 — User request operations

Users can create valid requests without manager interaction.

---

## AUTH-004 — Permissionless claims

Any address may claim a valid finalized request.

---

# 18. Immutability Tests

## IMM-001 — Manager cannot be changed

**Expected:**

- No manager replacement mechanism exists.

---

## IMM-002 — USDC address cannot be changed

**Expected:**

- No V1 setter exists.

---

## IMM-003 — Vault wallet cannot be changed

**Expected:**

- No V1 setter exists.

---

## IMM-004 — Liquid wallet cannot be changed

**Expected:**

- No V1 setter exists.

---

## IMM-005 — Fee wallet cannot be changed

**Expected:**

- No V1 setter exists.

---

## IMM-006 — WSK Vault authority cannot be changed

**Expected:**

- No V1 `setVault()` mechanism exists.

---

## IMM-007 — No upgrade proxy

**Expected:**

- V1 is deployed as a non-upgradeable implementation.
- No upgrade authority can replace implementation behavior.

---

# 19. Atomicity and Security Tests

## SEC-001 — Reentrancy protection

Attempt reentrant behavior through relevant external token calls or malicious mock contracts.

**Expected:**

- No request can be settled twice.
- No funds can be withdrawn twice.
- No NFT can be burned before a failed settlement is safely reverted.

---

## SEC-002 — Claim state ordering

**Expected:**

- A request cannot be successfully claimed twice, including through reentrant execution.

---

## SEC-003 — Failed external USDC transfer

**Expected:**

- Claim reverts.
- Request remains unclaimed.
- NFT remains.
- No partial accounting mutation remains.

---

## SEC-004 — Failed external WSK operation

**Expected:**

- Claim/request transaction reverts atomically.
- No partial settlement remains.

---

## SEC-005 — Batch rollback

Use a batch where an early request would succeed but a later request fails.

**Expected:**

- Entire batch is reverted.
- Early request is restored to unclaimed state.
- Early NFT remains.
- No partial fund movement remains.

---

# 20. Event Tests

The exact Solidity event declarations may be implemented according to the AI specification, but externally observable event information shall cover the following semantics.

## EVENT-001 — Mint request

Expected event information:

- requestId
- user
- USDC amount
- epoch

---

## EVENT-002 — Redeem request

Expected event information:

- requestId
- user
- gross WSK amount
- fee amount
- epoch

---

## EVENT-003 — Epoch transition

Expected event information:

- finalized epoch
- NAV
- end block

---

## EVENT-004 — Mint claim

Expected event information:

- requestId
- user
- WSK amount

---

## EVENT-005 — Redeem claim

Expected event information:

- requestId
- user
- WSK amount
- USDC amount

---

# 21. Invariants

The following properties shall hold throughout normal operation.

### INV-001 — Request ID uniqueness

Every successful request has a unique positive requestId.

### INV-002 — Request ID monotonicity

Request IDs increase by exactly one.

### INV-003 — Epoch immutability

A request's epoch never changes.

### INV-004 — Request owner immutability

A request's owner never changes.

### INV-005 — Finalized NAV immutability

A finalized epoch NAV never changes.

### INV-006 — Pending mint does not mint WSK

Before successful claim, a pending mint does not increase WSK supply.

### INV-007 — Pending redeem does not burn WSK

Before successful claim, a pending redeem does not reduce WSK supply.

### INV-008 — Redeem fee remains WSK

The redemption fee is transferred in WSK and is not burned.

### INV-009 — Claim beneficiary

Settlement always goes to request.owner.

### INV-010 — Claim atomicity

A failed claim leaves the request economically unsettled.

### INV-011 — NFT/request correspondence

Every unclaimed request has its corresponding Pending NFT.

### INV-012 — Successful claim consumes NFT

A successfully claimed request no longer has an active Pending NFT.

### INV-013 — Post-wind-down settlement

Pre-wind-down requests remain claimable after wind-down.

### INV-014 — No new fund operation after wind-down

No new mint, redeem, or epoch transition occurs after wind-down.

### INV-015 — ERC-20 transferability after wind-down

WSK transfers and approvals remain functional after wind-down.

---

# 22. Recommended Property-Based / Fuzz Tests

The implementation should include fuzz testing for:

1. Random positive mint amounts.
2. Random positive redeem amounts.
3. Random positive NAV values.
4. Random sequences of empty and non-empty epochs.
5. Random request ordering.
6. Mixed mint/redeem batches.
7. Duplicate request IDs.
8. Repeated failed claims followed by successful claims.
9. Random fee-rounding boundaries.
10. Values near uint256 arithmetic limits.
11. Random transfer activity involving feeWallet.
12. Random WSK direct transfers to Vault.
13. Random USDC direct transfers to Vault.
14. Wind-down at arbitrary valid lifecycle points.

For every fuzz case, invariants in Section 21 must remain true.

---

# 23. Acceptance Gate

The implementation is considered V1-complete only when:

- All mandatory tests pass.
- All invariants pass under unit and fuzz testing.
- No known test exposes double settlement.
- No known test exposes incorrect epoch/NAV assignment.
- No known test exposes incorrect redeem fee accounting.
- No known test exposes partial state mutation after failed claims.
- Post-wind-down settlement behavior matches the SRS.
- V1 has no upgrade path.
- Fixed V1 addresses cannot be replaced.
- Historical request and epoch data remain queryable.

---

# 24. Explicitly Out of Scope

The following are not V1 acceptance requirements:

- Portfolio performance correctness.
- Off-chain NAV calculation correctness.
- Manager honesty or key custody.
- DEX market-price correctness.
- Velodrome pool/gauge creation.
- Liquidity mining economics.
- DeFiLlama integration.
- OPScan listing/verification workflow.
- V1 → V2 migration contract.
- Governance/multisig.
- Multi-chain support.
- Multi-stablecoin settlement.
- Automatic keeper settlement.
- Request cancellation.
- Rescue/refund of accidental direct transfers.
- Dust sweeping.

These may be tested separately when their respective integrations are implemented.

---

# 25. Final Test Philosophy

The primary correctness model for Wellstake V1 is:

**request → epoch assignment → epoch NAV finalization → permissionless settlement → atomic claim completion**

The test suite must prove that:

1. economic entitlement is determined by the request's epoch;
2. all requests in the same epoch use the same finalized NAV;
3. pending operations do not prematurely alter settled accounting;
4. claim is atomic;
5. claim cannot be repeated;
6. post-wind-down settlement remains possible for existing requests;
7. no new fund operations occur after wind-down;
8. V1 remains intentionally immutable and simple.
