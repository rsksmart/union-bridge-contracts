# Breaking Changes

## [v0.5.1]

### Public Functions - Changed Names or Parameters (v0.5.1)

1. **`validatePeginStatus` and `validatePegoutStatus` → `validatePegStatus`** (in `IStreamManager`)
   - **Old signatures**:
     - `function validatePeginStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus) external view returns (StreamPosition memory)`
     - `function validatePegoutStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus) external view returns (StreamPosition memory, uint128 committeeId, uint8 pegoutConfirmations)`
   - **New signatures** (overloaded):
     - `function validatePegStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus) external view returns (StreamPosition memory, uint128 committeeId, uint8 pegoutConfirmations)` — validates a single expected status
     - `function validatePegStatus(bytes32 _acceptPeginTxid, PegStatus _statusA, PegStatus _statusB) external view returns (StreamPosition memory, uint128 committeeId, uint8 pegoutConfirmations)` — validates that the current status matches either of two acceptable statuses
   - **Impact**: Both old functions are removed. Callers of `validatePeginStatus` must switch to the single-argument overload of `validatePegStatus` and handle the two additional return values (`committeeId`, `pegoutConfirmations`). Callers of `validatePegoutStatus` must switch to the same single-argument overload.

2. **`getPartialSignatures` return type changed** (in `ISignatureManager`)
   - **Old signature**: `function getPartialSignatures(bytes32 _txid) external view returns (SignatureData[] memory, uint8 missingSignatures, uint8 missingNonces, uint128 committeeId)`
   - **New signature**: `function getPartialSignatures(bytes32 _txid) external view returns (SignatureData[] memory, uint8 missingNonces, uint128 committeeId)`
   - **Change**: `missingSignatures` return value removed.
   - **Impact**: Callers must update destructuring to remove the `missingSignatures` position.

### Public Functions - Removed (v0.5.1)

1. **`validatePeginStatus`** (in `IStreamManager`) — replaced by `validatePegStatus` (see above).
2. **`validatePegoutStatus`** (in `IStreamManager`) — replaced by `validatePegStatus` (see above).
3. **`_isInputNotRevealed`** (in `ChallengeManager`) — was a `public pure` helper; removed along with its OP_RETURN output validation logic.

### Errors - Removed (v0.5.1)

1. **`InvalidInputNotRevealedOutput`** (in `IChallengeManager`) — removed; OP_RETURN output is no longer required on `INPUT_NOT_REVEALED_TX`.
2. **`InvalidRevealedOutput`** (in `IChallengeManager`) — removed; the corresponding OP_RETURN-based check is gone.
3. **`UserTakeAlreadySigned`** (in `IOperatorTakeManager`) — removed; `triggerOperatorTake` can now be called even when all committee signatures are present (see Workflow Changes below).

### Errors - New (v0.5.1)

1. **`UserTakeNotCancelled(bytes32 acceptPeginTxid)`** (in `IOperatorTakeManager`) — thrown when the operator tries to call `registerAdvanceFunds` before cancelling the user take flow (i.e., `cancelUserTakeTxBlockNumber` is still zero).

### Bitcoin Transaction Format Changes (v0.5.1)

1. **`INPUT_NOT_REVEALED_TX` output structure changed**
   - **Old**: First output was an OP_RETURN (unspendable, empty data); speedup outputs followed at indices `1..N`.
   - **New**: OP_RETURN output removed. Speedup outputs are now at indices `0..N-1` (one per committee member).
   - **Impact**: The expected output count is now exactly `committeeMembers.length` (previously `1 + committeeMembers.length`). Integrations that construct or validate `INPUT_NOT_REVEALED_TX` must remove the OP_RETURN output and re-index the speedup outputs.

2. **`ADVANCE_FUNDS_TX` OP_RETURN script format changed**
   - **Old script**: `OP_RETURN <pegout_id_32_bytes>` (push opcode omitted — invalid OP_RETURN format)
   - **New script**: `OP_RETURN OP_PUSHBYTES_32 <pegout_id_32_bytes>` (valid standard OP_RETURN format)
   - **Impact**: Integrations that construct or parse the OP_RETURN output of `ADVANCE_FUNDS_TX` must include the `OP_PUSHBYTES_32` (`0x20`) byte before the 32-byte pegout ID. The raw script is now `[0x6a, 0x20, <32 bytes>]` instead of `[0x6a, <32 bytes>]`.

### Workflow Changes (v0.5.1)

1. **`triggerOperatorTake` no longer blocked when all signatures are present**
   - Previously, calling `triggerOperatorTake` while the peg-out was in `USER_TAKE` status and all committee signatures were collected reverted with `UserTakeAlreadySigned`.
   - Now, `triggerOperatorTake` can be called once the user take timeout has expired regardless of whether all signatures are present. This handles the edge case where signatures were collected but the `USER_TAKE_TX` was never submitted on-chain.

2. **`registerUserTake` now accepts `OP_SELECTED` status**
   - Previously, `registerUserTake` only accepted peg-outs in `USER_TAKE` status.
   - Now it also accepts `OP_SELECTED` status, allowing a committee member to register a valid user take Bitcoin transaction even after the operator take flow has been triggered.

3. **`registerAdvanceFunds` requires user take to be explicitly cancelled first**
   - The previous check (`cancelUserTakeTxBlockNumber < blockNumber`) allowed advancing funds without a cancellation record if `cancelUserTakeTxBlockNumber` was 0 (default).
   - Now, if `cancelUserTakeTxBlockNumber == 0`, the call reverts with `UserTakeNotCancelled`. The operator must call `registerCancelUserTake` before `registerAdvanceFunds`.
   - **Impact**: Any integration that called `registerAdvanceFunds` without first registering a cancel user take transaction must be updated to include the `registerCancelUserTake` step.

## [v0.5.0]

### Contract Restructuring (v0.5.0)

1. **OperatorTakeManager introduced – split from PegoutManager**
   - **Reason**: PegoutManager's operator-take flow is now a separate deployable contract for cleaner separation of concerns.
   - **Change**: `registerAdvanceFunds`, `registerReimbursementKickoff`, `registerOperatorTake`, `registerOperatorWon`, and `triggerOperatorTake` were moved from `PegoutManager` to the new `OperatorTakeManager` contract.
   - **Impact**: Callers of those functions must now target `OperatorTakeManager`. Deployment must include `OperatorTakeManager`. AccessManager now exposes `revertIfNotChallengeManager` and `setOperatorTakeManager` to wire the new contract into the permission model.

### Public Functions - Changed Names or Parameters (v0.5.0)

1. **`depositAggregatedKey` → `depositAggregatedKeys`** (in `ICommitteeRegistry`)
   - **Old signature**: `function depositAggregatedKey(uint128 _committeeId, bytes memory _aggregatedKey) external`
   - **New signature**: `function depositAggregatedKeys(uint128 _committeeId, bytes memory _takeAggregatedKey, bytes memory _disputeAggregatedKey) external`
   - **Impact**: Members must now supply both the take aggregated key and the dispute aggregated key in a single call.

2. **`isMemberInCommittee` → `validateMemberInCommittee`** (in `ICommitteeRegistry`)
   - **Old signature**: `function isMemberInCommittee(uint128 _committeeId, address _memberAddress) external view returns (bool)`
   - **New signature**: `function validateMemberInCommittee(uint128 _committeeId, address _memberAddress) external view`
   - **Change**: Function no longer returns a boolean; it reverts if the member is not in the committee.
   - **Impact**: Callers that checked the return value must now use a try/catch or restructure to expect revert-on-failure semantics.

3. **`getCommitteeDisputeKeys` return type changed** (in `ICommitteeRegistry`)
   - **Old signature**: `function getCommitteeDisputeKeys(uint128 _committeeId) external view returns (bytes32[] memory)`
   - **New signature**: `function getCommitteeDisputeKeys(uint128 _committeeId) external view returns (CompactPubKey[] memory)`
   - **Impact**: Callers must update to handle `CompactPubKey` structs (`bytes1 parity`, `bytes32 xOnly`) instead of raw `bytes32` values.

4. **`getOperatorDisputeData` return type extended** (in `ICommitteeRegistry`)
   - **Old return**: `(address operatorAddress, bytes32 disputePubKey)`
   - **New return**: `(address operatorAddress, CompactPubKey memory disputePubKey, CompactPubKey memory takePubKey)`
   - **Impact**: Callers must handle the additional `takePubKey` return value and the change from `bytes32` to `CompactPubKey`.

5. **`getMemberTakePubKey` return type changed** (in `IMemberRegistry`)
   - **Old signature**: `function getMemberTakePubKey(address _address) external view returns (bytes32)`
   - **New signature**: `function getMemberTakePubKey(address _address) external view returns (CompactPubKey memory)`
   - **Impact**: Update callers to use `CompactPubKey` struct.

6. **`getChallengeTempInfo` → `getChallengeInfo`** (in `IChallengeManager`)
   - **Old signature**: `function getChallengeTempInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeTempInfo memory)`
   - **New signature**: `function getChallengeInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeInfo memory)`
   - **Change**: Function and struct renamed.
   - **Impact**: Update callers to use `getChallengeInfo` and the renamed `ChallengeInfo` struct.

