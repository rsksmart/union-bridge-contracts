// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {
    ICommitteeRegistry,
    Committee,
    CommunicationData,
    COMMUNICATION_DATA_CHUNKS
} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";

contract DepositCommunicationDataScript is ScriptUtils, ContractAddressManager {
    ICommitteeRegistry committeeRegistry;
    IMemberRegistry memberRegistry;

    bytes committeePubKey;
    uint16 mnemonicIndex;
    uint64 stream;
    uint256 privKey;
    address user;
    bytes32 comPubKey;

    function setUp(uint16 _mnemonicIndex, uint64 _streamIndex) internal {
        committeeRegistry = ICommitteeRegistry(getCommitteeRegistry());
        memberRegistry = committeeRegistry.memberRegistry();

        // Read args from command line / env
        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("mnemonic index must be between 0 and 9");
        }
        stream = _streamIndex;
        if (stream > 4) {
            revert("stream index must be between 0 and 4");
        }

        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);

        comPubKey = generateRegistrationPublicKeys(privKey).communicationKey;
    }

    function run(uint16 _mnemonicIndex, uint64 _streamIndex) public {
        setUp(_mnemonicIndex, _streamIndex);

        vm.startBroadcast(privKey);
        bytes32[] memory committeeComPubkeys = getPendingCommitteeComPubKeys(stream);
        vm.stopBroadcast();

        uint128 committeeId = committeeRegistry.getPendingCommitteeId(stream);
        CommunicationData[] memory newMemberComunicationData = encryptComunicationData(committeeComPubkeys, "ip:port");

        vm.startBroadcast(privKey);
        committeeRegistry.depositCommunicationData(committeeId, newMemberComunicationData);
        vm.stopBroadcast();

        // console.log("=== Member deposited communication data successfully ===");
        // console.log("Mnemonic Index:", mnemonicIndex);
        // console.log("User:", user);
        // console.log("Stream:", stream);
        // console.log("Data:");
        // for (uint256 i = 0; i < memberComunicationData.length; i++) {
        //     console.log("Member ", i, ":");
        //     for (uint256 j = 0; j < COMMUNICATION_DATA_CHUNKS; j++) {
        //         console.logBytes32(memberComunicationData[i].data[j]);
        //     }
        // }
    }

    function encryptComunicationData(bytes32[] memory committeeComPubkeys, string memory data)
        internal
        view
        returns (CommunicationData[] memory)
    {
        CommunicationData[] memory encryptedData = new CommunicationData[](committeeComPubkeys.length);
        for (uint256 i = 0; i < committeeComPubkeys.length; i++) {
            if (committeeComPubkeys[i] == comPubKey) {
                continue;
            }
            encryptedData[i] = encryptData(committeeComPubkeys[i], data);
        }
        return encryptedData;
    }

    function encryptData(bytes32 _communicationPublicKey, string memory data)
        internal
        pure
        returns (CommunicationData memory)
    {
        // Placeholder for actual encryption logic
        // Here we just simulate "encryption" by concatenating the public key and data
        bytes memory flat = abi.encodePacked(_communicationPublicKey, ":", data);

        require(flat.length <= 256, "Communication data too large");

        bytes32[COMMUNICATION_DATA_CHUNKS] memory result;

        for (uint256 i = 0; i < COMMUNICATION_DATA_CHUNKS; i++) {
            uint256 offset = i * 32;
            if (offset >= flat.length) break;

            bytes memory chunk = new bytes(32);
            for (uint256 j = 0; j < 32 && (offset + j) < flat.length; j++) {
                chunk[j] = flat[offset + j];
            }

            result[i] = bytesToBytes32(chunk);
        }

        return CommunicationData({data: result});
    }

    function bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        require(source.length <= 32, "Invalid chunk size");
        assembly {
            result := mload(add(source, 32))
        }
    }

    function getPendingCommitteeComPubKeys(uint64 _streamId) internal view returns (bytes32[] memory) {
        Committee memory committee = committeeRegistry.getPendingCommittee(_streamId);

        bytes32[] memory committeeMembersPubKeys = new bytes32[](committee.members.length);
        for (uint256 i = 0; i < committee.members.length; i++) {
            address memberAddress = committee.members[i].memberAddress;
            committeeMembersPubKeys[i] = memberRegistry.getMemberComPubKey(memberAddress);
        }
        return committeeMembersPubKeys;
    }
}
