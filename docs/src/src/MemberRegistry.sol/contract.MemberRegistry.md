# MemberRegistry
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/bd6b4a28bf5973e554d9b7a237190a44cdd46b38/src/MemberRegistry.sol)

**Inherits:**
[IMemberRegistry](/src/interfaces/IMemberRegistry.sol/interface.IMemberRegistry.md), [BaseProxy](/src/BaseProxy.sol/abstract.BaseProxy.md), ReentrancyGuardUpgradeable, [Pausable](/src/Pausable.sol/abstract.Pausable.md)

Manages member registration, applications, and balance tracking for the union bridge system

*Handles member lifecycle operations including registration, candidacy, and balance management*


## State Variables
### members
Mapping of member addresses to their member data


```solidity
mapping(address => Member) internal members;
```


### committeesCandidates
Mapping of stream denomination and role to list of candidate addresses


```solidity
mapping(StreamDenomination denomination => mapping(Role role => address[] membersAddress)) internal committeesCandidates;
```


### streamManager
Stream manager contract for managing streams and packets


```solidity
IStreamManager public streamManager;
```


### accessManager
Access manager contract for managing access control


```solidity
IAccessManager public accessManager;
```


### rbtcBridge
RbtcBridge contract for Bitcoin block hash entropy


```solidity
IRbtcBridge public rbtcBridge;
```


## Functions
### initialize

Initializes the MemberRegistry contract


```solidity
function initialize(
    address _initialOwner,
    IAccessManager _accessManager,
    IRbtcBridge _rbtcBridge,
    IStreamManager _streamManager
) public virtual initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_initialOwner`|`address`|The initial owner of the contract|
|`_accessManager`|`IAccessManager`|The access manager contract address|
|`_rbtcBridge`|`IRbtcBridge`|The rbtc bridge contract address|
|`_streamManager`|`IStreamManager`||


### _validateFundingUTXO


```solidity
function _validateFundingUTXO(UTXO calldata _utxo) internal pure;
```

### _initMemberBalance


```solidity
function _initMemberBalance(Member storage _member) internal;
```

### _getOrRegisterMember


```solidity
function _getOrRegisterMember(address _address, MemberRegistrationKeys calldata _publicKeys)
    internal
    returns (Member storage);
```

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


### _committeesCandidatesHasSpace


```solidity
function _committeesCandidatesHasSpace(StreamDenomination _denomination, Role _role) internal view returns (bool);
```

### _registerCandidateToStream


```solidity
function _registerCandidateToStream(
    address _memberAddress,
    StreamDenomination _denomination,
    Role _role,
    uint256 _amount,
    UTXO calldata _fundingUTXO
) internal;
```

### unsubscribeFromStream

Internal function to handle member unsubscription from stream

*Called by CommitteeRegistry after pending committee checks*


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


```solidity
function withdrawAvailableBalance() external nonReentrant whenNotPaused;
```

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


### _reapplyToStream


```solidity
function _reapplyToStream(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber, Role _role)
    internal;
```

### _unsubscribeFromStream


```solidity
function _unsubscribeFromStream(address _memberAddress, StreamDenomination _denomination) internal;
```

### _movePreStakedToAvailable


```solidity
function _movePreStakedToAvailable(Member storage _member, address _memberAddress, StreamDenomination _denomination)
    internal;
```

### _removeFromCandidates


```solidity
function _removeFromCandidates(address _memberAddress, StreamDenomination _stream, Role _role) internal;
```

### _isRSAKeyEmpty


```solidity
function _isRSAKeyEmpty(bytes32[RSA_PUBLIC_KEY_CHUNKS] memory _rsaPublicKey) internal pure returns (bool);
```

### _getRSAKeyHash


```solidity
function _getRSAKeyHash(bytes32[RSA_PUBLIC_KEY_CHUNKS] memory _rsaPublicKey) internal pure returns (bytes32);
```

### _getAddressFromPublicKey


```solidity
function _getAddressFromPublicKey(bytes memory _uncompressedPublicKey) internal pure returns (address);
```

### _validatePublicKeys


```solidity
function _validatePublicKeys(MemberRegistrationKeys calldata _publicKeys) internal pure;
```

### _validateECDSAKey


```solidity
function _validateECDSAKey(ECDSAPublicKey calldata _key, PublicKeyType _type) internal pure;
```

### _validateRSAKey