7. **`getPegoutTempInfo` → `getPegoutStartInfo`** (in `IPegoutManager`)
   - **Old signature**: `function getPegoutTempInfo(bytes32 _acceptPeginTxid) external view returns (PegoutTempInfo memory)`
   - **New signature**: `function getPegoutStartInfo(bytes32 _acceptPeginTxid) external view returns (PegoutStartInfo memory)`
   - **Change**: Function and struct renamed. `PegoutStartInfo` contains only `userPubKey`, `createdAt`, and `pegoutTxid` (leaner than the old `PegoutTempInfo`).
   - **Impact**: Update callers; access operator-take specific data via `IOperatorTakeManager.getOperatorTakeInfo()`.

8. **`advanceSlot` parameters changed** (in `IStreamManager`)
   - **Old signature**: `function advanceSlot(uint64 _streamId, uint64 _packetNumber, uint64 _slotId) external`
   - **New signature**: `function advanceSlot(bytes32 _acceptPeginTxid) external`
   - **Impact**: Callers must pass the `acceptPeginTxid` instead of explicit stream/packet/slot IDs.

9. **`getEnablerOutputP2TRScriptPub` parameter type changed** (in `IBitcoinManager`)
   - **Old signature**: `function getEnablerOutputP2TRScriptPub(bytes memory _committeePubKey, bytes32[] memory _disputeKeys) external view returns (bytes memory)`
   - **New signature**: `function getEnablerOutputP2TRScriptPub(bytes memory _committeeTakePubKey, CompactPubKey[] memory _disputeKeys) external view returns (bytes memory)`
   - **Impact**: Update callers to pass `CompactPubKey[]` for dispute keys and rename the first parameter semantically.

10. **`validatePegoutMemberOutput` parameter type changed** (in `IBitcoinManager`)
    - **Old signature**: `function validatePegoutMemberOutput(BtcTxOut calldata _pegoutOutput, bytes32 _memberPubKey) external pure`
    - **New signature**: `function validatePegoutMemberOutput(BtcTxOut calldata _pegoutOutput, CompactPubKey calldata _memberPubKey) external pure`
    - **Impact**: Update callers to pass `CompactPubKey`.

11. **`triggerOperatorTake` parameter changed** (in `IOperatorTakeManager`, previously `IPegoutManager`)
    - **Old signature**: `function triggerOperatorTake(bytes32 _pegoutTxid) external`
    - **New signature**: `function triggerOperatorTake(bytes32 _acceptPeginTxid) external`
    - **Change**: Parameter semantics changed from `pegoutTxid` to `acceptPeginTxid`. Function also moved to `IOperatorTakeManager`.
    - **Impact**: Update callers with the correct txid and target the new contract.

### Public Functions - Removed (v0.5.0)

1. **`setUserTakeTimeout`**, **`setOperatorTakeTimeout`** (in `IPegoutManager`) – Removed; replaced by `setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout)` in `IOperatorTakeManager` which sets timeouts per-stream.
2. **`userTakeTimeout`**, **`operatorTakeTimeout`** (in `IPegoutManager`) – Removed; use `takeTimeouts(uint256 streamId)` in `IOperatorTakeManager`.
3. **`getAcceptPeginTxid`** (in `IPegoutManager`) – Removed.
4. **`getPegoutTxid`** (in `IPegoutManager`) – Removed.
5. **`getCommitteePubKey`** (in `IStreamManager`) – Removed; use `getCommitteeTakePubKey` or `getCommitteeDisputePubKey` in `ICommitteeRegistry`.
6. **`registerAdvanceFunds`**, **`registerReimbursementKickoff`**, **`registerOperatorTake`**, **`registerOperatorWon`**, **`triggerOperatorTake`** (in `IPegoutManager`) – Moved to `IOperatorTakeManager`.

### Public Functions - New (v0.5.0)

1. **`demoteOperatorToWatchtower`** (in `ICommitteeRegistry`)
   - **Signature**: `function demoteOperatorToWatchtower(uint128 _committeeId, address _memberAddress) external`
   - **Description**: Owner-only function that demotes an operator to watchtower role within a committee. This is the first step toward a future slashing implementation.

2. **`getCommitteeTakePubKey`**, **`getCommitteeDisputePubKey`** (in `ICommitteeRegistry`)
   - **Signatures**: `function getCommitteeTakePubKey(uint128 _committeeId) external view returns (bytes memory)`; `function getCommitteeDisputePubKey(uint128 _committeeId) external view returns (bytes memory)`
   - **Description**: Returns the aggregated take or dispute public key for a committee.

3. **`getCommitteeMembersLength`** (in `ICommitteeRegistry`)
   - **Signature**: `function getCommitteeMembersLength(uint128 _committeeId) external view returns (uint256)`

4. **`getMemberDisputePubKey`** (in `IMemberRegistry`)
   - **Signature**: `function getMemberDisputePubKey(address _address) external view returns (CompactPubKey memory)`
   - **Description**: Returns the dispute public key for a registered member.

5. **`registerInputNotRevealed`** (in `IChallengeManager`)
   - **Signature**: `function registerInputNotRevealed(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _inputNotRevealed) external`
   - **Description**: Registers proof that the operator did not reveal the input within the required window.

6. **`registerStopOperatorWon`** (in `IChallengeManager`)
   - **Signature**: `function registerStopOperatorWon(bytes32 _acceptPeginTxid, BtcTxSPVProof calldata _stopOperatorWon) external`
   - **Description**: Registers a stop-operator-won transaction to halt an invalid operator-won claim.

7. **Pegout queue** (in `IPegoutManager`) — `enqueuePegout`, `dequeuePegout`, `tryProcessEnqueuedPegout`, `getPegoutQueueLength`
   - **Background**: Previously, `requestPegout` reverted if a peg-out was already in process for the stream. Users had to retry off-chain until the slot freed up.
   - **Change**: Users can now call `enqueuePegout` to place their request in a per-stream queue while a peg-out is in process. Once the current peg-out completes, the next request is automatically promoted via `tryProcessEnqueuedPegout` (callable by anyone) or manually via `dequeuePegout`.
   - **Signatures**:
     - `function enqueuePegout(bytes memory _userPubKey) external payable` — joins the queue; sends RBTC with the call.
     - `function dequeuePegout(uint64 _streamId) external` — removes and refunds the first queued request (called by the queued user to cancel).
     - `function tryProcessEnqueuedPegout(uint64 _streamId) external` — promotes the next queued request if the stream is free.
     - `function getPegoutQueueLength(uint64 _streamId) external view returns (uint64)` — returns the current queue depth.
   - **Impact**: Integrations that previously looped or retried `requestPegout` should switch to `enqueuePegout`. UIs should surface queue position via `getPegoutQueueLength`.

10. **`setTakeTimeout`** (in `IOperatorTakeManager`)
    - **Signature**: `function setTakeTimeout(uint64 _streamId, TakeTimeout memory _timeout) external`
    - **Description**: Sets per-stream user-take and operator-take timeouts (replaces the old global `setUserTakeTimeout` / `setOperatorTakeTimeout`).

11. **`takeTimeouts`** (in `IOperatorTakeManager`)
    - **Signature**: `function takeTimeouts(uint256 streamId) external view returns (uint256 userTake, uint256 operatorTake)`

12. **`getOperatorTakeInfo`** (in `IOperatorTakeManager`)
    - **Signature**: `function getOperatorTakeInfo(bytes32 _acceptPeginTxid) external view returns (OperatorTakeInfo memory)`

13. **`getCancelUserTakeTxBlockNumber`** (in `IOperatorTakeManager`)
    - **Signature**: `function getCancelUserTakeTxBlockNumber(bytes32 _acceptPeginTxid) external view returns (int256 blockNumber)`

14. **`registerCancelUserTake`** (in `IOperatorTakeManager`)
    - **Signature**: `function registerCancelUserTake(BtcTxSPVProof calldata _cancelUserTakeSPVProof) external`
    - **Description**: Registers a cancel-user-take transaction.

15. **`getMissingOperatorTakeHashes`** (in `IOperatorTakeManager`)
    - **Signature**: `function getMissingOperatorTakeHashes(bytes32 _acceptPeginTxid) external view returns (uint8)`

16. **`setRejectPeginConfirmations`** (in `IStreamManager`)
    - **Signature**: `function setRejectPeginConfirmations(uint64 _streamId, uint8 _confirmations) external`
    - **Description**: Sets the confirmation count required for reject-pegin and user-reimbursement transactions (must be ≤ `peginConfirmations`).

17. **`validatePeginStatus`**, **`validatePegoutStatus`** (in `IStreamManager`)
    - **Signatures**: `function validatePeginStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus) external view`; `function validatePegoutStatus(bytes32 _acceptPeginTxid, PegStatus _expectedStatus) external view`

18. **`getFilledSlotsCount`** (in `IStreamManager`)
    - **Signature**: `function getFilledSlotsCount(uint64 _streamId) external view returns (uint64)`

19. **`revertIfNotChallengeManager`** (in `IAccessManager`)
    - **Signature**: `function revertIfNotChallengeManager(address _caller) external view`

