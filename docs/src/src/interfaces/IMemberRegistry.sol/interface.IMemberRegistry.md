# IMemberRegistry
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IMemberRegistry.sol)

Interface for managing committee member registration, applications, and balance tracking

*Handles member lifecycle operations including registration, candidacy, and balance management*


## Functions
### applyToStream

Internal function to handle member application to stream

*Called by CommitteeRegistry to handle member registration and candidacy*


```solidity
function applyToStream(
    address _memberAddress,
    StreamDenomination _stream,
    Role _role,
    MemberRegistrationKeys calldata _publicKeys,
    UTXO calldata _fundingUTXO
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The address of the member applying|
|`_stream`|`StreamDenomination`|The stream denomination to apply for|
|`_role`|`Role`|The role requested in the committee|
|`_publicKeys`|`MemberRegistrationKeys`|Member registration public keys|
|`_fundingUTXO`|`UTXO`|The Bitcoin UTXO that will be used for the member funding|


### unsubscribeFromStream

Internal function to handle member unsubscription from stream

*Called by CommitteeRegistry after pending committee checks*

*Only callable by CommitteeRegistry contract*


```solidity
function unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The address of the member unsubscribing|
|`_denomination`|`StreamDenomination`|The stream denomination to unsubscribe from|


### withdrawAvailableBalance

Withdraws available balance to the caller's address

*Can only withdraw balance that is not pre-staked or staked*

*Only callable when contract is unpaused*


```solidity
function withdrawAvailableBalance() external;
```

### selectCommittee

Randomly selects members to form a new committee for a given stream

*Pseudo-randomly select at least minCommitteeWatchtowers watchtowers and minCommitteeOperators operators.*

*reverts with notEnoughWatchtowers if there are fewer than minCommitteeWatchtowers watchtower candidates*

*reverts with notEnoughOperators if there are fewer than minCommitteeOperators operator candidates*

*Only callable by CommitteeRegistry contract*


```solidity
function selectCommittee(uint64 _streamId, uint256 _minWatchtowers, uint256 _minOperators, uint256 _totalMemberCount)
    external
    returns (CommitteeMember[] memory, PendingCommitteeStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID to select committee for|
|`_minWatchtowers`|`uint256`|Minimum number of watchtowers required|
|`_minOperators`|`uint256`|Minimum number of operators required|
|`_totalMemberCount`|`uint256`|Total number of members in committee|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CommitteeMember[]`|CommitteeMember[] Array of selected committee members|
|`<none>`|`PendingCommitteeStatus`|PendingCommitteeStatus Status of the selection process|


### releaseCommitteeMembers

Internal function to handle committee member release operations

*Called by CommitteeRegistry after committee completion*


```solidity
function releaseCommitteeMembers(CommitteeMember[] memory _committeeMembers, uint64 _streamId, uint64 _packetNumber)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_committeeMembers`|`CommitteeMember[]`|Array of committee members to release|
|`_streamId`|`uint64`|The stream ID|
|`_packetNumber`|`uint64`|The packet number|


### reAddCandidateToStream

External function to handle re-addition of members as candidates

*Called by CommitteeRegistry after pending committee reset*


```solidity
function reAddCandidateToStream(StreamDenomination _denomination, CommitteeMember memory _member) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream of the pending committee|
|`_member`|`CommitteeMember`|The member to re-add as candidate|


### setReApplyForStream

Sets the reapply flag for a member in a specific stream

*Controls whether the member will automatically reapply after committee release*


```solidity
function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination to set the flag for|
|`_reApply`|`bool`|True to automatically reapply, false to receive balance as available|


### disableMemberReApplyForStream

Sets the reapply flag as false for a member in a specific stream

*Controls that the member will not automatically reapply after committee release*


```solidity
function disableMemberReApplyForStream(address _memberAddress, StreamDenomination _denomination) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member adress|
|`_denomination`|`StreamDenomination`|The stream denomination to set the flag for|


### isMember

Returns whether the address belongs to a member


```solidity
function isMember(address _address) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when address was ever a member, false otherwise|


### getMemberTakePubKey

Gets the TAKE public key for a specific member


