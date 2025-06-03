// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {BaseProxy} from "./BaseProxy.sol";
import {
    Role,
    Member,
    CommitteeMember,
    Committee,
    ICommitteeRegistry,
    PendingCommittee,
    PendingCommitteeData
} from "./interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, IStreamManager} from "./interfaces/IStreamManager.sol";
import {IPegManager} from "./interfaces/IPegManager.sol";

contract CommitteeRegistry is ICommitteeRegistry, BaseProxy {
    // Address of the Memeber => Amount provided
    Member[] internal members;

    uint256 public constant MAX_COMMITTEES_SIZE = 100;
    uint256 public constant MAX_MEMBERS_SIZE = 256;
    uint256 public constant MAX_MEMBERS_PER_COMMITTEE = 100;

    // Committee selection constants
    uint256 public constant MIN_WATCHTOWERS = 3;
    uint256 public constant MIN_OPERATORS = 3;
    // NOTE: Should fit condition MIN_COMMITTEE_MEMBERS > MIN_WATCHTOWERS + MIN_OPERATORS
    uint256 public constant MIN_COMMITTEE_MEMBERS = 10;

    mapping(uint64 => PendingCommittee) internal pendingCommittees;
    mapping(uint256 => Committee) internal committeesByKey;

    // NOTE: This is a mapping of the members, where the key is the address and the value is the index in the members array + 1
    mapping(address => uint16) internal memberIndexByAddress;
    IStreamManager streamManager;
    address pegManager;

    // TODO: This will be tackle later on in another story
    uint256 public constant pendingCommitteeTimelock = 1 days;

    mapping(StreamDenomination denomination => CommitteeMember[]) internal committeesCandidates;

    function initialize(address _initialOwner) public virtual initializer {
        __BaseProxy_init(_initialOwner);
    }

    function setStreamManager(IStreamManager _streamManager) public {
        streamManager = _streamManager;
    }

    function getMinimumDeposit(StreamDenomination _denomination) public view returns (uint256) {
        return streamManager.getStreamById(uint8(_denomination)).securityBondValue;
    }

    function _initMemberBalance(Member storage _member) internal {
        uint64 streams = streamManager.getStreamsLength();
        _member.balance.available = 0;
        _member.balance.preStaked = new uint256[](streams);
        for (uint64 i = 0; i < streams; i++) {
            _member.balance.preStaked[i] = 0;
        }
        for (uint256 i = 0; i < streams; i++) {
            _member.balance.staked.push();
        }
    }

    // FIXME: Temporary function to register a committee, should be deleted when createCommittee is called in setup
    function registerCommittee(uint256 _committeeId, Committee calldata _committee) external {
        if (committeesByKey[_committeeId].memberIndexesAndRoles.length != 0) {
            revert AlreadyRegisteredCommittee(_committeeId);
        }

        committeesByKey[_committeeId] = _committee;
        emit NewCommittee(_committeeId, _committee);
    }

    function _getMemberPubKeyByAddress(address _address) internal view returns (bytes32) {
        uint16 memberIndex = memberIndexByAddress[_address];
        if (memberIndex == 0) {
            return bytes32(0);
        }
        // Substract 1 to get the correct index
        return members[memberIndex - 1].publicKey;
    }

    function applyToStream(bytes32 _publicKey, StreamDenomination _stream, Role _role) external payable {
        // Check if the member is already registered
        if (!_isAlreadyMember(msg.sender)) {
            _registerMember(_publicKey);
        }

        Member storage member = _getMemberByAddress(msg.sender);

        if (member.publicKey != _publicKey) {
            revert PublicKeyMismatch(member.publicKey, _publicKey);
        }
        if (_role == Role.None) {
            revert RequestedNoneRoleForStream(_stream);
        }
        if (member.requestedRoles[_stream] != Role.None) {
            revert MemberAlreadyRegisteredForStream(msg.sender, _stream, _role, member.requestedRoles[_stream]);
        }
        uint256 minDeposit = getMinimumDeposit(_stream);
        if (msg.value < minDeposit) {
            revert DespositBondTooLow(msg.value, minDeposit);
        }

        _registerCandidateToStream(msg.sender, _stream, _role, msg.value);

        emit NewSecurityBondDeposit(msg.sender, _stream, _role, msg.value);
    }

    // NOTE: This function intends to keep many different structures in sync, be careful when modifying it
    function _registerCandidateToStream(address _memberAddress, StreamDenomination _stream, Role _role, uint256 _amount)
        internal
    {
        Member storage member = _getMemberByAddress(_memberAddress);

        member.balance.preStaked[uint8(_stream)] = _amount;
        member.requestedRoles[_stream] = _role;

        committeesCandidates[_stream].push(CommitteeMember({index: _getMemberIndexByAddress(msg.sender), role: _role}));
    }

    function unsubscribeFromStream(StreamDenomination _stream) external {
        Member storage member = _getMemberByAddress(msg.sender);

        if (member.requestedRoles[_stream] == Role.None) {
            revert MemberIsNotCandidateForStream(msg.sender, _stream);
        }

        uint256 available = _removeStreamCandidate(msg.sender, _stream);
        emit MemberUnsubscribedFromStream(msg.sender, _stream);
        emit NewAvailableBalance(msg.sender, available);
    }

    // NOTE: This function intends to keep many different structures in sync, be careful when modifying it
    function _removeStreamCandidate(address _memberAddress, StreamDenomination _stream)
        internal
        returns (uint256 preStakedAmount)
    {
        Member storage member = _getMemberByAddress(_memberAddress);

        preStakedAmount = member.balance.preStaked[uint8(_stream)];

        member.balance.available += preStakedAmount;
        member.balance.preStaked[uint8(_stream)] = 0;
        member.requestedRoles[_stream] = Role.None;

        // Remove from candidates
        CommitteeMember[] storage candidates = committeesCandidates[_stream];
        uint16 memberIndex = _getMemberIndexByAddress(_memberAddress);
        uint256 length = candidates.length;

        // NOTE: This effectively brings the last candidate forward in the list by replacing the removed member
        for (uint256 i = 0; i < length; i++) {
            if (candidates[i].index == memberIndex) {
                candidates[i] = candidates[length - 1];
                candidates.pop();
                break;
            }
        }
    }

    function withdrawAvailableBalance() external {
        Member storage member = _getMemberByAddress(msg.sender);
        uint256 amount = member.balance.available;
        if (amount == 0) {
            revert NoAvailableBalanceToWithdraw(msg.sender);
        }
        member.balance.available = 0;
        emit AvailableBalanceRetrieved(msg.sender, amount);

        (bool sent,) = msg.sender.call{value: amount}("");
        if (!sent) {
            revert FailedToSendRSK(msg.sender, amount);
        }
    }

    function _isAlreadyMember(address _address) internal view returns (bool) {
        return memberIndexByAddress[_address] != 0;
    }

    function _registerMember(bytes32 _publicKey) internal {
        // Check max Members
        if (members.length >= MAX_MEMBERS_SIZE) {
            revert TooManyMembers(MAX_MEMBERS_SIZE);
        }

        members.push(); // Expand the array
        Member storage member = members[members.length - 1]; // Get reference
        member.publicKey = _publicKey;
        _initMemberBalance(member);
        // We save the position in the array + 1, to avoid 0 as a valid index, it is then substracted in getMemberPubKeyByAddress
        memberIndexByAddress[msg.sender] = uint16(members.length);

        emit NewMember(_publicKey);
    }

    function _registerCommittee(uint256 _committeeId, Committee storage _committee) internal {
        // Check if exists
        // NOTE: Could we ignore this check due to committeeId being unique?
        if (committeesByKey[_committeeId].aggregatedKey != bytes32(0)) {
            return;
        }

        committeesByKey[_committeeId] = _committee;
        emit NewCommittee(_committeeId, _committee);
    }

    function getCommittee(uint256 _committeeId) public view returns (Committee memory) {
        Committee memory committee = committeesByKey[_committeeId];
        if (committee.memberIndexesAndRoles.length == 0) {
            revert CommitteeNotFound(_committeeId);
        }
        return committee;
    }

    function getMembersLength() external view returns (uint256) {
        return members.length;
    }

    function getCommitteeMembers(uint256 _committeeId) external view returns (CommitteeMember[] memory) {
        return getCommittee(_committeeId).memberIndexesAndRoles;
    }

    function getMemberPubKeyByIndex(uint16 _memberIndex) external view returns (bytes32) {
        if (_memberIndex >= members.length) {
            revert MemberIndexNotFound(_memberIndex);
        }
        return members[_memberIndex].publicKey;
    }

    function getMemberIndexByAddress(address _address) external view returns (uint16) {
        return _getMemberIndexByAddress(_address);
    }

    function _getMemberIndexByAddress(address _address) internal view returns (uint16) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            revert MemberNotRegistered(_address);
        }
        if (memberIndex > members.length) {
            revert _MemberIndexOutOfBounds(memberIndex);
        }

        // Substract 1 to get the correct index
        return memberIndex - 1;
    }

    function getMemberPublicKey(address _address) external view returns (bytes32) {
        return _getMemberByAddress(_address).publicKey;
    }

    function getMemberRequestedRole(address _address, StreamDenomination _denomination) external view returns (Role) {
        return _getMemberByAddress(_address).requestedRoles[_denomination];
    }

    function getMemberAvailableBalance(address _address) external view returns (uint256) {
        return _getMemberByAddress(_address).balance.available;
    }

    function getMemberPreStakedBalance(address _address, StreamDenomination _denomination)
        external
        view
        returns (uint256)
    {
        return _getMemberByAddress(_address).balance.preStaked[uint8(_denomination)];
    }

    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount)
    {
        return _getMemberByAddress(_address).balance.staked[uint8(_denomination)][_packetNumber];
    }

    function _getMemberByAddress(address _address) internal view returns (Member storage) {
        uint16 memberIndex = memberIndexByAddress[_address];

        // 0 is reserved for non registered members
        if (memberIndex == 0) {
            revert NonRegisteredMember(_address);
        }

        // Substract 1 to get the correct index
        return members[memberIndex - 1];
    }

    function createCommittee(uint64 _streamId) external onlyPegManager {
        // TODO: Validate if the streamId is valid
        // TODO: Validate who can call this function. PegManager and external or in setup.
        // If it's called externally we should check that we really need to create a new committee.
        // Or maybe validate that there is a pending committee that it's expired

        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.expireAt != 0) {
            // slither-disable-next-line timestamp
            if (block.timestamp < pendingCommittee.expireAt) {
                // This is called from the pegManager, so we should not revert.
                return;
            }

            _slashCommittee();
            _deletePendingCommittee(_streamId);
        }
        _createCommittee(_streamId);
    }

    function _createCommittee(uint64 _streamId) internal returns (bool) {
        CommitteeMember[] memory committeeMembers = _selectCommittee(_streamId);
        if (committeeMembers.length == 0) {
            // This is called from the pegManager, so we should not revert.
            return false;
        }

        pendingCommittees[_streamId].expireAt = block.timestamp + pendingCommitteeTimelock;
        pendingCommittees[_streamId].missingData = uint16(committeeMembers.length);

        // Initialize the committee members here.
        // No need to initialize aggregatedKey, since it will be set by the members.
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            // Copy committee members from memory to storage
            pendingCommittees[_streamId].committee.memberIndexesAndRoles.push(committeeMembers[i]);

            bytes32 memberPubKey = members[committeeMembers[i].index].publicKey;
            // Initialize committee users pending data
            pendingCommittees[_streamId].data[memberPubKey] =
                PendingCommitteeData({inCommittee: true, aggregatedKey: bytes32(0)});
        }
        emit NewPendingCommittee(_streamId, pendingCommittees[_streamId].committee);
        return true;
    }

    function depositMemberInfoForCommittee(uint64 _streamId, bytes32 _aggregatedKey) external {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.expireAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }

        if (_aggregatedKey == bytes32(0)) {
            revert InvalidAgregatedKey();
        }

        bytes32 memberPubKey = _getCurrentMemberPubKey();
        if (!pendingCommittee.data[memberPubKey].inCommittee) {
            revert MemberNotInCommittee(memberPubKey);
        }

        if (pendingCommittee.data[memberPubKey].aggregatedKey != bytes32(0)) {
            revert MemberAlreadyUpdated(memberPubKey);
        }

        pendingCommittee.data[memberPubKey].aggregatedKey = _aggregatedKey;

        if (pendingCommittee.committee.aggregatedKey == bytes32(0)) {
            // Save the agregated key for the committee
            pendingCommittee.committee.aggregatedKey = _aggregatedKey;
        } else {
            if (pendingCommittee.committee.aggregatedKey != _aggregatedKey) {
                _deletePendingCommittee(_streamId);
                _createCommittee(_streamId); // Ignoring checks
                return;
            }
        }

        pendingCommittee.missingData--;
        if (pendingCommittee.missingData != 0) {
            // Committee is not completed yet
            return;
        }

        // Create unique committee id associated to the streamId and packetNumber.
        uint256 committeeId = uint256(keccak256(abi.encode(_streamId, streamManager.getPacketsLength(_streamId))));
        _registerCommittee(committeeId, pendingCommittee.committee);
        // create new packet
        streamManager.createNewPacket(_streamId, committeeId, pendingCommittee.committee.aggregatedKey);
        _deletePendingCommittee(_streamId);
    }

    function _slashCommittee() internal {
        // TODO: slash the members. Sasasaaa.
    }

    function getPendingCommittee(uint64 _streamId)
        public
        view
        returns (Committee memory committee, uint256 expiredAt, uint256 missingData)
    {
        PendingCommittee storage pendingCommittee = pendingCommittees[_streamId];
        if (pendingCommittee.expireAt == 0) {
            revert CommitteeIsNotPending(_streamId);
        }
        committee = pendingCommittee.committee;
        expiredAt = pendingCommittee.expireAt;
        missingData = pendingCommittee.missingData;
    }

    function _getCurrentMemberPubKey() internal view returns (bytes32) {
        bytes32 memberPubKey = _getMemberPubKeyByAddress(msg.sender);
        if (memberPubKey == bytes32(0)) {
            revert MemberNotFound(msg.sender);
        }
        return memberPubKey;
    }

    function isPendingCommitteeExpired(uint64 _streamId) external view returns (bool) {
        uint256 expireAt = pendingCommittees[_streamId].expireAt;
        // If no pending committee in proccess we return false
        if (expireAt == 0) {
            return false;
        }
        // slither-disable-next-line timestamp
        return block.timestamp > expireAt;
    }

    function _deletePendingCommittee(uint64 _streamId) internal {
        CommitteeMember[] storage committeeMembers = pendingCommittees[_streamId].committee.memberIndexesAndRoles;
        for (uint256 i = 0; i < committeeMembers.length; i++) {
            bytes32 memberPubKey = members[committeeMembers[i].index].publicKey;
            delete pendingCommittees[_streamId].data[memberPubKey];
        }
        //slither-disable-next-line mapping-deletion
        delete pendingCommittees[_streamId];
    }

    function setPegManager(IPegManager _pegManager) external onlyOwner {
        if (address(_pegManager) == address(0)) {
            revert InvalidZeroAddress();
        }
        pegManager = address(_pegManager);
    }

    modifier onlyPegManager() {
        _checkPegManager();
        _;
    }

    /**
     * @dev Throws if the sender is not the pegManager.
     */
    function _checkPegManager() internal view virtual {
        if (pegManager != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    function getCommitteeCandidates(StreamDenomination _denomination)
        external
        view
        returns (CommitteeMember[] memory)
    {
        return committeesCandidates[_denomination];
    }

    /**
     * @notice Randomly selects members to form a new committee for a given stream
     * @dev Pseudo-randomly select at least MIN_WATCHTOWERS watchtowers and MIN_OPERATORS operators.
     * - reverts with notEnoughWatchtowers if there are fewer than MIN_WATCHTOWERS watchtower candidates
     * - reverts with notEnoughOperators if there are fewer than MIN_OPERATORS operator candidates
     *
     * @param _streamId The ID of the stream to select committee members for (0-4)
     * @return An array of MIN_COMMITTEE_MEMBERS CommitteeMembers containing the selected members.
     *
     */
    function _selectCommittee(uint64 _streamId) internal view returns (CommitteeMember[] memory) {
        // Get the stream denomination for the streamId
        StreamDenomination denomination = StreamDenomination(_streamId);

        // Get all candidates for this denomination
        CommitteeMember[] memory candidates = committeesCandidates[denomination];
        uint256 candidatesLength = candidates.length;

        // Separate watchtowers and operators
        uint256[] memory watchtowerIndices = new uint256[](candidatesLength);
        uint256[] memory operatorIndices = new uint256[](candidatesLength);
        uint256 watchtowerCount = 0;
        uint256 operatorCount = 0;

        for (uint256 i = 0; i < candidatesLength; i++) {
            if (candidates[i].role == Role.Watchtower) {
                watchtowerIndices[watchtowerCount] = i;
                watchtowerCount++;
            } else if (candidates[i].role == Role.Operator) {
                operatorIndices[operatorCount] = i;
                operatorCount++;
            }
        }

        // Ensure we have enough candidates
        if (watchtowerCount < MIN_WATCHTOWERS) {
            revert NotEnoughWatchtowers(MIN_WATCHTOWERS, watchtowerCount);
        }
        if (operatorCount < MIN_OPERATORS) {
            revert NotEnoughOperators(MIN_OPERATORS, operatorCount);
        }

        // Check if we have enough total members for the committee
        uint256 totalAvailableMembers = watchtowerCount + operatorCount;
        if (totalAvailableMembers < MIN_COMMITTEE_MEMBERS) {
            revert NotEnoughMembers(MIN_COMMITTEE_MEMBERS, totalAvailableMembers);
        }

        // Amount of each members per role in the committee
        // NOTE: Here assumme that MIN_COMMITTEE_MEMBERS > MIN_WATCHTOWERS + MIN_OPERATORS
        uint256 operatorsCommitteeAmount = (MIN_COMMITTEE_MEMBERS - MIN_WATCHTOWERS > operatorCount)
            ? operatorCount
            : MIN_COMMITTEE_MEMBERS - MIN_WATCHTOWERS;
        uint256 watchtowerCommitteeAmount = MIN_COMMITTEE_MEMBERS - operatorsCommitteeAmount;
        uint256 committeeMembersCounter = 0;

        // Create the final committee with MIN_COMMITTEE_MEMBERS members
        CommitteeMember[] memory selectedMembers = new CommitteeMember[](MIN_COMMITTEE_MEMBERS);

        // True randomness is not required here. We only need enough unpredictability to ensure
        // different committee members get selected across multiple runs.
        // We use Fisher-Yates shuffle because it guarantees each index is selected exactly once.
        // This way we avoid index collisions and infinite loops.

        // Select random operators
        for (uint256 length = operatorCount; length > operatorCount - operatorsCommitteeAmount; length--) {
            // slither-disable-next-line weak-prng
            uint256 randomPos = uint256(keccak256(abi.encode(block.timestamp, length))) % length;

            // This indexing will be simplified when `candidates` array is split in `watchtowers` and `operators` arrays
            selectedMembers[committeeMembersCounter++] = candidates[operatorIndices[randomPos]];

            // Just move last position to replace random position. There is no need to swap values now.
            operatorIndices[randomPos] = operatorIndices[length - 1];
        }

        // Select random watchtowers
        for (uint256 length = watchtowerCount; length > watchtowerCount - watchtowerCommitteeAmount; length--) {
            // slither-disable-next-line weak-prng
            uint256 randomPos = uint256(keccak256(abi.encode(block.timestamp, length))) % length;

            // This indexing will be simplified when `candidates` array is split in `watchtowers` and `operators` arrays
            selectedMembers[committeeMembersCounter++] = candidates[watchtowerIndices[randomPos]];

            // Just move last position to replace random position. There is no need to swap values now.
            watchtowerIndices[randomPos] = watchtowerIndices[length - 1];
        }

        return selectedMembers;
    }
}