20. **`setOperatorTakeManager`** (in `IPauseManager`)
    - **Signature**: `function setOperatorTakeManager(address _operatorTakeManager) external`
    - **Description**: Wires OperatorTakeManager into the AccessManager/PauseManager system (address can only be set once).

### Struct Changes (v0.5.0)

1. **New `CompactPubKey` struct** (in `IMemberRegistry`)
   - **Definition**: `struct CompactPubKey { bytes1 parity; bytes32 xOnly; }`
   - **Impact**: Replaces raw `bytes32` public key values throughout the interfaces (dispute keys, take keys, member pub keys). All callers working with public keys must use this struct.

2. **`ChallengeTempInfo` → `ChallengeInfo`** (in `IChallengeManager`) – Struct renamed.

3. **`PegoutTempInfo` → `PegoutStartInfo`** (in `IPegoutManager`) – Struct renamed and slimmed; operator-take fields moved to `OperatorTakeInfo` in `IOperatorTakeManager`.

4. **New `OperatorTakeInfo` struct** (in `IOperatorTakeManager`)
   - Stores operator take state: `operatorTakeUpdatedAt`, `operatorTakeAddress`, `operatorTakePubKey`, `operatorDisputePubKey`, `pegoutId`, `advanceFundsBlockNumber`, `reimbursementKickoffTxid`.

5. **New `TakeTimeout` struct** (in `IOperatorTakeManager`)
   - **Definition**: `struct TakeTimeout { uint256 userTake; uint256 operatorTake; }`
   - **Impact**: Replaces the previous global timeout state variables with per-stream configuration.

6. **New `PegoutRequest` struct** (in `IPegoutManager`)
   - **Definition**: `struct PegoutRequest { bytes userPubKey; address userAddress; }`

7. **Structs moved from `ICommitteeRegistry` to `IMemberRegistry`**: `Balance`, `ApplicationData`, `ECDSAPublicKey`, `RSAPublicKey`, `MemberRegistrationKeys`, `MemberKeys`, `Member`.
   - **Impact**: Update imports; use `IMemberRegistry` to reference these types.

### Events - Changed (v0.5.0)

1. **`MemberInfoDeposited`** (in `ICommitteeRegistry`)
   - **Old signature**: `event MemberInfoDeposited(uint128 indexed committeeId, address indexed member, bytes aggregatedKey)`
   - **New signature**: `event MemberInfoDeposited(uint128 indexed committeeId, address indexed member, bytes aggregatedTakeKey, bytes aggregatedDisputeKey)`
   - **Impact**: Event listeners must handle the two key fields.

2. **`AdvanceFundsRegistered`**, **`ReimbursementKickoffRegistered`** (moved from `IPegoutManager` to `IOperatorTakeManager`)
   - **Impact**: Event listeners must subscribe to `OperatorTakeManager` instead of `PegoutManager`.

### Events - Removed (v0.5.0)

1. **`UserTakeTimeoutUpdated`**, **`OperatorTakeTimeoutUpdated`** (in `IPegoutManager`) – Replaced by `TakeTimeoutUpdated` in `IOperatorTakeManager`.

### Events - New (v0.5.0)

1. **`OperatorDemotedToWatchtower`** (in `ICommitteeRegistry`)
   - **Signature**: `event OperatorDemotedToWatchtower(uint128 indexed committeeId, address indexed memberAddress)`

2. **`InputNotRevealedRegistered`**, **`StopOperatorWonRegistered`** (in `IChallengeManager`)

3. **`PegoutEnqueued`** (in `IPegoutManager`)
   - **Signature**: `event PegoutEnqueued(uint64 indexed streamId, bytes userPubKey, address userAddress)`

4. **`CancelUserTakeRegistered`** (in `IOperatorTakeManager`)
   - **Signature**: `event CancelUserTakeRegistered(bytes32 indexed acceptPeginTxid)`

5. **`TakeTimeoutUpdated`** (in `IOperatorTakeManager`)
   - **Signature**: `event TakeTimeoutUpdated(uint64 indexed streamId, TakeTimeout newTimeout)`

6. **`RejectPeginConfirmationsUpdated`** (in `IStreamManager`)
   - **Signature**: `event RejectPeginConfirmationsUpdated(uint64 _streamId, uint8 _confirmations)`

### Errors - Changed (v0.5.0)

1. **`PublicKeyMismatch` → `PublicKeyMismatchECDSA`** (in `IMemberRegistry`)
   - **Old**: `error PublicKeyMismatch(PublicKeyType keyType, bytes32 currentPubKey, bytes32 newPubKey)`
   - **New**: `error PublicKeyMismatchECDSA(PublicKeyType keyType, CompactPubKey registeredPubKey, CompactPubKey submittedPubKey)`

2. **New `PublicKeyMismatchRSA`** (in `IMemberRegistry`)
   - **Signature**: `error PublicKeyMismatchRSA(bytes32 registeredKeyHash, bytes32 submittedKeyHash)`

### Errors - Removed (v0.5.0)

1. **`InvalidPublicKeyLength`** (in `IBitcoinManager`) – Removed.

### Errors - New (v0.5.0)

1. **IAccessManager**: `CallerIsNotChallengeManager(address _caller)`.
2. **ICommitteeRegistry**: `InvalidSameAggregatedKeys`, `CommitteeIsNotActive(uint128 committeeId)`, `MemberIsNotOperatorInCommittee(uint128 committeeId, address memberAddress)`, `DemotionViolatesMinOperators(uint128 committeeId, uint256 currentOperators, uint256 minOperators)`.
3. **IChallengeManager**: `RevealTxidNotMatch`, `InvalidInputNotRevealedInputCount`, `InvalidInputNotRevealedOutputCount`, `InvalidInputNotRevealedOutput`, `InvalidRevealedOutput`, `InvalidRevealedOutputCount`, `NoChallengeRegistered`, `InvalidStopOperatorWonTxid`, `InvalidStopOperatorWonInputCount`.
4. **IOperatorTakeManager**: `WrongUserAmount`, `OperatorTakeAddressNotMatch`, `OperatorTakeDataNotFound`, `InvalidTimeoutsLength`, `InvalidTimeout`, `UserTakeTimeoutNotExpired`, `UserTakeAlreadySigned`, `OperatorTakeTimeoutNotExpired`, `AdvanceFundsBeforeCancelUserTake`, `CancelUserTakeAlreadyRegistered`.
5. **IStreamManager**: `InvalidRejectPeginConfirmations(uint8 confirmations)`, `RejectPeginConfirmationsExceedsPegin(uint8 rejectPeginConfirmations, uint8 peginConfirmations)`, `PeginConfirmationsLowerThanRejectPegin(uint8 peginConfirmations, uint8 rejectPeginConfirmations)`.

### New Contracts and Interfaces (v0.5.0)

1. **OperatorTakeManager** / **IOperatorTakeManager** – New contract and interface for operator-take flow (advance funds, kickoff, operator take, operator won). Inherits `PegManagerBase`.

### Workflow Changes (v0.5.0)

1. **Operator-take functions now on OperatorTakeManager** – All calls to `registerAdvanceFunds`, `registerReimbursementKickoff`, `registerOperatorTake`, `registerOperatorWon`, and `triggerOperatorTake` must be directed to `OperatorTakeManager` instead of `PegoutManager`.
2. **Per-stream timeouts** – User-take and operator-take timeouts are now configured per-stream via `OperatorTakeManager.setTakeTimeout(streamId, TakeTimeout)` instead of global setters on `PegoutManager`.
3. **Pegout queueing** – `requestPegout` no longer reverts when a stream is busy. Subsequent requests must use `PegoutManager.enqueuePegout()` to join the per-stream queue. Once the active peg-out completes, the next request is automatically promoted; anyone can also trigger promotion by calling `tryProcessEnqueuedPegout`. Integrations must handle the queued state and surface queue position to users.
4. **rejectPeginConfirmations** – `StreamManager` now tracks a separate confirmation count for reject-pegin and user-reimbursement transactions, configurable via `setRejectPeginConfirmations`. This must be ≤ `peginConfirmations`.

## [v0.4.3-alpha]

### Deployment Script Changes (v0.4.3-alpha)

1. **RSK Regtest deployments now use the native Bridge precompile**
   - **Reason**: RSK regtest nodes run the real PowPeg bridge precompile, so deploying a mock diverges from mainnet/testnet behavior.
   - **Change**: `01_DeployImplAndProxy.s.sol` no longer deploys a `BridgeMock` when `block.chainid == ChainIds.RSK_REGTEST` (33). It now wires `RbtcBridge` to the native bridge at `RSK_BRIDGE_ADDRESS` (`0x0000000000000000000000000000000001000006`), same as mainnet/testnet. `BridgeMock` is still deployed for the Foundry `LOCAL` chain id (31337).
   - **Impact**: Environments deploying to RSK regtest that relied on `BridgeMock` (e.g. to manipulate bridge state in tests) must run under the `LOCAL` chain id instead. Deployed contract ABIs are unchanged.

## [v0.4.2-alpha]

### Base Event semantics (`RbtcBridge`) (v0.4.2-alpha)

