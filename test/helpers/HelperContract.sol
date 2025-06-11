// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ScriptUtils} from "script/helpers/ScriptUtils.sol";
import {DeployScript} from "script/deploy/DeployScript.s.sol";
import {PegManager, BtcTxSPVProof, PegStatus} from "src/PegManager.sol";
import {PegManagerHarness} from "test/helpers/PegManagerHarness.sol";
import {StreamManagerHarness} from "test/helpers/StreamManagerHarness.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {
    Role,
    Member,
    CommitteeMember,
    Committee,
    CommitteeRegistry,
    PublicKeyRegistration
} from "src/CommitteeRegistry.sol";
import {StreamDenomination} from "src/interfaces/IStreamManager.sol";
import {BtcTxIn, BtcTxOut, BtcTransaction} from "src/interfaces/IBitcoinManager.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BtcTxEncoder} from "src/libraries/BtcTxEncoder.sol";
import {RSK_BRIDGE_ADDRESS, IBridge} from "src/interfaces/IBridge.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {TestUtils} from "./TestUtils.sol";
import {Constants} from "src/libraries/Constants.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {Stream, SlotState} from "src/interfaces/IStreamManager.sol";
import {CommitteeRegistryHarness} from "./CommitteeRegistryHarness.sol";

abstract contract HelperContract is Test, TestUtils {
    bytes32 internal constant BTC_REIMBURSEMENT_PUBKEY =
        0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;

    uint256 constant COMMITTEE_ID_STREAM_1_PACKET_0 =
        78541660797044910968829902406342334108369226379826116161446442989268089806461;
    uint256 constant COMMITTEE_ID_STREAM_1_PACKET_1 =
        92458281274488595289803937127152923398167637295201432141969818930235769911599;
    bytes32 constant COMMITTEE_PUB_KEY = 0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d;

    // Dummy requested roles and streams for the members
    StreamDenomination internal constant DEFAULT_STREAM = StreamDenomination._0_001BTC;
    Role internal constant DEFAULT_ROLE = Role.Operator;

    BitcoinManager internal bitcoinManager;
    BridgeMock internal bridgeMock;
    CommitteeRegistryHarness internal registry;
    PegManagerHarness internal pm;
    SignatureManager internal signatureManager;
    StreamManagerHarness internal streamManager;

    // Arrange
    uint64 internal constant VALUE = 1_000_000; // 0.01 BTC
    uint256 internal constant BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE = 1000; // Arbitrary timestamp for random committee selection. Changing it will change all random committees
    uint256 registeredMembersCounter = 0; // Counter to keep track of registered members

    // Keep track of the number of members registered so if we want to register more members it'll use new addresses
    function setup_registerNewMembers(uint256 numWatchtowers, uint256 numOperators, StreamDenomination denomination)
        internal
    {
        // Register members with their mock keys. These are Bitcoin x-only public keys.
        uint256 totalMembers = numWatchtowers + numOperators;

        for (uint256 memberIndex = 0; memberIndex < totalMembers; memberIndex++) {
            PublicKeyRegistration[] memory pubKeysRegistration =
                generatePublicKeysRegistration(registeredMembersCounter + memberIndex + 1);
            address user = vm.addr(registeredMembersCounter + memberIndex + 1); // Use a different address for each member
            // First numWatchtowers members are watchtowers, the rest are operators
            Role role = memberIndex < numWatchtowers ? Role.Watchtower : Role.Operator;

            setup_applyToStream(denomination, user, pubKeysRegistration, role);
        }

        registeredMembersCounter += totalMembers;
    }

    function setup_applyToStream(
        StreamDenomination _denomination,
        address _address,
        PublicKeyRegistration[] memory _publicKeysRegistration,
        Role _role
    ) internal {
        uint256 minimumDeposit = registry.getMinimumDeposit(_denomination);
        vm.deal(_address, minimumDeposit);

        vm.prank(_address); // Use a different address for each member
        registry.applyToStream{value: minimumDeposit}(_denomination, _role, _publicKeysRegistration);
    }

    // This function should be used for members that has been already registered. But it won't fail if the member is not registered.
    // It will just apply to the stream with the given denomination and role.
    function setup_applyToStream_MultipleMembers(
        StreamDenomination _denomination,
        uint256 _numWatchtowers,
        uint256 _numOperators,
        uint256 _memberIndexInit
    ) internal {
        uint256 totalMembers = _numWatchtowers + _numOperators;

        for (uint256 i = 0; i < totalMembers; i++) {
            Role role = i < _numWatchtowers ? Role.Watchtower : Role.Operator;
            PublicKeyRegistration[] memory pubKeysRegistration =
                generatePublicKeysRegistration(_memberIndexInit + i + 1);
            setup_applyToStream(_denomination, vm.addr(_memberIndexInit + i + 1), pubKeysRegistration, role);
        }
    }

    function runTestDeployScript() internal {
        // Using the deployment script in tests like in
        // https://github.com/Cyfrin/foundry-smart-contract-lottery-cu/blob/main/test/unit/RaffleTest.t.sol#L38
        DeployScript deployScript = new DeployScript();
        deployScript.run();
        bitcoinManager = deployScript.bitcoinManager();
        registry = CommitteeRegistryHarness(address(deployScript.committeeRegistry()));
        pm = PegManagerHarness(address(deployScript.pegManager()));
        streamManager = StreamManagerHarness(address(deployScript.streamManager()));
        // Set up bridge mock at bridge precompiled address
        bridgeMock = BridgeMock(deployScript.bridgeAddress());
        signatureManager = SignatureManager(deployScript.signatureManager());
    }

    // ========================== Peg In Request ==========================
    // This counter is added to the txId from getPeginRequestTxIn to avoid collisions when doing multiple pegin's
    uint256 internal txIdCounter = 0;

    function getPeginRequestTxIn() internal returns (BtcTxIn memory) {
        return BtcTxIn({
            txId: bytes32(uint256(0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2) + txIdCounter++),
            vout: 1694,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
    }

    function getPeginRequestP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE,
            // TODO this is the value that includes the op_return data inside the taptree
            // It should be put back once the protocol builder is updated
            // scriptPubKey: hex"5120c8c2100e84799661079100ee50ce96bd1db6a1021819042b5b950ef01a4e7f41"
            scriptPubKey: hex"5120228f281f297fd01cd363b9c93f742ba2976c1ec5a6083d9f754cb61e505356c3"
        });
    }

    function getPeginRequestPacket() internal pure returns (uint64) {
        return 0;
    }

    function getPeginRskDestinationAddress() internal pure returns (address) {
        return 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    }

    function getPeginBtcReimbursementPubKey() internal pure returns (bytes32) {
        return 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
    }

    function getPeginRequestOpReturnOut(
        uint64 _packetNumber,
        address _rskDestinationAddress,
        bytes32 _btcReimbursementPubKey
    ) internal pure returns (BtcTxOut memory) {
        bytes memory script = abi.encodePacked(
            OpCodes.OP_RETURN, // (1 byte)
            OpCodes.OP_PUSHBYTES_69, // (1 byte)
            "RSK_PEGIN", // (9 bytes)
            _packetNumber, // (8 bytes)
            _rskDestinationAddress, // (20 bytes)
            _btcReimbursementPubKey // (32 bytes)
        );

        // Return the constructed output
        return BtcTxOut({amount: 0, scriptPubKey: script});
    }

    function getBtcPeginRequestTx() internal returns (BtcTransaction memory) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getPeginRequestTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);
        btcOutputs[0] = getPeginRequestP2TROut();

        Stream memory stream = streamManager.getStream(VALUE);
        uint64 packetNumber = stream.peginPacketPointer;

        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        btcOutputs[1] = getPeginRequestOpReturnOut(packetNumber, rskDestinationAddress, btcReimbursementPubKey);
        return BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: btcInputs,
            outputs: btcOutputs,
            locktime: Constants.LOCKTIME
        });
    }

    function getBtcTxHash(BtcTransaction memory _tx) internal pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxEncoder.encodeTx(_tx));
    }

    // ========================== Peg In Accept ==========================
    function getBtcAcceptPeginTx(BtcTransaction memory _tx) internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getAcceptPeginTxIn(_tx);
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);
        btcOutputs[0] = getAcceptPeginP2TROut();
        btcOutputs[1] = getBtcSpeedUpOut();
        // Locktime
        return BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: btcInputs,
            outputs: btcOutputs,
            locktime: Constants.LOCKTIME
        });
    }

    function getAcceptPeginTxIn(BtcTransaction memory _tx) internal pure returns (BtcTxIn memory) {
        return BtcTxIn({txId: getBtcTxHash(_tx), vout: 0, sequence: Constants.SEQUENCE, scriptSig: hex""});
    }

    function getBtcSpeedUpOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: Constants.SPEED_UP_AMOUNT,
            // TODO we consider the btc reimbursement public key as even
            // this may not be the case in the future and we should change this
            scriptPubKey: BtcScriptParser.getP2WPKHScript(abi.encodePacked(uint8(0x02), BTC_REIMBURSEMENT_PUBKEY))
        });
    }

    function getAcceptPeginP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE - (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT),
            scriptPubKey: hex"51209687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702"
        });
    }

    // ========================== Peg out ==========================
    function createPegoutTx(bytes32 _acceptPeginTxHash, bytes memory _userPubKey, uint64 _amount)
        internal
        pure
        returns (BtcTransaction memory)
    {
        // Input: spend the accept peg-in UTXO
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _acceptPeginTxHash,
            vout: 0, // P2TR output is at index 0
            sequence: 0xfffffffd,
            scriptSig: hex""
        });

        // Outputs
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);

        // user output amount
        uint64 userAmount = _amount - 1000; // Subtract fee
        bytes memory userScriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);

        // pay to user's P2WPKH
        btcOutputs[0] = BtcTxOut({amount: userAmount, scriptPubKey: userScriptPubKey});

        // speedup
        btcOutputs[1] = BtcTxOut({amount: 300, scriptPubKey: userScriptPubKey});

        return BtcTransaction({version: Constants.BTC_TX_VERSION, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function satoshiToWei(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10 ** 10;
    }

    function createBtcTxSPVProof(BtcTransaction memory _btcTransaction) internal pure returns (BtcTxSPVProof memory) {
        BtcTxSPVProof memory btcTxSPVProof = BtcTxSPVProof({
            blockHash: 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9,
            btcTx: _btcTransaction,
            //values obtained from https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs
            merkleBranchPath: 949,
            merkleBranchHashes: new bytes32[](1)
        });
        btcTxSPVProof.merkleBranchHashes[0] = 0x480fd40f2e47eeea8edeef2f7f3e2c680642f748c989ed2e542fe5d28164da51;
        return btcTxSPVProof;
    }

    function setup_multipleRequestAndAcceptPeginFlows(uint256 _numberOfPegins, uint64 _streamId) internal {
        for (uint256 i = 0; i < _numberOfPegins; i++) {
            BtcTransaction memory btcTx = setup_requestPeginFlow();
            setup_acceptPeginFlow(btcTx);

            if (
                _numberOfPegins > Constants.SLOTS_PER_PACKET
                    && (i % Constants.SLOTS_PER_PACKET) == Constants.SLOT_USAGE_THRESHOLD
            ) {
                uint256 memberIndexStart = registry.minCommitteeMembers();
                uint256 memberCount = registry.minCommitteeMembers();
                setup_depositMemberInfo_MultipleMembers(_streamId, memberIndexStart, memberCount);
            }
        }
    }

    function setup_acceptPeginFlow(BtcTransaction memory _tx) public returns (BtcTransaction memory) {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcAcceptPeginTx(_tx);
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Act
        pm.acceptPeginRequest(peginAcceptedTxSPVProof);

        return btcTransaction;
    }

    function setup_requestPeginFlow() public returns (BtcTransaction memory) {
        // Arrange
        BtcTransaction memory btcTransaction = getBtcPeginRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create Pegin struct information
        BtcTxSPVProof memory peginRequestTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Act
        pm.registerPeginRequest(peginRequestTxSPVProof);
        return btcTransaction;
    }

    function setup_requestAndAcceptPeginFlow() public returns (BtcTransaction memory, BtcTransaction memory) {
        BtcTransaction memory peginTx = setup_requestPeginFlow();
        return (peginTx, setup_acceptPeginFlow(peginTx));
    }

    // ========================== Register Pegout Setup ==========================
    struct RegisterPegoutSetup {
        BtcTransaction pegoutTx;
        BtcTxSPVProof pegoutTxSPVProof;
        Stream stream;
        uint64 packetNumber;
        uint64 slotId;
        bytes32 acceptPeginTxHash;
        bytes userPubKey;
        bytes32 expectedTxHash;
    }

    function setup_registerPegoutScenario() public returns (RegisterPegoutSetup memory setup) {
        setup.stream = streamManager.getStream(VALUE);
        setup.packetNumber = 0;
        setup.userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        // peg-in tx hash
        setup.acceptPeginTxHash = 0x30b6a2cae94d89540a99e0dfa39cf88e6de40dca9142810fdce7a95c00faff47;

        // Create a peg-out transaction that spends the accept peg-in UTXO
        setup.pegoutTx = createPegoutTx(setup.acceptPeginTxHash, setup.userPubKey, VALUE);

        setup.slotId = streamManager.setSlotHarness(
            setup.stream.streamId,
            setup.packetNumber,
            hex"00143fd2e14f4b448a071e074e1e1879318447f2a266",
            setup.acceptPeginTxHash,
            VALUE
        );

        // Set the slot state to LOCKED
        streamManager.setSlotStateHarness(setup.stream.streamId, setup.packetNumber, setup.slotId, SlotState.LOCKED);

        // Set up the pegoutTxs mapping
        pm.setPegoutTempInfoHarness(setup.acceptPeginTxHash, setup.userPubKey);
        pm.setStreamPositionHarness(
            setup.acceptPeginTxHash, setup.stream.streamId, setup.packetNumber, setup.slotId, PegStatus.ACCEPTED
        );

        // Create SPV proof for the peg-out transaction
        setup.pegoutTxSPVProof = createBtcTxSPVProof(setup.pegoutTx);

        // Calculate the expected transaction hash
        setup.expectedTxHash = bitcoinManager.getBtcTxHash(setup.pegoutTx);

        return setup;
    }

    function setup_depositMemberInfo(uint64 _streamId, address _memberAddress) internal {
        vm.prank(_memberAddress);
        registry.depositMemberInfoForCommittee(_streamId, COMMITTEE_PUB_KEY);
    }

    // This function is used to deposit member info for multiple members in a committee
    // It will deposit member info for members with indexes from _memberIndexInit to _memberIndexInit + _memberCount - 1
    function setup_depositMemberInfo_MultipleMembers(uint64 _streamId, uint256 _memberIndexInit, uint256 _memberCount)
        internal
    {
        uint256 memberIndexEnd = _memberIndexInit + _memberCount;

        for (uint256 i = _memberIndexInit; i < memberIndexEnd; i++) {
            // Member address is vm.address(memberIndex + 1);
            setup_depositMemberInfo(_streamId, vm.addr(i + 1));
        }
    }

    function setup_pendingCommittee() internal returns (Committee memory expectedCommittee, uint64 streamId) {
        StreamDenomination denomination = StreamDenomination._0_01BTC;
        streamId = 1;
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        uint256 numOperators = registry.minCommitteeMembers() / 2;
        uint256 numWatchtowers = registry.minCommitteeMembers() - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);
        return (setup_getExpectedCommitteeBeforeExpire(), streamId);
    }

    function setup_pendingCommitteeAndExpire() internal returns (Committee memory expectedCommittee, uint64 streamId) {
        (, streamId) = setup_pendingCommittee();
        expectedCommittee = setup_getExpectedCommitteeAfterExpire();
    }

    function setup_completeCommittee() internal returns (Committee memory expectedCommittee, uint64 streamId) {
        (expectedCommittee, streamId) = setup_pendingCommittee();

        setup_depositMemberInfo_MultipleMembers(streamId, 0, registry.minCommitteeMembers());
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY;

        return (expectedCommittee, streamId);
    }

    function setup_completeCommitteeAndNewMembers()
        internal
        returns (Committee memory firstCommittee, Committee memory secondCommittee, uint64 streamId)
    {
        (firstCommittee, streamId) = setup_completeCommittee();

        // Register new members
        uint256 numOperators = registry.minCommitteeMembers() / 2;
        uint256 numWatchtowers = registry.minCommitteeMembers() - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, StreamDenomination(streamId));

        secondCommittee = setup_getExpectedSecondCommittee();
        secondCommittee.aggregatedKey = COMMITTEE_PUB_KEY;

        return (firstCommittee, secondCommittee, streamId);
    }

    function setup_getExpectedSecondCommittee() internal returns (Committee memory) {
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);

        Committee memory committee = Committee({
            aggregatedKey: bytes32(0),
            memberIndexesAndRoles: new CommitteeMember[](registry.minCommitteeMembers()),
            leaderIndex: 0
        });

        committee.memberIndexesAndRoles[0] = CommitteeMember({index: 17, role: Role.Operator});
        committee.memberIndexesAndRoles[1] = CommitteeMember({index: 16, role: Role.Operator});
        committee.memberIndexesAndRoles[2] = CommitteeMember({index: 18, role: Role.Operator});
        committee.memberIndexesAndRoles[3] = CommitteeMember({index: 19, role: Role.Operator});
        committee.memberIndexesAndRoles[4] = CommitteeMember({index: 15, role: Role.Operator});
        committee.memberIndexesAndRoles[5] = CommitteeMember({index: 12, role: Role.Watchtower});
        committee.memberIndexesAndRoles[6] = CommitteeMember({index: 11, role: Role.Watchtower});
        committee.memberIndexesAndRoles[7] = CommitteeMember({index: 13, role: Role.Watchtower});
        committee.memberIndexesAndRoles[8] = CommitteeMember({index: 14, role: Role.Watchtower});
        committee.memberIndexesAndRoles[9] = CommitteeMember({index: 10, role: Role.Watchtower});

        return committee;
    }

    function setup_getExpectedCommitteeBeforeExpire() internal returns (Committee memory) {
        // NOTE: This function is tied to the initial setup of members that it's 0 members
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        Committee memory committee = Committee({
            aggregatedKey: bytes32(0),
            memberIndexesAndRoles: new CommitteeMember[](registry.minCommitteeMembers()),
            leaderIndex: 0
        });

        committee.memberIndexesAndRoles[0] = CommitteeMember({index: 7, role: Role.Operator});
        committee.memberIndexesAndRoles[1] = CommitteeMember({index: 6, role: Role.Operator});
        committee.memberIndexesAndRoles[2] = CommitteeMember({index: 8, role: Role.Operator});
        committee.memberIndexesAndRoles[3] = CommitteeMember({index: 9, role: Role.Operator});
        committee.memberIndexesAndRoles[4] = CommitteeMember({index: 5, role: Role.Operator});
        committee.memberIndexesAndRoles[5] = CommitteeMember({index: 2, role: Role.Watchtower});
        committee.memberIndexesAndRoles[6] = CommitteeMember({index: 1, role: Role.Watchtower});
        committee.memberIndexesAndRoles[7] = CommitteeMember({index: 3, role: Role.Watchtower});
        committee.memberIndexesAndRoles[8] = CommitteeMember({index: 4, role: Role.Watchtower});
        committee.memberIndexesAndRoles[9] = CommitteeMember({index: 0, role: Role.Watchtower});

        return committee;
    }

    function setup_registerMember(uint256 privKey) internal {
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);

        vm.prank(user);
        registry.registerMemberHarness(pubKeysRegistration);
    }

    function setup_getExpectedCommitteeAfterExpire() internal returns (Committee memory) {
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        // Modifying this timeout will change committee member order
        uint256 timeout = 7 days;
        vm.warp(block.timestamp + timeout); // warp time to make committee expired

        // NOTE: member order is tied to the timeout used in setup_pendingCommitteeAndExpire()
        Committee memory committee = Committee({
            aggregatedKey: bytes32(0),
            memberIndexesAndRoles: new CommitteeMember[](registry.minCommitteeMembers()),
            leaderIndex: 0
        });

        committee.memberIndexesAndRoles[0] = CommitteeMember({index: 7, role: Role.Operator});
        committee.memberIndexesAndRoles[1] = CommitteeMember({index: 8, role: Role.Operator});
        committee.memberIndexesAndRoles[2] = CommitteeMember({index: 9, role: Role.Operator});
        committee.memberIndexesAndRoles[3] = CommitteeMember({index: 5, role: Role.Operator});
        committee.memberIndexesAndRoles[4] = CommitteeMember({index: 6, role: Role.Operator});
        committee.memberIndexesAndRoles[5] = CommitteeMember({index: 2, role: Role.Watchtower});
        committee.memberIndexesAndRoles[6] = CommitteeMember({index: 3, role: Role.Watchtower});
        committee.memberIndexesAndRoles[7] = CommitteeMember({index: 4, role: Role.Watchtower});
        committee.memberIndexesAndRoles[8] = CommitteeMember({index: 0, role: Role.Watchtower});
        committee.memberIndexesAndRoles[9] = CommitteeMember({index: 1, role: Role.Watchtower});

        return committee;
    }
}
