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
import {StreamDenomination, Slot} from "src/interfaces/IStreamManager.sol";
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
    Role internal constant DEFAULT_ROLE = Role.OPERATOR;

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
            address user = vm.addr(registeredMembersCounter + memberIndex + 1); // Use a different address for each member
            PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(uint256(uint160(user))); // Generate public keys based on the address
            // First numWatchtowers members are watchtowers, the rest are operators
            Role role = memberIndex < numWatchtowers ? Role.WATCHTOWER : Role.OPERATOR;

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

    function setup_applyToStream_MultipleMembers(
        StreamDenomination _denomination,
        CommitteeMember[] memory _committeeMembers
    ) internal {
        uint256 totalMembers = _committeeMembers.length;

        for (uint256 i = 0; i < totalMembers; i++) {
            CommitteeMember memory member = _committeeMembers[i];
            PublicKeyRegistration[] memory pubKeysRegistration =
                generatePublicKeysRegistration(uint256(uint160(member.memberAddress))); // Generate public keys based on the address
            setup_applyToStream(_denomination, member.memberAddress, pubKeysRegistration, member.role);
        }
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
            Role role = i < _numWatchtowers ? Role.WATCHTOWER : Role.OPERATOR;
            address memberAddress = vm.addr(_memberIndexInit + i + 1);
            PublicKeyRegistration[] memory pubKeysRegistration =
                generatePublicKeysRegistration(uint256(uint160(memberAddress))); // Generate public keys based on the address
            setup_applyToStream(_denomination, memberAddress, pubKeysRegistration, role);
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
            scriptPubKey: hex"51202dda3f54cd468bdf3b43a853018e728ffd6e52a6a49bb5b9355de7225edbcf2f"
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
        pm.acceptPegin(peginAcceptedTxSPVProof);

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
        pm.requestPegin(peginRequestTxSPVProof);
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
        bytes32 pegoutTxHash;
        bytes32 pegoutSignatureHash;
    }

    function setup_pegout() internal returns (RegisterPegoutSetup memory setup) {
        // =========== Request Peg-In & Accept Peg-In ============
        (, BtcTransaction memory acceptPeginTx) = setup_requestAndAcceptPeginFlow();

        // Get the accept peg-in tx hash that will be spent in the peg-out
        setup.acceptPeginTxHash = bitcoinManager.getBtcTxHash(acceptPeginTx);
        setup.stream = streamManager.getStream(VALUE);
        setup.userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        // =================== Request Peg-Out ===================
        uint64 pegoutAmount = VALUE; // Same amount as peg-in
        uint256 pegoutAmountInWei = BtcHelper.satoshiToWei(pegoutAmount);

        // Calculate expected values
        Stream memory stream = streamManager.getStream(pegoutAmount);
        setup.packetNumber = stream.pegoutPacketPointer;
        setup.slotId = stream.pegoutSlotPointer;

        // Request peg-out
        pm.tryPegout{value: pegoutAmountInWei}(setup.userPubKey);

        // Verify slot was locked
        Slot memory slot = streamManager.getSlot(stream.streamId, setup.packetNumber, setup.slotId);
        assertEq(uint256(slot.state), uint256(SlotState.LOCKED), "Slot should be locked after peg-out request");
        assertEq(slot.acceptPeginTx, setup.acceptPeginTxHash, "Slot should reference the correct accept peg-in tx");

        // Create a peg-out transaction that spends the accept peg-in UTXO
        // TODO: Fix this function, it's different that BitcoinManager so it then creates a different pegoutSignatureHash
        setup.pegoutTx = createPegoutTx(setup.acceptPeginTxHash, setup.userPubKey, slot.acceptPeginAmount);

        // Create SPV proof for the peg-out transaction
        setup.pegoutTxSPVProof = createBtcTxSPVProof(setup.pegoutTx);

        // Calculate the expected transaction hash
        // Hardcoded for packet 0, slot 0. This should be fixed when update createPegoutTx
        setup.pegoutSignatureHash = hex"772f88b4a710480e59273515298d2830db5239e54152de486a9a3e6a5adc5c6a";

        setup.pegoutTxHash = bitcoinManager.getBtcTxHash(setup.pegoutTx);
    }

    function setup_pegFlow() internal returns (RegisterPegoutSetup memory setup) {
        setup = setup_pegout();
        pm.registerPegout(setup.pegoutTxSPVProof);

        return setup;
    }

    function setup_multiplePegFlows(uint8 amount) internal returns (RegisterPegoutSetup[] memory setups) {
        setups = new RegisterPegoutSetup[](amount);
        for (uint8 i = 0; i < amount; i++) {
            setups[i] = setup_pegFlow();
        }
    }

    function setup_pegoutAndMemberNonces() internal returns (RegisterPegoutSetup memory setup) {
        setup = setup_pegout();
        setup_addMemberNonce_MultipleMembers(setup.pegoutSignatureHash, 0, registry.minCommitteeMembers());
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
            members: new CommitteeMember[](registry.minCommitteeMembers()),
            leaderAddress: address(0),
            operatorTakeIndex: 0
        });

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(17 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(16 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(18 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(19 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(15 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(12 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(11 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(13 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(14 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(10 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_getExpectedCommitteeBeforeExpire() internal returns (Committee memory) {
        // NOTE: This function is tied to the initial setup of members that it's 0 members
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        Committee memory committee = Committee({
            aggregatedKey: bytes32(0),
            members: new CommitteeMember[](registry.minCommitteeMembers()),
            leaderAddress: address(0),
            operatorTakeIndex: 0
        });

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(7 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(6 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(8 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(9 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(5 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(2 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(1 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(3 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(4 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(0 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_registerMember(uint256 privKey) internal {
        PublicKeyRegistration[] memory pubKeysRegistration = generatePublicKeysRegistration(privKey);
        address user = vm.addr(privKey);

        registry.registerMemberHarness(user, pubKeysRegistration);
    }

    function setup_getExpectedCommitteeAfterExpire() internal returns (Committee memory) {
        vm.warp(BLOCK_TIMESTAMP_FOR_DETERMINISTIC_COMMITTEE);
        // Modifying this timeout will change committee member order
        uint256 timeout = 7 days;
        vm.warp(block.timestamp + timeout); // warp time to make committee expired

        // NOTE: member order is tied to the timeout used in setup_pendingCommitteeAndExpire()
        Committee memory committee = Committee({
            aggregatedKey: bytes32(0),
            members: new CommitteeMember[](registry.minCommitteeMembers()),
            leaderAddress: address(0),
            operatorTakeIndex: 0
        });

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(7 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(8 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(9 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(5 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(6 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(2 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(3 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(4 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(0 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(1 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_addMemberNonce(address _memberAddress, bytes32 _hashToSign, bytes memory _nonce) internal {
        vm.prank(_memberAddress);
        signatureManager.addMemberNonce(_hashToSign, _nonce);
    }

    function setup_addMemberNonce_MultipleMembers(bytes32 _hashToSign, uint256 _memberIndexStart, uint256 _memberCount)
        internal
    {
        uint256 memberIndexEnd = _memberIndexStart + _memberCount;
        for (uint256 i = _memberIndexStart; i < memberIndexEnd; i++) {
            // The nonce values are dummy values
            bytes memory nonce =
                hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
            setup_addMemberNonce(vm.addr(i + 1), _hashToSign, nonce);
        }
    }

    function setup_addMemberSignature(address _memberAddress, bytes32 _hashToSign, bytes32 _signature) internal {
        vm.prank(_memberAddress);
        signatureManager.addMemberSignature(_hashToSign, _signature);
    }

    function setup_addMemberSignature_MultipleMembers(
        bytes32 _hashToSign,
        uint256 _memberIndexStart,
        uint256 _membersCount
    ) internal {
        uint256 memberIndexEnd = _memberIndexStart + _membersCount;
        for (uint256 i = _memberIndexStart; i < memberIndexEnd; i++) {
            // The signarture values are dummy values
            bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            setup_addMemberSignature(vm.addr(i + 1), _hashToSign, signature);
        }
    }
}