1. **`setBaseEvent` – duplicate guard is per block, not lifetime**
   - **Reason**: The previous check (`bridge.getBaseEvent().length > 0`) blocked any new base event after one was set, even across different peg-outs/blocks. Now a new base event can be set in a later block, overriding the previous one. Only multiple calls in the same block must be prevented.
   - **Change**: `RbtcBridge.setBaseEvent` no longer reads `bridge.getBaseEvent()`. It reverts with `BaseEventAlreadySet` only if `latestBaseEventBlock == block.number`. A new `uint256 public latestBaseEventBlock` records the block of the last successful call.
   - **Impact**:
     - Integrations that assumed “base event can only be set once ever” must update to the new behavior: `setBaseEvent` can only be set once per block, but it can be called again in a later block, and the new call overwrites the previous value set.
     - Two `setBaseEvent` calls in the **same block** still revert with `BaseEventAlreadySet` on the second.

### Struct and Storage Layout Changes (v0.4.2-alpha)

1. **`RbtcBridge`**
   - **Added**: `latestBaseEventBlock` (`uint256`).

## [v0.4.1-alpha]

### Bitcoin Transaction Script Validation (v0.4.1-alpha)

1. **OP_RETURN Pegout ID script now uses OP_PUSHBYTES_32**
   - **Reason**: Bitcoin script pub key has OP_PUSHBYTES_32 opcode after OP_RETURN to push the pegout id (bytes32) to the stack.
   - **Change**: `BtcScriptParser.getPegoutIdScript` now encodes the pegoutId OP_RETURN output as `OP_RETURN OP_PUSHBYTES_32 <32‑byte pegoutId>` instead of `OP_RETURN <pegoutId>` without an explicit push opcode.
   - **Impact**: Any integration that was constructing the pegoutId output without `OP_PUSHBYTES_32` must update their Bitcoin transaction builder; scripts missing the `0x20` push opcode will now fail validation.

## [v0.4.0-alpha]

### Contract Restructuring (v0.4.0-alpha)

1. **PegoutManager split – ChallengeManager introduced**
   - **Reason**: PegoutManager reached 24 kB contract size limit.
   - **Change**: `registerChallenge` and `registerInputRevealed` were moved from `PegoutManager` to a new contract `ChallengeManager`.
   - **Impact**: Callers must invoke `ChallengeManager.registerChallenge` and `ChallengeManager.registerInputRevealed` instead of `PegoutManager`. Deployment and initialization must include the new `ChallengeManager` contract.

2. **AccessControl replaced by AccessManager**
   - **Old**: Access control logic was embedded in multiple contracts via `AccessControl` (abstract).
   - **New**: A dedicated authorization contract `AccessManager` replaces `AccessControl`. `AccessManager` inherits from `PauseManager` and is used as the single authority for permissions and pausing.
   - **Impact**: Deployment scripts and initializers must deploy and pass `AccessManager` instead of distributing multiple addresses. Contracts now take a single `IAccessManager` (or `AccessManager`) address for permission checks. The interfaces `IAccessControl` and contract `AccessControl` were removed.

### Public Functions - Changed Names or Parameters (v0.4.0-alpha)

1. **`reAddCommitteeMembers` → `reAddCandidateToStream`** (in `IMemberRegistry`)
   - **Old signature**: `function reAddCommitteeMembers(Committee memory _discardedCommittee) external`
   - **New signature**: `function reAddCandidateToStream(StreamDenomination _denomination, CommitteeMember memory _member) external`
   - **Changes**: Function renamed; takes a single stream denomination and one `CommitteeMember` instead of a full `Committee`. Must be called per member.
   - **Impact**: Callers must loop over committee members and call `reAddCandidateToStream` for each with the stream denomination.

### Public Functions - Removed (v0.4.0-alpha)

1. **`getOperatorDisputeKeys`** (in `ICommitteeRegistry`)
   - **Old signature**: `function getOperatorDisputeKeys(uint128 _committeeId) external view returns (bytes32[] memory)`
   - **Change**: Removed; enabler outputs now use all committee members’ dispute keys, not only operators.
   - **Replacement**: Use `getCommitteeDisputeKeys(uint128 _committeeId)` which returns dispute keys for all committee members.
   - **Impact**: Callers that relied on operator-only dispute keys must switch to `getCommitteeDisputeKeys` and, if needed, filter by operator role off-chain or accept the full committee key set.

2. **`setPeginManager`** (in `IBitcoinManager`) – Removed; PeginManager is no longer set on BitcoinManager.
3. **`setPeginManager`**, **`setPegoutManager`**, **`setStreamManager`** (in `ICommitteeRegistry`) – Removed; use AccessManager and deployment flow instead.
4. **`setCommitteeRegistry`**, **`setStreamManager`**, **`setBridge`** (in `IMemberRegistry`) – Removed; set during initialization or via upgrade.
5. **`setPeginManager`**, **`setPegoutManager`** (in `IRbtcBridge`) – Removed; RbtcBridge now receives `IAccessManager` at init and no longer has these setters.

### Public Functions - New (v0.4.0-alpha)

1. **`registerOperatorWon`** (in `IPegoutManager`)
   - **Signature**: `function registerOperatorWon(BtcTxSPVProof memory _pegoutTxSPVProof) external`
   - **Description**: Registers the operator-won transaction when the operator wins a challenge; marks the slot as paid. Call when peg status is `OPERATOR_TAKE`. Must be called after `registerOperatorTake` when the operator wins.
   - **Impact**: Integrations implementing the operator-take flow must call this to complete the operator-won path.

2. **`getAcceptPeginTxid`** (in `IPegoutManager`)
   - **Signature**: `function getAcceptPeginTxid(bytes32 _pegoutTxid) external view returns (bytes32)`
   - **Description**: Returns the accept peg-in transaction id for a given peg-out transaction id.
   - **Impact**: Use for reverse lookup from pegout txid to accept pegin txid.

3. **`getChallengeInfo`** (in `IChallengeManager`)
   - **Signature**: `function getChallengeInfo(bytes32 _acceptPeginTxid) external view returns (ChallengeInfo memory)`
   - **Description**: Returns challenge information (challengeTxid, revealTxid) for a given accept peg-in txid.
   - **Impact**: Query challenge state when integrating with ChallengeManager.

4. **`isWhitelisted`**, **`whitelistAddress`**, **`whitelistAddresses`**, **`unwhitelistAddress`**, **`unwhitelistAddresses`** (in `ICommitteeRegistry`)
   - **Description**: Whitelist management; addresses must be whitelisted before they can apply to a stream. `setWhitelister` sets the role allowed to whitelist/unwhitelist.
   - **Impact**: Operators must whitelist candidate addresses; update apply-to-stream flow to respect whitelist.

5. **`isMemberInCommittee`** (in `ICommitteeRegistry`)
   - **Signature**: `function isMemberInCommittee(uint128 _committeeId, address _memberAddress) external view returns (bool)`
   - **Description**: Returns whether an address is a member of a given committee.
   - **Impact**: Use for membership checks without iterating committee members.

6. **`setWhitelister`** (in `ICommitteeRegistry`)
   - **Signature**: `function setWhitelister(address _newWhitelister) external`
   - **Description**: Sets the whitelister address (owner only).
   - **Impact**: Configure who can call whitelist/unwhitelist.

7. **`getNextPegoutSlotLocation`**, **`hasPegoutInProcess`** (in `IStreamManager`)
   - **Signatures**: `function getNextPegoutSlotLocation(uint64 _streamId) external view returns (SlotLocation memory)`; `function hasPegoutInProcess(uint64 _streamId) external view returns (bool)`
   - **Description**: Get the next slot that would be used for pegout, and whether a pegout is already in progress for the stream.
   - **Impact**: Replace use of `pegoutPacketPointer` / `pegoutSlotPointer` with these APIs.

8. **`getEnablerScriptPubKey`** (in `IStreamManager`)
   - **Signature**: `function getEnablerScriptPubKey(uint64 _streamId, uint64 _packetNumber) external view returns (bytes memory)`
   - **Description**: Returns the enabler script public key for a packet (enabler script is stored at packet level).
   - **Impact**: Use when building accept-pegin or validating enabler output; pass to `validateRequestPeginEnablerOutput` as expected script.

9. **`setTimelockSettings`** (in `IStreamManager`)
   - **Signature**: `function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings) external`
   - **Description**: Sets timelock settings for a stream (owner only).
   - **Impact**: Configure timelock per stream after init if needed.

10. **`isMember`** (in `IMemberRegistry`)
    - **Signature**: `function isMember(address _address) external view returns (bool)`
    - **Description**: Returns whether an address has ever been a member.
    - **Impact**: Use for membership checks.

11. **`bridge`**, **`getBestBlockHash`**, **`verifyTxConfirmations`**, **`getTxBlockNumberAndVerifyConfirmations`** (in `IRbtcBridge`)
    - **Description**: RbtcBridge now exposes bridge getter, Bitcoin best block hash, and SPV verification helpers. ProofValidator logic moved into RbtcBridge.
    - **Impact**: Call these for bridge interaction and proof verification.