```solidity
function _validateRSAKey(RSAPublicKey calldata _key, PublicKeyType _type) internal pure;
```

### _validateCompactPubKeyMatch


```solidity
function _validateCompactPubKeyMatch(
    CompactPubKey storage _stored,
    ECDSAPublicKey calldata _submitted,
    PublicKeyType _keyType
) internal view;
```

### _validateMemberKeyMatch


```solidity
function _validateMemberKeyMatch(Member storage _member, MemberRegistrationKeys calldata _publicKeys) internal view;
```

### _registerMember


```solidity
function _registerMember(address _memberAddress, MemberRegistrationKeys calldata _publicKeys)
    internal
    returns (Member storage);
```

### getMemberTakePubKey

Gets the TAKE public key for a specific member


```solidity
function getMemberTakePubKey(address _address) external view override returns (CompactPubKey memory);
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
function getMemberComPubKey(address _address) external view override returns (RSAPublicKey memory);
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
function getMemberDisputePubKey(address _address) external view override returns (CompactPubKey memory);
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
function getMemberPublicKeys(address _address) external view override returns (MemberKeys memory publicKeys);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_address`|`address`|The member's address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`publicKeys`|`MemberKeys`|Member public keys structure|


### _getMemberApplicationData


```solidity
function _getMemberApplicationData(address _address, StreamDenomination _denomination)
    internal
    view
    returns (ApplicationData storage);
```

### getMemberRequestedRole

Gets the requested role for a member in a specific stream


```solidity
function getMemberRequestedRole(address _memberAddress, StreamDenomination _denomination)
    external
    view
    override
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
function getMemberAvailableBalance(address _address) external view override returns (uint256);
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
    override
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
    override
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
function getMemberFundingUTXO(uint64 _streamId, address _memberAddress) external view override returns (UTXO memory);
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


### _getMember


```solidity
function _getMember(address _address) internal view returns (Member storage member);
```

### getCommitteeCandidates

Gets all candidates for a specific role in a stream


```solidity
function getCommitteeCandidates(StreamDenomination _denomination, Role _role)
    external
    view
    override
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


### setReApplyForStream

Sets the reapply flag for a member in a specific stream

*Controls whether the member will automatically reapply after committee release*


```solidity
function setReApplyForStream(StreamDenomination _denomination, bool _reApply) external override whenNotPaused;
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


### _setReApplyForStream


```solidity
function _setReApplyForStream(address _memberAddress, StreamDenomination _denomination, bool _reApply) internal;
```

### getReApplyForStream

Gets the reapply flag for a member in a specific stream


```solidity
function getReApplyForStream(StreamDenomination _denomination) external view override returns (bool);
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


### _movePreStakedToStaked


```solidity
function _movePreStakedToStaked(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
    internal;
```

### _moveStakedToAvailable


```solidity
function _moveStakedToAvailable(address _memberAddress, StreamDenomination _denomination, uint64 _packetNumber)
    internal;
```

### _getRandomPosition

Calculates a pseudo-random position within an array

*Uses Bitcoin block hash as entropy source combined with array length*


```solidity
function _getRandomPosition(bytes32 _btcBlockHash, uint256 _arrayLength) private pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_btcBlockHash`|`bytes32`|The Bitcoin block hash used for entropy|
|`_arrayLength`|`uint256`|The length of the array to select from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The pseudo-random position within the array (0 to _arrayLength - 1)|


### selectCommittee

Randomly selects members to form a new committee for a given stream

*Pseudo-randomly select at least minCommitteeWatchtowers watchtowers and minCommitteeOperators operators.*


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


### _selectCommittee


```solidity
function _selectCommittee(uint64 _streamId, uint256 _minWatchtowers, uint256 _minOperators, uint256 _totalMemberCount)
    internal
    returns (CommitteeMember[] memory, PendingCommitteeStatus);
```

### forceReleaseCommitteeMembers_TESTNET


```solidity
function forceReleaseCommitteeMembers_TESTNET(
    uint64 _streamId,
    uint64 _packetNumber,
    address[] memory _committeeMembersAddresses
) external onlyOwner;
```

### forceExit_TESTNET

WARNING! ONLY FOR TESTNET Forces a withdrawal of the contract's balance to a specified address

*Only callable on testnet, this function will leave the contract in a broken state and should be used only as a last resort*


```solidity
function forceExit_TESTNET(address _to) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address to which the balance will be sent|


