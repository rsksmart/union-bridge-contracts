// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {ContractAddressManager} from "script/helpers/ContractAddressManager.sol";
import {
    ICommitteeRegistry, MemberRegistrationKeys, MemberKeys, Role, UTXO
} from "src/interfaces/ICommitteeRegistry.sol";
import {IMemberRegistry} from "src/interfaces/IMemberRegistry.sol";
import {StreamDenomination, IStreamManager} from "src/interfaces/IStreamManager.sol";

contract ApplyToStreamScript is ScriptUtils, ContractAddressManager {
    ICommitteeRegistry committeeRegistry;
    IMemberRegistry memberRegistry;
    IStreamManager streamManager;
    uint256 minimumDeposit;
    uint256 mnemonicIndex;
    uint256 streamId;
    uint256 role;
    uint256 privKey;
    address user;
    MemberRegistrationKeys memberRegistrationKeys;
    UTXO fundingUTXO;

    function setUp(
        uint16 _mnemonicIndex,
        uint16 _streamIndex,
        uint16 _roleIndex,
        bytes32 _txid,
        uint32 _outputIndex,
        uint64 _amount
    ) internal {
        committeeRegistry = getCommitteeRegistry();
        memberRegistry = committeeRegistry.memberRegistry();
        streamManager = IStreamManager(getStreamManager());
        // Read args from command line / env
        mnemonicIndex = _mnemonicIndex;
        if (mnemonicIndex > 9) {
            revert("MNEMONIC_INDEX must be between 0 and 9");
        }
        streamId = _streamIndex;
        if (streamId > 4) {
            revert("STREAM_INDEX must be between 0 and 4");
        }
        role = _roleIndex;
        if (role > 2) {
            revert("ROLE_INDEX must be between 0 and 2");
        }

        minimumDeposit = streamManager.getMinimumDeposit(StreamDenomination(streamId), Role(role));
        privKey = getMemberKey(uint32(mnemonicIndex));
        user = vm.addr(privKey);
        MemberRegistrationKeys memory memberRegistrationKeysMemory = generateRegistrationPublicKeys(privKey);
        memberRegistrationKeys.takeKey = memberRegistrationKeysMemory.takeKey;
        memberRegistrationKeys.covenantKey = memberRegistrationKeysMemory.covenantKey;
        memberRegistrationKeys.communicationKey = memberRegistrationKeysMemory.communicationKey;

        if (user.balance < minimumDeposit) {
            revert("Insufficient balance to apply to stream");
        }

        if (_txid == bytes32(0)) {
            revert("Invalid UTXO: txid cannot be zero");
        }
        if (_amount == 0) {
            revert("Invalid UTXO: amount cannot be zero");
        }

        fundingUTXO = UTXO({txid: _txid, outputIndex: _outputIndex, amount: _amount});
    }

    function run(
        uint16 _mnemonicIndex,
        uint16 _streamIndex,
        uint16 _roleIndex,
        bytes32 _txid,
        uint32 _outputIndex,
        uint64 _amount
    ) public {
        setUp(_mnemonicIndex, _streamIndex, _roleIndex, _txid, _outputIndex, _amount);

        vm.startBroadcast(privKey);
        committeeRegistry.applyToStream{value: minimumDeposit}(
            StreamDenomination(streamId), Role(role), memberRegistrationKeys, fundingUTXO
        );
        vm.stopBroadcast();
        MemberKeys memory memberPubKeys = memberRegistry.getMemberPublicKeys(user);
        if (memberPubKeys.takePubKey != memberRegistrationKeys.takeKey.publicKeyX) {
            revert("applyToStream failed: take public key mismatch");
        }
        if (memberPubKeys.covenantPubKey != memberRegistrationKeys.covenantKey.publicKeyX) {
            revert("applyToStream failed: covenant public key mismatch");
        }
        if (
            keccak256(abi.encode(memberPubKeys.communicationPubKey))
                != keccak256(abi.encode(memberRegistrationKeys.communicationKey))
        ) {
            revert("applyToStream failed: communication public key mismatch");
        }

        console.log("=== User applied to stream successfully ===");
        // console.log("Mnemonic Index:", mnemonicIndex);
        // console.log("User:", user);
        // console.log("Stream:", streamId);
        // console.log("Role:", role);
        // console.log("Deposit:", minimumDeposit);
    }
}