12. **IPauseManager setters** (in `IPauseManager`): **`setCommitteeRegistry`**, **`setPeginManager`**, **`setPegoutManager`**, **`setChallengeManager`**, **`setMemberRegistry`**, **`setRbtcBridge`**
    - **Description**: Configure pausable contract addresses after deployment (no `initialize`). Each setter is owner-only; address can only be set once (reverts with `AlreadySet` if already non-zero).
    - **Impact**: Deployment must use these setters instead of a single initialize to wire PauseManager/AccessManager.

### Struct and Storage Layout Changes (v0.4.0-alpha)

1. **`Slot`** (in `IStreamManager`)
   - **Removed**: `enablerScriptPubKey` (bytes). Enabler script is now stored at packet level.
2. **`Packet`** (in `IStreamManager`)
   - **Added**: `enablerScriptPubKey` (bytes), `finishedSlots` (uint64).
3. **`Stream`** (in `IStreamManager`)
   - **Removed**: `pegoutPacketPointer`, `pegoutSlotPointer`. Peg-out slot selection uses new APIs (`getNextPegoutSlotLocation`, `hasPegoutInProcess`, `lockSlot`).
4. **`PegoutTempInfo`** (in `IPegoutManager`)
   - **Added**: `operatorTakePubKey` (bytes32) after `takeOperatorAddress`.

### Events - Changed (v0.4.0-alpha)

1. **`PegoutRequested`** (in `IPegoutManager`)
   - **Old**: Last parameter `bytes32 pegoutId` present.
   - **New**: `pegoutId` parameter removed.
2. **`AdvanceFundsRegistered`** (in `IPegoutManager`)
   - **New**: Added final parameter `bytes32 operatorTakePubKey`.
3. **`ReimbursementKickoffRegistered`** (in `IPegoutManager`)
   - **Old**: `(bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo)`.
   - **New**: Added `bytes32 indexed pegoutId` and `bytes32 operatorTakePubKey`; parameter order and indexing changed.
4. **`OperatorTakeTriggered`** (in `IPegoutManager`)
   - **Change**: First parameter `pegoutTxid` is now `indexed`.

### Events - Removed (v0.4.0-alpha)

1. **`PeginManagerUpdated`** (in `IBitcoinManager`).
2. **`StreamManagerUpdated`**, **`PeginManagerUpdated`**, **`PegoutManagerUpdated`** (in `ICommitteeRegistry`).
3. **`MemberRegistryUpdated`** (in `ICommitteeRegistry`).
4. **`CommitteeRegistryUpdated`** (in `IMemberRegistry`).
5. **`PacketClosed`** (in `IPegoutManager`) – Emitted now by `IStreamManager` (see Events - New).
6. **`CommitteeRegistryUpdated`** (in `IStreamManager`).

### Events - New (v0.4.0-alpha)

1. **`WhitelisterUpdated`**, **`AddressWhitelisted`**, **`AddressUnwhitelisted`** (in `ICommitteeRegistry`).
2. **`PacketClosed`** (in `IStreamManager`) – Emitted when a packet is fully completed or closed.
3. **`PauserUpdated`** (in `IPausable`).
4. **`BaseEventSet`** (in `IRbtcBridge`).

### Errors - Changed (v0.4.0-alpha)

1. **`ReimbursementKickoffTxidNotMatch`** (in `IPegoutManager`)
   - **Old**: `error ReimbursementKickoffTxidNotMatch(bytes32 expected, bytes32 actual)`
   - **New**: `error ReimbursementKickoffTxidNotMatch(bytes32 actual, bytes32 expected)` (parameter order swapped).
2. **`OperatorTakeTxidNotMatch`** (in `IPegoutManager`)
   - **Old**: `error OperatorTakeTxidNotMatch(bytes32 expected, bytes32 actual)`
   - **New**: `error OperatorTakeTxidNotMatch(bytes32 actual, bytes32 expected)` (parameter order swapped).
3. **`CommitteeRegistryAddressZero` → `InvalidZeroAddress`** (in `ISignatureManager`).
4. **`ZeroAddress` → `InvalidZeroAddress`** (in `IPauseManager`).
5. **`StreamAlreadyInitialized`** (in `IStreamManager`)
   - **Old**: `error StreamAlreadyInitialized(uint256 streamId)`
   - **New**: `error StreamsAlreadyInitialized()` (no parameters).
6. **`InvalidStreamSettingsLength`** (in `IStreamManager`)
   - **Old**: `error InvalidStreamSettingsLength(uint256 streamSettingsLength)`
   - **New**: `error InvalidStreamSettingsLength(uint256 actualLength, uint256 expectedLength)` (two parameters).

### Errors - Removed (v0.4.0-alpha)

1. **`UnauthorizedAccount`**, **`InvalidZeroAddress`** (in `IBitcoinManager`).
2. **`InvalidZeroAddress`**, **`MemberRegistryAddressZero`** (in `ICommitteeRegistry`).
3. **`InvalidZeroAddress`** (in `IMemberRegistry`).
4. **`NoPacketAvailable`** (in `IStreamManager`).
5. **`InvalidAcceptPeginTxid`** (in `IStreamManager`).
6. **`BridgeAddressZero`**, **`PeginManagerAddressZero`**, **`PegoutManagerAddressZero`** (in `IRbtcBridge`).

### Errors - New (v0.4.0-alpha)

1. **IChallengeManager**: `ReimbursementKickoffTxidNotMatch`, `ChallengeTxidNotMatch`, `InvalidChallengeInputCount`, `InvalidRevealedInputCount`.
2. **ICommitteeRegistry**: `NonWhitelistedAddress`, `UnauthorizedWhitelister`, `InvalidMaxMembers`.
3. **IPauseManager**: `InvalidZeroAddress`, `AlreadySet`.
4. **IPausable**: `InvalidZeroAddress`, `UnauthorizedPauser`.
5. **IPegoutManager**: `InputRevealedTxidNotMatch`, `OperatorWonTxidNotMatch`, `InvalidKickoffInputCount`, `InvalidSlotId`.
6. **IRbtcBridge**: `BridgeBtcInexistantBlockHash`, `BridgeBtcBlockNotInBestChain`, `BridgeBtcInconsistentBlock`, `BridgeBtcBlockTooOld`, `BridgeBtcTxInvalidMerkleBranch`, `NotEnoughConfirmations`, `BaseEventAlreadySet`, `BaseEventTooLong`, `BaseEventEmpty`.

### New Contracts and Interfaces (v0.4.0-alpha)

1. **ChallengeManager** / **IChallengeManager** – New contract and interface for challenge and input-reveal registration (see Contract Restructuring above).
2. **AccessManager** / **IAccessManager** – New contract and interface replacing AccessControl; inherits from PauseManager and centralizes permission checks.
3. **IPegBase** – New base interface for peg-related contracts (PeginManager, PegoutManager, ChallengeManager); includes `StreamManagerUpdated` event and errors `PeginNotRequested`, `InvalidPegStatus`.

### Removed Contracts and Interfaces (v0.4.0-alpha)

1. **AccessControl** / **IAccessControl** – Replaced by `AccessManager` / `IAccessManager`.
2. **ProofValidator** – Logic moved into `RbtcBridge`; standalone contract and tests removed.

## [v0.3.0-alpha]

### Public Functions - Changed Names or Parameters (v0.3.0-alpha)

1. **`addOperatorTakeTxid` → `addOperatorTakeTxids`** (in `ISignatureManager`)
   - **Old signature**: `function addOperatorTakeTxid(bytes32 _acceptPeginTxid, bytes32 _takeTxid) external`
   - **New signature**: `function addOperatorTakeTxids(bytes32 _acceptPeginTxid, bytes32 _takeTxid, bytes32 _wonTxid) external`
   - **Changes**:
     - Function name changed (singular to plural)
     - Added required parameter `_wonTxid` (bytes32) for the OperatorWon transaction id
     - **Impact**: All callers must update to use the new function name and provide the `_wonTxid` parameter

2. **`getOperatorTakeData` return type changed** (in `ISignatureManager`)
   - **Old signature**: `function getOperatorTakeData(bytes32 _acceptPeginTxid) external view returns (OperatorTakeData[] memory)`
   - **Old struct**: `struct OperatorTakeData { bytes32 txid; address memberAddress; }`
   - **New struct**: `struct OperatorTakeData { bytes32 takeTxid; bytes32 wonTxid; address memberAddress; }`
   - **Changes**:
     - The `OperatorTakeData` struct now includes both `takeTxid` and `wonTxid` fields instead of a single `txid` field
     - **Impact**: Callers expecting the old struct format need to be updated to handle both transaction IDs

3. **`StreamManager.initialize` parameters changed** (in `IStreamManager`)
   - **Old signature**: `function initialize(address _initialOwner, address _peginManager, address _pegoutManager, ICommitteeRegistry _committeeRegistry, uint64[] memory _denominations, StreamManagerSettings memory _settings)`
   - **New signature**: `function initialize(address _initialOwner, address _peginManager, address _pegoutManager, ICommitteeRegistry _committeeRegistry, StreamManagerSettings memory _settings, StreamSettings[] memory _streamSettings)`
   - **Changes**:
     - Replaced `uint64[] memory _denominations` parameter with `StreamSettings[] memory _streamSettings`
     - `StreamSettings` includes denomination, peginConfirmations, pegoutConfirmations, and timelockSettings
     - **Impact**: All deployment scripts and initialization code must be updated to use the new `StreamSettings[]` format

