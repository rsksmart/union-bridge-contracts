// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {StreamDenomination} from "./IStreamManager.sol";

enum Role {
    None,
    Operator,
    Watchtower
}

struct Balance {
    uint256 available;
    uint256[] preStaked;
    mapping(uint64 packetNumber => uint256 amount)[] staked; // denominationIndex => (packetId => amount)
}

struct Member {
    bytes32 publicKey;
    mapping(StreamDenomination => Role) requestedRoles;
    Balance balance;
    mapping(string key => string value) data;
}

struct CommitteeMember {
    uint16 index; // from the members array
    Role role;
}

struct Committee {
    bytes32 internalKey; // BTC public key of the commitee
    CommitteeMember[] memberIndexesAndRoles; // Indices and roles of the members from the members array
    uint8 leaderIndex; // TODO add leader logic
}

interface ICommitteeRegistry {
    error RequestedNoneRoleForStream(StreamDenomination stream);
    error NonRegisteredMember(address memberAddress);
    error TooManyMembers(uint256 maxMembers);
    error TooManyMembersPerCommittee(uint256 maxMembersPerCommittee);
    error TooManyCommittees(uint256 maxCommitteeSize);
    error AlreadyRegisteredCommittee(bytes32 committeeKey);
    error NotEnoughWatchtowers(uint256 required, uint256 available);
    error NotEnoughOperators(uint256 required, uint256 available);
    error NotEnoughMembers(uint256 required, uint256 available);
    error MemberAlreadyRegisteredForStream(
        address memberAddress, StreamDenomination requestedStream, Role requestedRole, Role currentRole
    );
    error MemberIsNotCandidateForStream(address member, StreamDenomination stream);
    error NoAvailableBalanceToWithdraw(address member);
    error MemberIndexNotFound(uint16 memberIndex);
    error MemberNotRegistered(address memberAddress);

    function depositBond(bytes32 _publicKey, StreamDenomination _requestedStream, Role _requestedRole)
        external
        payable;

    function unsuscribeFromStream(StreamDenomination _stream) external;

    function withdrawAvailableBalance() external;

    function getMemberPublicKey(address _address) external view returns (bytes32);

    function getMemberRequestedRole(address _address, StreamDenomination _denomination) external view returns (Role);

    function getMemberAvailableBalance(address _address) external view returns (uint256);

    function getMemberPreStakedBalance(address _address, StreamDenomination _denomination)
        external
        view
        returns (uint256);

    function getMemberStakedBalance(address _address, StreamDenomination _denomination, uint64 _packetNumber)
        external
        view
        returns (uint256 amount);

    function getCommitteeCandidates(StreamDenomination _denomination)
        external
        view
        returns (CommitteeMember[] memory);

    function registerCommittee(Committee calldata _committee) external;

    function getCommittee(bytes32 _committeeKey) external view returns (Committee calldata);

    function getCommitteeMember(bytes32 _committeeKey) external view returns (CommitteeMember[] memory);

    function getCommitteeByIndex(uint256 _committeeIndex) external view returns (bytes32);

    function getCommitteesLength() external view returns (uint256);

    function getNextAvailableCommittee() external view returns (Committee calldata);

    function getMemberPubKeyByIndex(uint16 _memberIndex) external view returns (bytes32);

    function getMemberIndexByAddress(address _address) external view returns (uint16);

    function createCommittee(uint64 _streamId) external view returns (bytes32);

    function selectCommittee(uint64 _streamId) external view returns (CommitteeMember[] memory);
}
