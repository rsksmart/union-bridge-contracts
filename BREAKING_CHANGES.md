# Breaking Changes

## [Unreleased]

### Changed

- `SignatureManager.addOperatorTakeTxid` renamed to `addOperatorTakeTxids`.
- `SignatureManager.getOperatorTakeTxids` now receive `operatorWonTxid` too.
- `shell/script/operator-take/add-operator-take-txid.sh` and `script/operator-take/add-every-operator-take-txid.sh` to use `addOperatorTakeTxids` and deposit `operatorWonTxid`.


### Removed

- `shell/script/operator-take/add-every-operator-take-tx-hash.sh` unused script.


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