4. **`RequestPeginTempInfo` struct fields added** (in `IPeginManager`)
   - **Old struct**:

     ```solidity
     struct RequestPeginTempInfo {
         address rskDestinationAddress;
         bytes32 btcReimbursementPubKey;
         bytes32 acceptPeginSignatureHash;
     }
     ```

   - **New struct**:

     ```solidity
     struct RequestPeginTempInfo {
         address rskDestinationAddress;
         bytes32 btcReimbursementPubKey;
         bytes32 acceptPeginSignatureHash;
         int256 btcBlockNumber;
         bytes32 userReimbursementTxid;
         bytes32 rejectPeginTxid;
     }
     ```

   - **Changes**:
     - Added `btcBlockNumber` field
     - Added `userReimbursementTxid` field
     - Added `rejectPeginTxid` field
     - **Impact**: Code accessing this struct needs to handle the new fields

### Bitcoin Transaction Structure Changes (v0.3.0-alpha)

1. **`requestPegin` Bitcoin transaction structure changed**
   - **Old structure**: Had 2 outputs (P2TR taptree output and OP_RETURN metadata output)
   - **New structure**: Now has 3 outputs - added an enabler output (output index 2) containing dispute keys
   - **Changes**:
     - Added enabler output at index 2 with amount `ENABLER_AMOUNT` (540 satoshis)
     - Enabler output contains a Taproot script with committee dispute keys in the merkle tree
     - The enabler output is validated via `validateRequestPeginEnablerOutput` function
   - **Impact**:
     - SPV proofs submitted to `requestPegin` must now include the enabler output
     - Bitcoin transactions created for request pegin must include this third output
     - Validation will fail if the enabler output is missing, has incorrect amount, or incorrect scriptPubKey

2. **`acceptPegin` Bitcoin transaction structure changed**
   - **Old structure**: Had 1 input (consuming request pegin taptree UTXO) and 2 outputs (P2TR taptree output and speed-up output)
   - **New structure**: Now has 2 inputs and 3 outputs
   - **Changes**:
     - Added enabler input at index 1 that consumes the request pegin enabler UTXO (output index 2 from request pegin)
     - Added enabler output at index 1 with amount `ENABLER_AMOUNT` (540 satoshis) containing operator dispute keys only
     - The main taptree output amount is reduced by `ENABLER_AMOUNT` to account for the enabler output
     - Both inputs (taptree and enabler) must be included in the signature hash calculation
   - **Impact**:
     - SPV proofs submitted to `acceptPegin` must now include both inputs (taptree and enabler)
     - SPV proofs must include the enabler output in the transaction outputs
     - Bitcoin transactions created for accept pegin must consume both UTXOs from request pegin
     - Validation will fail if the enabler input/output is missing or incorrect
     - The `getAcceptPeginSignatureHash` function now requires `PrevoutData[]` array with both prevouts (taptree + enabler)

### Public Functions - New (v0.3.0-alpha)

1. **`registerAdvanceFunds`** (in `IPegoutManager`)
   - **Signature**: `function registerAdvanceFunds(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _advanceFunds) external`
   - **Description**: Registers the advance funds transaction submitted by the operator
   - **Note**: Must be called before `registerOperatorTake` when an operator is selected

2. **`registerReimbursementKickoff`** (in `IPegoutManager`)
   - **Signature**: `function registerReimbursementKickoff(bytes32 acceptPeginTxid, BtcTxSPVProof calldata _kickoffSPV) external`
   - **Description**: Registers the reimbursement kickoff transaction submitted by the operator
   - **Note**: Must be called after `registerAdvanceFunds` and before `registerOperatorTake`

3. **`userReimbursement`** (in `IPeginManager`)
   - **Signature**: `function userReimbursement(BtcTxSPVProof calldata _userReimbursementTxSPVProof, uint32 _reimbursementPeginVin) external`
   - **Description**: Registers a user reimbursement transaction from Bitcoin
   - **Note**: Sets slot state to BLOCKED

4. **`rejectPegin`** (in `IPeginManager`)
   - **Signature**: `function rejectPegin(BtcTxSPVProof memory _rejectPeginTxSPVProof) external`
   - **Description**: Registers a reject peg-in transaction from Bitcoin
   - **Note**: Sets slot state to BLOCKED

5. **`setTimelockSettings`** (in `IStreamManager`)
   - **Signature**: `function setTimelockSettings(uint64 _streamId, TimelockSettings memory _timelockSettings) external`
   - **Description**: Sets the timelock settings for a stream
   - **Access**: Only callable by the owner

### Enums - Changed (v0.3.0-alpha)

1. **`PegStatus` enum values added** (in `IPegCommonTypes`)
   - **Old enum values**: `NOT_REGISTERED`, `REGISTERED`, `ACCEPTED`, `USER_TAKE`, `OPERATOR_TAKE`, `OPERATOR_WON`, `COMPLETED`, `LENGTH`
   - **New enum values**: Added `OP_SELECTED`, `ADVANCED`, `KICKOFF`, `CHALLENGE`, `REVEALED`, `BLOCKED`
   - **Changes**:
     - `OP_SELECTED`: Operator has been selected for advancing the slot
     - `ADVANCED`: Slot is being advanced by an operator to the user
     - `KICKOFF`: Operator has presented reimbursement kickoff proof for the slot
     - `CHALLENGE`: Slot is under challenge after kickoff presentation
     - `REVEALED`: Operator slot id secret has been revealed to initiate a challenge
     - `BLOCKED`: Pegin is blocked due to timeout or refund proof
   - **Impact**: Code checking or handling `PegStatus` values needs to account for the new states

### Workflow Changes (v0.3.0-alpha)

1. **`registerOperatorTake` workflow changed** (in `IPegoutManager`)
   - **Old workflow**: Could call `registerOperatorTake` directly when peg status was `OPERATOR_TAKE`
   - **New workflow**: Before calling `registerOperatorTake`, must first call:
     1. `registerAdvanceFunds` (sets status to `ADVANCED`)
     2. `registerReimbursementKickoff` (sets status to `KICKOFF`)
   - **Impact**: All integrations using operator take functionality must update their workflow

2. **Pegin rejection and user reimbursement workflow added** (in `IPeginManager`)
   - **New capability**: After `requestPegin` and before `acceptPegin`, the following actions are now possible:
     - **Reject pegin**: Committee can call `rejectPegin` to register a reject peg-in transaction, which sets the slot status to `BLOCKED`
     - **User reimbursement**: User can call `userReimbursement` to register a user reimbursement transaction, which also sets the slot status to `BLOCKED`
   - **Impact**: Integrations must handle the new `BLOCKED` status and account for these new workflow paths that can occur between request and accept pegin phases

### Events - New (v0.3.0-alpha)

1. **`AdvanceFundsRegistered`** (in `IPegoutManager`)
   - **Signature**: `event AdvanceFundsRegistered(bytes32 indexed blockHash, bytes32 indexed txid, bytes32 indexed acceptPeginTxid, bytes32 pegoutId, uint128 committeeId, StreamPosition streamInfo)`
   - **Description**: Emitted when advance funds are successfully registered
   - **Emitted by**: `registerAdvanceFunds` function

2. **`ReimbursementKickoffRegistered`** (in `IPegoutManager`)
   - **Signature**: `event ReimbursementKickoffRegistered(bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo)`
   - **Description**: Emitted when the reimbursement kickoff transaction is successfully registered
   - **Emitted by**: `registerReimbursementKickoff` function

3. **`UserReimbursementRegistered`** (in `IPeginManager`)
   - **Signature**: `event UserReimbursementRegistered(bytes32 indexed userReimbursementTxid, bytes32 indexed requestPeginTxid, StreamPosition streamInfo)`
   - **Description**: Emitted when a user reimbursement is successfully registered
   - **Emitted by**: `userReimbursement` function

4. **`RejectPeginRegistered`** (in `IPeginManager`)
   - **Signature**: `event RejectPeginRegistered(bytes32 indexed rejectPeginTxid, bytes32 indexed requestPeginTxid, StreamPosition streamInfo)`
   - **Description**: Emitted when a reject peg-in is successfully registered
   - **Emitted by**: `rejectPegin` function

5. **`TimelockSettingsUpdated`** (in `IStreamManager`)
   - **Signature**: `event TimelockSettingsUpdated(uint64 _streamId, TimelockSettings _timelockSettings)`
   - **Description**: Emitted when the timelock settings are updated for a stream
   - **Emitted by**: `setTimelockSettings` function

### Events - Changed (v0.3.0-alpha)

1. **`OperatorTakeTxidAdded` → `OperatorTakeTxidsAdded`** (in `ISignatureManager`)
   - **Old signature**: `event OperatorTakeTxidAdded(bytes32 acceptPeginTxid, address memberAddress, bytes32 hash)`
   - **New signature**: `event OperatorTakeTxidsAdded(bytes32 acceptPeginTxid, address memberAddress, bytes32 takeTxid, bytes32 wonTxid)`
   - **Changes**:
     - Event name changed (singular to plural)
     - Parameter `hash` replaced with two parameters: `takeTxid` and `wonTxid`
     - Now includes both OperatorTake and OperatorWon transaction IDs
   - **Impact**: Event listeners filtering or parsing this event need to update to handle the new event name and parameters