```solidity
function getMemberTakePubKey(address _address) external view returns (CompactPubKey memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CompactPubKey`|The TAKE public key in compact form (parity byte + x-coordinate)|


### getMemberComPubKey

Gets the COMMUNICATION public key for a specific member


```solidity
function getMemberComPubKey(address _address) external view returns (RSAPublicKey memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RSAPublicKey`|The COMMUNICATION public key (RSA struct)|


### getMemberDisputePubKey

Retrieves the DISPUTE public key for a specific member


```solidity
function getMemberDisputePubKey(address _address) external view returns (CompactPubKey memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`CompactPubKey`|The DISPUTE public key in compact form (parity byte + x-coordinate)|


### getMemberPublicKeys

Retrieves all public keys for a specific member


```solidity
function getMemberPublicKeys(address _address) external view returns (MemberKeys memory publicKeys);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`MemberKeys`|Member public keys structure|


### getMemberRequestedRole

Gets the requested role for a member in a specific stream


```solidity
function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
    external
    view
    returns (Role);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member's address|
|`_denomination`|`StreamDenomination`|The stream denomination|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Role`|The requested role for the member|


### getMemberAvailableBalance

Gets the available balance for a member


```solidity
function getMemberAvailableBalance(address _address) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The available balance that can be withdrawn|


### getMemberPreStakedBalance

Gets the pre-staked balance for a member in a specific stream


```solidity
function getMemberPreStakedBalance(address _memberAddress, StreamDenomination _denomination)
    external
    view
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_memberAddress`|`address`|The member's address|
|`_denomination`|`StreamDenomination`|The stream denomination|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The pre-staked balance for the stream|


### getMemberStakedBalance

Gets the staked balance for a member in a specific stream and packet


```solidity
function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
    external
    view
    returns (uint256 amount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|
|`_denomination`|`StreamDenomination`|The stream denomination|
|`_packetNumber`|`uint64`|The packet number|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The staked amount in the packet|


### getMemberFundingUTXO

Gets the funding UTXO for a member in a specific stream


```solidity
function getMemberFundingUTXO(uint64 _streamId, address _memberAddress) external view returns (UTXO memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_streamId`|`uint64`|The stream ID|
|`_memberAddress`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`UTXO`|The funding UTXO for the member's application to the stream|


### getCommitteeCandidates

Gets all candidates for a specific role in a stream


```solidity
function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
    external
    view
    returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination|
|`_role`|`Role`|The role to get candidates for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of candidate addresses|


### getReApplyForStream

Gets the reapply flag for a member in a specific stream


```solidity
function getReApplyForStream(StreamDenomination _denomination) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_denomination`|`StreamDenomination`|The stream denomination to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the member will automatically reapply, false otherwise|


### stakePreStakedCandidatesBalance

Moves candidates balance from pre staked to staked

*Called by CommitteeRegistry during committee formation*

*Only callable by Committee Registry contract*


```solidity
function stakePreStakedCandidatesBalance(
    CommitteeMember[] memory _members,
    StreamDenomination _denomination,
    uint64 _packetNumber
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_members`|`CommitteeMember[]`|Array of committee members|
|`_denomination`|`StreamDenomination`|The stream denomination|
|`_packetNumber`|`uint64`|The packet number|


### forceReleaseCommitteeMembers_TESTNET


```solidity
function forceReleaseCommitteeMembers_TESTNET(
    uint64 _streamId,
    uint64 _packetNumber,
    address[] memory _committeeMembersAddresses
) external;
```

### forceExit_TESTNET

WARNING! ONLY FOR TESTNET Forces a withdrawal of the contract's balance to a specified address

*Only callable on testnet, this function will leave the contract in a broken state and should be used only as a last resort*


```solidity
function forceExit_TESTNET(address _to) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to which the balance will be sent|


## Events
### NewMember
Event emitted when a new member is registered


```solidity
event NewMember(address indexed member, MemberKeys publicKeys);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member address|
|`publicKeys`|`MemberKeys`|The public keys of the new member|

### MemberUnsubscribedFromStream
Event emitted when a member unsubscribes from a stream


```solidity
event MemberUnsubscribedFromStream(address indexed member, StreamDenomination stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member's address|
|`stream`|`StreamDenomination`|The stream denomination|

### NewAvailableBalance
Event emitted when a member's balance is updated


```solidity
event NewAvailableBalance(address indexed memberAddress, uint256 availableBalance, uint256 preStakedBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`availableBalance`|`uint256`|The new available balance|
|`preStakedBalance`|`uint256`|The new pre-staked balance|

### AvailableBalanceRetrieved
Event emitted when available balance is withdrawn


```solidity
event AvailableBalanceRetrieved(address indexed sender, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address that withdrew the balance|
|`amount`|`uint256`|The amount withdrawn|

### NewSecurityBondDeposit
Event emitted when a security bond is deposited


```solidity
event NewSecurityBondDeposit(
    address indexed sender, StreamDenomination requestedStream, Role requestedRole, uint256 amount
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address that deposited the bond|
|`requestedStream`|`StreamDenomination`|The stream denomination|
|`requestedRole`|`Role`|The requested role|
|`amount`|`uint256`|The amount deposited|

### MemberReApplied
Event emitted when a member reapplies to a stream


```solidity
event MemberReApplied(
    address indexed memberAddress, StreamDenomination denomination, Role role, uint256 preStakedBalance
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|
|`role`|`Role`|The role requested by the member|
|`preStakedBalance`|`uint256`|The pre-staked balance for the application|

### MemberReApplyUpdated
Event emitted when a member's reapply flag is updated


```solidity
event MemberReApplyUpdated(address indexed memberAddress, StreamDenomination denomination, bool reApply);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|
|`reApply`|`bool`|The new reapply flag value|

### MissingWatchtowers
Event emitted when there are not enough watchtowers for committee formation


```solidity
event MissingWatchtowers(StreamDenomination denomination, uint256 required, uint256 missing);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`required`|`uint256`|Number of watchtowers required|
|`missing`|`uint256`|Number of watchtowers missing|

### MissingOperators
Event emitted when there are not enough operators for committee formation


```solidity
event MissingOperators(StreamDenomination denomination, uint256 required, uint256 missing);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`required`|`uint256`|Number of operators required|
|`missing`|`uint256`|Number of operators missing|

### MissingMembers
Event emitted when there are not enough total members for committee formation


```solidity
event MissingMembers(StreamDenomination denomination, uint256 required, uint256 missing);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`required`|`uint256`|Number of members required|
|`missing`|`uint256`|Number of members missing|

### BridgeUpdated
Event emitted when the bridge address is updated


```solidity
event BridgeUpdated(address indexed newBridge);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newBridge`|`address`|The new bridge address|

### CommitteeMembersForceReleased

```solidity
event CommitteeMembersForceReleased(uint64 indexed streamId, uint64 indexed packetNumber);
```

### ForceExit

```solidity
event ForceExit(address indexed to, uint256 amount);
```

## Errors
### MemberNotRegistered
Thrown when a member is not registered


```solidity
error MemberNotRegistered(address memberAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|

### MemberAlreadyRegisteredForStream
Thrown when a member is already registered for a stream


```solidity
error MemberAlreadyRegisteredForStream(
    address memberAddress, StreamDenomination requestedStream, Role requestedRole, Role currentRole
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`requestedStream`|`StreamDenomination`|The requested stream|
|`requestedRole`|`Role`|The requested role|
|`currentRole`|`Role`|The current role|

### MemberIsNotCandidateForStream
Thrown when a member is not a candidate for a stream


```solidity
error MemberIsNotCandidateForStream(address member, StreamDenomination stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member's address|
|`stream`|`StreamDenomination`|The stream denomination|

### NoAvailableBalanceToWithdraw
Thrown when there is no available balance to withdraw


```solidity
error NoAvailableBalanceToWithdraw(address member);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`member`|`address`|The member's address|

### DespositBondTooLow
Thrown when the deposit bond is too low


```solidity
error DespositBondTooLow(uint256 sent, uint256 minDeposit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sent`|`uint256`|The amount sent|
|`minDeposit`|`uint256`|The minimum deposit required|

### FailedToSendRSK
Thrown when RSK transfer fails


```solidity
error FailedToSendRSK(address memberAddress, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`amount`|`uint256`|The amount that failed to transfer|

### InvalidZeroValue
Thrown when a value is zero


```solidity
error InvalidZeroValue();
```

### ZeroUTXOTxid
Thrown when the funding UTXO transaction ID is zero


```solidity
error ZeroUTXOTxid(UTXO utxo);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`utxo`|`UTXO`|The complete UTXO with zero transaction ID|

### ZeroUTXOAmount
Thrown when the funding UTXO amount is zero


```solidity
error ZeroUTXOAmount(UTXO utxo);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`utxo`|`UTXO`|The complete UTXO with zero amount|

### RequestedNoneRoleForStream
Thrown when no role is requested for a stream


```solidity
error RequestedNoneRoleForStream(StreamDenomination stream);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stream`|`StreamDenomination`|The stream denomination|

### TooManyCandidatesForStream
Thrown when there are too many candidates for a stream


```solidity
error TooManyCandidatesForStream(StreamDenomination denomination, Role role);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`denomination`|`StreamDenomination`|The stream denomination|
|`role`|`Role`|The role for which there are too many candidates|

### InvalidEDCSAPublicKey
Thrown when a EDCSA public key is invalid (zero or not on curve)


```solidity
error InvalidEDCSAPublicKey(PublicKeyType keyType, bytes32 publicKeyX, bytes32 publicKeyY);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, DISPUTE, or COMMUNICATION)|
|`publicKeyX`|`bytes32`|The X-coordinate of the public key|
|`publicKeyY`|`bytes32`|The Y-coordinate of the public key|

### InvalidZeroRSAPublicKey
Thrown when a RSA public key is zero


```solidity
error InvalidZeroRSAPublicKey(PublicKeyType keyType);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, DISPUTE, or COMMUNICATION)|

### PublicKeyMismatchECDSA
Thrown when an ECDSA public key doesn't match the registered value


```solidity
error PublicKeyMismatchECDSA(PublicKeyType keyType, CompactPubKey registeredPubKey, CompactPubKey submittedPubKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE or DISPUTE)|
|`registeredPubKey`|`CompactPubKey`|The previously registered public key|
|`submittedPubKey`|`CompactPubKey`|The newly submitted public key|

### PublicKeyMismatchRSA
Thrown when an RSA public key hash doesn't match the registered value


```solidity
error PublicKeyMismatchRSA(bytes32 registeredKeyHash, bytes32 submittedKeyHash);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registeredKeyHash`|`bytes32`|Hash of the previously registered RSA public key|
|`submittedKeyHash`|`bytes32`|Hash of the newly submitted RSA public key|

### InvalidZeroEDCSASignature
Thrown when a signature is zero


```solidity
error InvalidZeroEDCSASignature(PublicKeyType keyType, ECDSAPublicKey publicKey);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, DISPUTE, or COMMUNICATION)|
|`publicKey`|`ECDSAPublicKey`|The public key registration with invalid signature|

### InvalidEDCSASignature
Thrown when a signature is invalid


```solidity
error InvalidEDCSASignature(
    PublicKeyType keyType, ECDSAPublicKey publicKey, address recoveredSignerAddress, address signerAddress
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`keyType`|`PublicKeyType`|The type of the public key (TAKE, DISPUTE, or COMMUNICATION)|
|`publicKey`|`ECDSAPublicKey`|The public key registration with invalid signature|
|`recoveredSignerAddress`|`address`|The address recovered from the signature|
|`signerAddress`|`address`|The expected signer address|

### _inconsistentPreStakedBalanceAndRole
Thrown when a member's pre-staked balance doesn't match their requested role requirements


```solidity
error _inconsistentPreStakedBalanceAndRole(
    address memberAddress, StreamDenomination denomination, uint256 preStakedBalance, Role requestedRole
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`memberAddress`|`address`|The member's address|
|`denomination`|`StreamDenomination`|The stream denomination|
|`preStakedBalance`|`uint256`|The member's pre-staked balance|
|`requestedRole`|`Role`|The role requested by the member|

### UnauthorizedAccount
Thrown when an account is not authorized to perform an operation


```solidity
error UnauthorizedAccount(address account);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The unauthorized account address|