### Errors - New (v0.3.0-alpha)

1. **`InvalidUserReimbursementTx`** (in `IPeginManager`)
   - **Signature**: `error InvalidUserReimbursementTx(bytes32 userReimbursementTxid)`
   - **Description**: Thrown when the user reimbursement transaction id is the same as the accept peg-in txid

2. **`InvalidRejectPeginTxid`** (in `IPeginManager`)
   - **Signature**: `error InvalidRejectPeginTxid(bytes32 rejectPeginTxid)`
   - **Description**: Thrown when the reject peg-in transaction id is the same as the accept peg-in txid

3. **`UserReimbursementBeforeTimelock`** (in `IPeginManager`)
   - **Signature**: `error UserReimbursementBeforeTimelock(int256 blocksElapsedSinceRequestPegin, uint256 timelockBlocks)`
   - **Description**: Thrown when the user reimbursement transaction is mined before the timelock period

4. **`ReimbursementKickoffBeforeAdvanceFunds`** (in `IPegoutManager`)
   - **Signature**: `error ReimbursementKickoffBeforeAdvanceFunds(int256 advanceFundsBlockNumber, int256 reimbursementKickoffBlockNumber)`
   - **Description**: Thrown when the reimbursement kickoff transaction is mined before the advance funds transaction

5. **`ReimbursementKickoffTxidNotMatch`** (in `IPegoutManager`)
   - **Signature**: `error ReimbursementKickoffTxidNotMatch(bytes32 expected, bytes32 actual)`
   - **Description**: Thrown when the reimbursement kickoff txid does not match the expected value

### Scripts - Changed (v0.3.0-alpha)

1. **`shell/script/operator-take/add-operator-take-txid.sh`** - Updated to use `addOperatorTakeTxids` and deposit `operatorWonTxid`
2. **`script/operator-take/add-every-operator-take-txid.sh`** - Updated to use `addOperatorTakeTxids` and deposit `operatorWonTxid`

### Scripts - Removed (v0.3.0-alpha)

1. **`shell/script/operator-take/add-every-operator-take-tx-hash.sh`** - Unused script removed

## [v0.2.2-alpha]

### Public Functions - Changed Names or Parameters (v0.2.2-alpha)

1. **`getOperatorTakeAddress` → `getOperatorDisputeData`** (in `ICommitteeRegistry`)
   - **Old signature**: `function getOperatorTakeAddress(uint128 committeeId, SignatureData[] calldata signatureData) external returns (address operatorAddress, bytes32 takePubKey)`
   - **New signature**: `function getOperatorDisputeData(uint128 committeeId, SignatureData[] calldata signatureData) external returns (address operatorAddress, bytes32 disputePubKey)`
   - **Changes**:
     - Function name changed
     - Return value renamed from `takePubKey` to `disputePubKey`
     - **Impact**: All callers must update to use the new function name and handle the renamed return value

2. **`getMemberComPubKey` return type changed** (in `IMemberRegistry`)
   - **Old signature**: `function getMemberComPubKey(address _address) external view returns (RSAPublicKey memory)`
   - **New signature**: `function getMemberComPubKey(address _address) external view returns (bytes32)`
   - **Changes**:
     - Now returns the communication key hash (`bytes32`) instead of the full `RSAPublicKey` struct
     - **Impact**: Callers expecting the full RSA public key struct need to be updated

3. **`removeCandidatesAndUpdateBalance` → `stakePreStakedCandidatesBalance`** (in `IMemberRegistry`)
   - **Old signature**: `function removeCandidatesAndUpdateBalance(...)`
   - **New signature**: `function stakePreStakedCandidatesBalance(CommitteeMember[] memory _members, StreamDenomination _denomination, uint64 _packetNumber) external`
   - **Changes**:
     - Function name changed
     - **Impact**: All callers must update to use the new function name

4. **`requestPegin` parameter renamed** (in `IPeginManager`)
   - **Old signature**: `function requestPegin(BtcTxSPVProof calldata _peginRequestTxSPVProof) external`
   - **New signature**: `function requestPegin(BtcTxSPVProof calldata _requestPeginTxSPVProof) external`
   - **Changes**:
     - Parameter name changed from `_peginRequestTxSPVProof` to `_requestPeginTxSPVProof`
     - **Impact**: Event listeners and documentation should use the new parameter name

### Public Functions - New (v0.2.2-alpha)

1. **`reAddCommitteeMembers`** (in `IMemberRegistry`)
   - **Signature**: `function reAddCommitteeMembers(Committee memory _discardedCommittee) external`
   - **Description**: Re-adds members from a discarded committee

2. **`setBridge`** (in `IMemberRegistry`)
   - **Signature**: `function setBridge(IBridge _bridge) external`
   - **Description**: Sets the bridge contract address

3. **`getPacketSlotsLength`** (in `IStreamManager`)
   - **Signature**: `function getPacketSlotsLength(uint64 _streamId, uint64 _packetNumber) external view returns (uint64)`
   - **Description**: Gets the number of slots in a packet

### Events - New (v0.2.2-alpha)

1. **`BridgeUpdated`** (in `IMemberRegistry`)
   - **Signature**: `event BridgeUpdated(address indexed newBridge)`
   - **Description**: Emitted when the bridge address is updated

### Errors - Changed (v0.2.2-alpha)

1. **`InvalidZeroEDCSAPublicKey` → `InvalidEDCSAPublicKey`** (in `IMemberRegistry`)
   - **Old signature**: `error InvalidZeroEDCSAPublicKey(PublicKeyType keyType, bytes32 publicKeyX, bytes32 publicKeyY)`
   - **New signature**: `error InvalidEDCSAPublicKey(PublicKeyType keyType, bytes32 publicKeyX, bytes32 publicKeyY)`
   - **Changes**: Error name changed (removed "Zero" from name)
   - **Impact**: Error handling code needs to update error name

2. **`InvalidZeroRSAPublicKey` → `InvalidZeroRSAPublicKeyHash`** (in `IMemberRegistry`)
   - **Old signature**: `error InvalidZeroRSAPublicKey(PublicKeyType keyType)`
   - **New signature**: `error InvalidZeroRSAPublicKeyHash(PublicKeyType keyType)`
   - **Changes**: Error renamed to reflect that it validates RSA key hash, not the full key
   - **Impact**: Error handling code needs to update error name

### Errors - New (v0.2.2-alpha)

1. **`BridgeExceededLockingCap`** (in `IPeginManager`)
   - **Signature**: `error BridgeExceededLockingCap(uint256 value, uint256 lockingCap)`
   - **Description**: Thrown when the input amount exceeds the locking cap of the pow-peg bridge

## [v0.2.1-alpha]

### Contract Restructuring (v0.2.1-alpha)

- **PegManager contract split**: The `PegManager` contract has been split into two separate contracts:
  - `PeginManager`: Handles all peg-in operations (Bitcoin to Rootstock)
  - `PegoutManager`: Handles all peg-out operations (Rootstock to Bitcoin)
  - **Impact**: All integrations using `PegManager` must be updated to use the appropriate new contract

### Public Functions - Changed Names or Parameters (v0.2.1-alpha)

1. **`getTemporaryPeginAddress` → `getRequestPeginData`** (in `PeginManager`)
   - **Old signature**: `function getTemporaryPeginAddress(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey) external returns (string memory temporaryPeginAddress)`
   - **New signature**: `function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey) external view returns (string memory temporaryPeginAddress, uint64 packetNumber, bytes32[] memory memberDisputeKeys, uint64 availableSlots)`
   - **Changes**:
     - Function name changed
     - Now returns additional values: `packetNumber`, `memberDisputeKeys`, and `availableSlots`
     - Changed from `external` to `external view`

2. **`getStreamPosition` → `getStreamPositionByRequestPegin`** (in `PeginManager`)
   - **Old signature**: `function getStreamPosition(bytes32 btcTxid) external view returns (StreamPosition memory)`
   - **New signature**: `function getStreamPositionByRequestPegin(bytes32 requestPeginTxid) external view returns (StreamPosition memory)`
   - **Changes**:
     - Function name changed
     - **IMPORTANT**: Parameter semantics changed - old function accepted `acceptPeginTxid`, new function accepts `requestPeginTxid` (the request peg-in transaction ID, not the accept peg-in transaction ID)
     - Moved from `PegManager` to `PeginManager`
   - **Note**: To get stream position by `acceptPeginTxid`, use `StreamManager.getStreamPosition(bytes32 _acceptPeginTxid)` directly

### Public Functions - Removed (v0.2.1-alpha)

1. **`setStreamManager`** - Removed from `PegManager`
   - **Old signature**: `function setStreamManager(IStreamManager _streamManager) external`
   - **Impact**: Stream manager must be set during initialization or via upgrade

2. **`setSignatureManager`** - Removed from `PegManager`
   - **Old signature**: `function setSignatureManager(ISignatureManager _signatureManager) external`
   - **Impact**: Signature manager must be set during initialization or via upgrade

3. **`setMemberRegistry`** - Removed from `PegManager`
   - **Old signature**: `function setMemberRegistry(IMemberRegistry _memberRegistry) external`
   - **Impact**: Member registry is now accessed through `CommitteeRegistry`

### Public Functions - New (v0.2.1-alpha)

1. **`RbtcBridge.mintRbtc`** - New function
   - **Signature**: `function mintRbtc(address payable _to, uint256 _amount) external`
   - **Description**: Mints RBTC from the PowPeg bridge and sends it to the specified address
   - **Access**: Only callable by `peginManager`

2. **`RbtcBridge.burnRbtc`** - New function
   - **Signature**: `function burnRbtc() external payable`
   - **Description**: Burns RBTC back to the PowPeg bridge
   - **Access**: Only callable by `pegoutManager`

3. **`RbtcBridge.getUnionBridgeLockingCap`** - New function
   - **Signature**: `function getUnionBridgeLockingCap() external view returns (uint256)`
   - **Description**: Gets the locking cap of the Union Bridge for RBTC minting operations

4. **`PeginManager.getRequestPeginData`** - New function (replaces `getTemporaryPeginAddress`)
   - **Signature**: `function getRequestPeginData(address _rootstockDepositAddress, uint64 _value, bytes32 _btcReimbursementPubKey) external view returns (string memory temporaryPeginAddress, uint64 packetNumber, bytes32[] memory memberDisputeKeys, uint64 availableSlots)`
   - **Description**: Generates request peg-in data including temporary Bitcoin address and member dispute keys

5. **`PeginManager.getStreamPositionByRequestPegin`** - New function (replaces `getStreamPosition`)
   - **Signature**: `function getStreamPositionByRequestPegin(bytes32 requestPeginTxid) external view returns (StreamPosition memory)`
   - **Description**: Retrieves the stream position information for a given request peg-in transaction id

### Events - Changed (v0.2.1-alpha)

1. **`PeginAccepted`** event parameter name changed
   - **Old**: `peginRequestTxid` (3rd indexed parameter)
   - **New**: `requestPeginTxid` (3rd indexed parameter)
   - **Impact**: Event listeners filtering by this parameter need to update

2. **`PegoutRegistered`** event structure changed
   - **Old signature**: `event PegoutRegistered(bytes32 indexed blockHash, bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, uint64 streamId, uint64 packetNumber, uint64 slotId)`
   - **New signature**: `event PegoutRegistered(bytes32 indexed blockHash, bytes32 indexed txid, bytes32 indexed acceptPeginTxid, uint128 committeeId, StreamPosition streamInfo)`
   - **Changes**:
     - Replaced individual `streamId`, `packetNumber`, `slotId` parameters with `StreamPosition streamInfo` struct
     - **Impact**: Event listeners parsing this event need to update to extract values from the struct

### Events - Removed (v0.2.1-alpha)

1. **`StreamManagerUpdated`** - Removed
   - **Old signature**: `event StreamManagerUpdated(IStreamManager _streamManager)`
   - **Impact**: No longer emitted since `setStreamManager` function was removed

2. **`SignatureManagerUpdated`** - Removed
   - **Old signature**: `event SignatureManagerUpdated(ISignatureManager _signatureManager)`
   - **Impact**: No longer emitted since `setSignatureManager` function was removed

### Events - New (v0.2.1-alpha)

1. **`RbtcBridge.RbtcMinted`** - New event
   - **Signature**: `event RbtcMinted(address indexed to, uint256 amount)`
   - **Description**: Emitted when RBTC is minted and sent to a user

2. **`RbtcBridge.RbtcBurned`** - New event
   - **Signature**: `event RbtcBurned(uint256 amount)`
   - **Description**: Emitted when RBTC is burned back to the PowPeg bridge

### Errors - Changed (v0.2.1-alpha)

1. **`BridgeExceededLockingCap`** - Moved to `IPeginManager`
   - **Old location**: `IPegManager`
   - **New location**: `IPeginManager`
   - **Signature unchanged**: `error BridgeExceededLockingCap(uint256 value, uint256 lockingCap)`
   - **Impact**: Error handling code needs to import from the new interface

### Errors - Removed (v0.2.1-alpha)

1. **`SignatureManagerAddressZero`** - Removed
   - **Old signature**: `error SignatureManagerAddressZero()`
   - **Impact**: No longer used since `setSignatureManager` was removed

2. **`StreamManagerAddressZero`** - Removed
   - **Old signature**: `error StreamManagerAddressZero()`
   - **Impact**: No longer used since `setStreamManager` was removed

3. **`MemberRegistryAddressZero`** - Removed
   - **Old signature**: `error MemberRegistryAddressZero()`
   - **Impact**: No longer used since `setMemberRegistry` was removed

### Errors - New (v0.2.1-alpha)

1. **`RbtcBridge.UnauthorizedCaller`** - New error
   - **Signature**: `error UnauthorizedCaller(address caller)`
   - **Description**: Thrown when an unauthorized address attempts to call a restricted function

2. **`RbtcBridge.FailedToSendRBTC`** - New error
   - **Signature**: `error FailedToSendRBTC(address to, uint256 amount)`
   - **Description**: Thrown when RBTC transfer to recipient fails

3. **`RbtcBridge.BridgeUnauthorizedCaller`** - New error
   - **Signature**: `error BridgeUnauthorizedCaller()`
   - **Description**: Thrown when the PowPeg bridge rejects the request due to unauthorized caller

4. **`RbtcBridge.BridgeExceededLockingCap`** - New error
   - **Signature**: `error BridgeExceededLockingCap(uint256 amount)`
   - **Description**: Thrown when the requested amount exceeds the PowPeg bridge locking cap

5. **`RbtcBridge.BridgeTransfersDisabled`** - New error
   - **Signature**: `error BridgeTransfersDisabled()`
   - **Description**: Thrown when RBTC transfers are currently disabled in the PowPeg bridge

6. **`RbtcBridge.BridgeReleaseInvalidValue`** - New error
   - **Signature**: `error BridgeReleaseInvalidValue(uint256 amount)`
   - **Description**: Thrown when the burn amount exceeds the previously minted amount

7. **`RbtcBridge.BridgeBtcUnknownError`** - New error
   - **Signature**: `error BridgeBtcUnknownError(int256 errorCode)`
   - **Description**: Thrown when the PowPeg bridge returns an unknown error code

8. **`RbtcBridge.BridgeAddressZero`** - New error
   - **Signature**: `error BridgeAddressZero()`
   - **Description**: Thrown when the bridge address is set to zero during initialization

9. **`RbtcBridge.PeginManagerAddressZero`** - New error
   - **Signature**: `error PeginManagerAddressZero()`
   - **Description**: Thrown when the peginManager address is set to zero during initialization

10. **`RbtcBridge.PegoutManagerAddressZero`** - New error
    - **Signature**: `error PegoutManagerAddressZero()`
    - **Description**: Thrown when the pegoutManager address is set to zero during initialization

11. **`IPeginManager.BridgeExceededLockingCap`** - New error (moved from IPegManager)
    - **Signature**: `error BridgeExceededLockingCap(uint256 value, uint256 lockingCap)`
    - **Description**: Thrown when the input amount exceeds the locking cap of the pow-peg bridge

### Added

- **New Contracts**:
  - `RbtcBridge`: Intermediary contract that acts as the single authorized address for RBTC minting/burning with the RSK PowPeg Bridge
  - `PauseManager`: Contract for managing pause functionality across the system
  - `Musig2`: Contract for MuSig2 signature aggregation
  - `PegManagerBase`: Base contract containing shared functionality for `PeginManager` and `PegoutManager`

- **New Interfaces**:
  - `IRbtcBridge`: Interface for the RbtcBridge contract
  - `IPeginManager`: Interface for peg-in operations
  - `IPegoutManager`: Interface for peg-out operations
  - `IPegManagerBase`: Base interface for peg managers
  - `IPegCommonTypes`: Common types shared between peg managers
  - `IPausable`: Interface for pausable contracts
  - `IPauseManager`: Interface for pause management
  - `IMusig2`: Interface for MuSig2 operations

### Changed

- **Architecture**: Split `PegManager` into `PeginManager` and `PegoutManager` for better separation of concerns
- **RBTC Minting/Burning**: Now handled through the `RbtcBridge` contract to comply with RSKIP-502 requirements
- **Initialization**: `PeginManager` and `PegoutManager` now require `IRbtcBridge` parameter during initialization

### Migration Guide

1. **Update contract references**: Replace all `PegManager` references with either `PeginManager` or `PegoutManager` depending on the operation
2. **Update function calls**:
   - Replace `getTemporaryPeginAddress` with `getRequestPeginData` and handle additional return values
   - Replace `getStreamPosition` with `getStreamPositionByRequestPegin`
3. **Update event listeners**:
   - Update `PeginAccepted` listeners to use `requestPeginTxid` instead of `peginRequestTxid`
   - Update `PegoutRegistered` listeners to extract values from `StreamPosition` struct
4. **Deploy RbtcBridge**: Deploy and configure the new `RbtcBridge` contract before deploying `PeginManager` and `PegoutManager`
5. **Update error handling**: Import `BridgeExceededLockingCap` from `IPeginManager` instead of `IPegManager`
