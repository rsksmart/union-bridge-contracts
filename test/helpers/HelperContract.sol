// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployScript} from "script/deploy/DeployScript.s.sol";
import {BtcTxSPVProof, PegStatus} from "src/PegManager.sol";
import {IPegManager, PegoutTempInfo, StreamPosition} from "src/interfaces/IPegManager.sol";
import {PegManagerHarness} from "test/helpers/PegManagerHarness.sol";
import {StreamManagerHarness} from "test/helpers/StreamManagerHarness.sol";
import {MemberRegistryHarness} from "test/helpers/MemberRegistryHarness.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {Role, CommitteeMember, Committee, MemberRegistrationKeys, UTXO} from "src/CommitteeRegistry.sol";
import {CommunicationData, COMMUNICATION_DATA_CHUNKS} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, Slot} from "src/interfaces/IStreamManager.sol";
import {
    BtcTxIn, BtcTxOut, BtcTransaction, BitcoinSignatureData, PrevoutData
} from "src/interfaces/IBitcoinManager.sol";
import {BitcoinManager} from "src/BitcoinManager.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BtcTxEncoder} from "src/libraries/BtcTxEncoder.sol";
import {BridgeMock} from "./BridgeMock.sol";
import {TestUtils} from "./TestUtils.sol";
import {Constants} from "src/libraries/Constants.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {Stream, SlotState} from "src/interfaces/IStreamManager.sol";
import {CommitteeRegistryHarness} from "./CommitteeRegistryHarness.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console} from "forge-std/console.sol";

abstract contract HelperContract is Test, TestUtils {
    bytes32 internal constant BTC_REIMBURSEMENT_PUBKEY =
        0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;

    uint128 constant COMMITTEE_ID_STREAM_1_COMMITTEE_1 = 118226726889222519722182588745663749063;
    uint128 constant COMMITTEE_ID_STREAM_1_COMMITTEE_2 = 9059004642890852444280677687625412743;
    uint128 constant COMMITTEE_ID_STREAM_1_COMMITTEE_3 = 252028015853910751738154200832734646518;
    // 33-byte compressed public key (0x02 prefix + 32 bytes)

    function COMMITTEE_PUB_KEY() internal pure returns (bytes memory) {
        return
            abi.encodePacked(bytes1(0x02), bytes32(0xd1cfc2049322ff6ba3a88c6e17c6622308f0fb1d2910ffadb309e4116358723d));
    }

    uint256 constant BLOCK_COMMITTEE_1 = 10;
    uint256 constant BLOCK_COMMITTEE_2 = 100000;
    uint256 constant BLOCK_COMMITTEE_3 = 200000;
    StreamDenomination constant SETUP_PENDING_COMMITTEE_DENOMINATION = StreamDenomination._0_01BTC;
    uint64 constant SETUP_PENDING_COMMITTEE_STREAM_ID = 1;

    uint256 constant TAKE_0_TIMEOUT_DEFAULT = 2 hours;
    uint256 constant TAKE_1_TIMEOUT_DEFAULT = 2 hours;

    // Dummy requested roles and streams for the members
    StreamDenomination internal constant DEFAULT_STREAM = StreamDenomination._0_001BTC;
    Role internal constant DEFAULT_ROLE = Role.OPERATOR;

    BitcoinManager internal bitcoinManager;
    BridgeMock internal bridgeMock;
    CommitteeRegistryHarness internal registry;
    MemberRegistryHarness internal memberRegistry;
    PegManagerHarness internal pm;
    SignatureManager internal signatureManager;
    StreamManagerHarness internal streamManager;

    // Arrange
    uint64 internal constant VALUE = 1_000_000; // 0.01 BTC
    uint256 registeredMembersCounter = 0; // Counter to keep track of registered members

    function runTestDeployScript() internal {
        // Using the deployment script in tests like in
        // https://github.com/Cyfrin/foundry-smart-contract-lottery-cu/blob/main/test/unit/RaffleTest.t.sol#L38
        DeployScript deployScript = new DeployScript();
        deployScript.run();
        bitcoinManager = deployScript.bitcoinManager();
        registry = CommitteeRegistryHarness(address(deployScript.committeeRegistry()));
        memberRegistry = MemberRegistryHarness(address(deployScript.memberRegistry()));
        pm = PegManagerHarness(address(deployScript.pegManager()));
        streamManager = StreamManagerHarness(address(deployScript.streamManager()));
        // Set up bridge mock at bridge precompiled address
        bridgeMock = BridgeMock(deployScript.bridgeAddress());
        signatureManager = SignatureManager(deployScript.signatureManager());

        // Set up the MemberRegistryHarness in the CommitteeRegistryHarness
        registry.setMemberRegistryHarness(memberRegistry);
    }

    // ========================== UTXO Helper ==========================

    function generateDefaultUTXO() internal pure returns (UTXO memory) {
        return UTXO({
            txid: 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef,
            outputIndex: 0,
            amount: 50000
        });
    }

    // ========================== Apply to stream ==========================

    // Keep track of the number of members registered so if we want to register more members it'll use new addresses
    function setup_registerNewMembers(uint256 numWatchtowers, uint256 numOperators, StreamDenomination denomination)
        internal
    {
        // Register members with their mock keys. These are Bitcoin x-only public keys.
        uint256 totalMembers = numWatchtowers + numOperators;

        for (uint256 memberIndex = 0; memberIndex < totalMembers; memberIndex++) {
            address user = vm.addr(registeredMembersCounter + memberIndex + 1); // Use a different address for each member
            MemberRegistrationKeys memory memberRegistrationKeys =
                generateRegistrationPublicKeys(uint256(uint160(user))); // Generate public keys based on the address
            // First numWatchtowers members are watchtowers, the rest are operators
            Role role = memberIndex < numWatchtowers ? Role.WATCHTOWER : Role.OPERATOR;

            setup_applyToStream(denomination, user, memberRegistrationKeys, role);
        }

        registeredMembersCounter += totalMembers;
    }

    function setup_applyToStream(
        StreamDenomination _denomination,
        address _address,
        MemberRegistrationKeys memory _publicKeysRegistration,
        Role _role
    ) internal {
        uint256 minimumDeposit = streamManager.getMinimumDeposit(_denomination, _role);
        vm.deal(_address, minimumDeposit);

        vm.prank(_address); // Use a different address for each member
        registry.applyToStream{value: minimumDeposit}(
            _denomination, _role, _publicKeysRegistration, generateDefaultUTXO()
        );
    }

    function setup_applyToStream_MultipleMembers(
        StreamDenomination _denomination,
        CommitteeMember[] memory _committeeMembers
    ) internal {
        uint256 totalMembers = _committeeMembers.length;

        for (uint256 i = 0; i < totalMembers; i++) {
            CommitteeMember memory member = _committeeMembers[i];
            MemberRegistrationKeys memory memberRegistrationKeys =
                generateRegistrationPublicKeys(uint256(uint160(member.memberAddress))); // Generate public keys based on the address
            setup_applyToStream(_denomination, member.memberAddress, memberRegistrationKeys, member.role);
        }
    }

    function getMemberTakePubKey(address _memberAddress) internal returns (bytes32) {
        return generateRegistrationPublicKeys(uint256(uint160(_memberAddress))).takeKey.publicKeyX;
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
            MemberRegistrationKeys memory memberRegistrationKeys =
                generateRegistrationPublicKeys(uint256(uint160(memberAddress))); // Generate public keys based on the address
            setup_applyToStream(_denomination, memberAddress, memberRegistrationKeys, role);
        }
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
            scriptPubKey: BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(BTC_REIMBURSEMENT_PUBKEY))
        });
    }

    function getAcceptPeginP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE - (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT),
            scriptPubKey: hex"51209687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702"
        });
    }

    function satoshiToWei(uint256 _amount) internal pure returns (uint256) {
        return _amount * 10 ** 10;
    }

    function setup_multipleRequestAndAcceptPeginFlows(uint256 _numberOfPegins) internal {
        if (_numberOfPegins > Constants.SLOTS_PER_PACKET) {
            vm.roll(BLOCK_COMMITTEE_2);
            vm.warp(BLOCK_COMMITTEE_2);
        }

        for (uint256 i = 0; i < _numberOfPegins; i++) {
            BtcTransaction memory btcTx = setup_requestPeginFlow();
            setup_acceptPeginFlow(btcTx);

            if (
                _numberOfPegins > Constants.SLOTS_PER_PACKET
                    && (i % Constants.SLOTS_PER_PACKET) == Constants.SLOT_USAGE_THRESHOLD
            ) {
                uint256 memberIndexStart = registry.committeeMemberCount();
                uint256 memberCount = registry.committeeMemberCount();
                setup_depositAggregatedKey_MultipleMembers(
                    COMMITTEE_ID_STREAM_1_COMMITTEE_2, memberIndexStart, memberCount
                );
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
    struct RegisterUserTakeSetup {
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

    function setup_pegout() internal returns (RegisterUserTakeSetup memory setup) {
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

        // Get the correct signature data that matches what tryPegout() will generate
        BitcoinSignatureData memory pegoutSignatureData = bitcoinManager.getPegoutTxData(
            setup.userPubKey,
            setup.acceptPeginTxHash,
            PrevoutData({value: slot.acceptPeginAmount, scriptPubKey: slot.scriptPubKey})
        );

        // Create a peg-out transaction that spends the accept peg-in UTXO
        setup.pegoutTx = pegoutSignatureData.tx;

        // Create SPV proof for the peg-out transaction
        setup.pegoutTxSPVProof = createBtcTxSPVProof(setup.pegoutTx);

        setup.pegoutSignatureHash = pegoutSignatureData.signatureHash;
        setup.pegoutTxHash = pegoutSignatureData.txHash;
        console.log("Pegout tx hash:");
        console.logBytes32(setup.pegoutTxHash);
    }

    function setup_pegFlow() internal returns (RegisterUserTakeSetup memory setup) {
        setup = setup_pegout();
        pm.registerUserTake(setup.pegoutTxSPVProof);

        return setup;
    }

    function setup_multiplePegFlows(uint8 amount) internal returns (RegisterUserTakeSetup[] memory setups) {
        setups = new RegisterUserTakeSetup[](amount);
        for (uint8 i = 0; i < amount; i++) {
            setups[i] = setup_pegFlow();
        }
    }

    function setup_pegoutAndMemberNonces() internal returns (RegisterUserTakeSetup memory setup) {
        setup = setup_pegout();
        setup_addMemberNonce_MultipleMembers(setup.pegoutTxHash, 0, registry.committeeMemberCount());
    }

    function setup_depositAggregatedKey(uint128 _committeeId, address _memberAddress) internal {
        vm.prank(_memberAddress);
        registry.depositAggregatedKey(_committeeId, COMMITTEE_PUB_KEY());
    }

    // This function is used to deposit the aggregated key for multiple members in a committee
    // It will deposit the aggregated key for members with indexes from _memberIndexInit to _memberIndexInit + _memberCount - 1
    function setup_depositAggregatedKey_MultipleMembers(
        uint128 _committeeId,
        uint256 _memberIndexInit,
        uint256 _memberCount
    ) internal {
        uint256 memberIndexEnd = _memberIndexInit + _memberCount;

        for (uint256 i = _memberIndexInit; i < memberIndexEnd; i++) {
            // Member address is vm.address(memberIndex + 1);
            setup_depositAggregatedKey(_committeeId, vm.addr(i + 1));
        }
    }

    function setup_pendingCommittee() internal returns (Committee memory expectedCommittee, uint128 committeeId) {
        StreamDenomination denomination = SETUP_PENDING_COMMITTEE_DENOMINATION;
        vm.warp(BLOCK_COMMITTEE_1);
        vm.roll(BLOCK_COMMITTEE_1);
        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, denomination);
        return (setup_getExpectedCommitteeBeforeExpire(), COMMITTEE_ID_STREAM_1_COMMITTEE_1);
    }

    function setup_pendingCommitteeAndExpire()
        internal
        returns (Committee memory expectedCommittee, uint128 committeeId)
    {
        (, committeeId) = setup_pendingCommittee();
        vm.warp(BLOCK_COMMITTEE_3);
        vm.roll(BLOCK_COMMITTEE_3);
        expectedCommittee = setup_getExpectedCommitteeAfterExpire();
    }

    function setup_completeCommittee() internal returns (Committee memory expectedCommittee, uint128 committeeId) {
        (expectedCommittee, committeeId) = setup_pendingCommittee();

        setup_depositAggregatedKey_MultipleMembers(committeeId, 0, registry.committeeMemberCount());
        expectedCommittee.aggregatedKey = COMMITTEE_PUB_KEY();
        expectedCommittee.isPending = false;
        expectedCommittee.missingData = 0;

        return (expectedCommittee, committeeId);
    }

    function setup_completeCommitteeAndNewMembers()
        internal
        returns (Committee memory firstCommittee, Committee memory secondCommittee, uint128 committeeId)
    {
        (firstCommittee, committeeId) = setup_completeCommittee();

        // Register new members
        vm.warp(BLOCK_COMMITTEE_2);
        vm.roll(BLOCK_COMMITTEE_2);
        uint256 numOperators = registry.committeeMemberCount() / 2;
        uint256 numWatchtowers = registry.committeeMemberCount() - numOperators;
        setup_registerNewMembers(numWatchtowers, numOperators, StreamDenomination(firstCommittee.streamId));

        secondCommittee = setup_getExpectedSecondCommittee();
        secondCommittee.aggregatedKey = COMMITTEE_PUB_KEY();

        return (firstCommittee, secondCommittee, COMMITTEE_ID_STREAM_1_COMMITTEE_2);
    }

    function setup_getExpectedSecondCommittee() internal view returns (Committee memory) {
        Committee memory committee = Committee({
            aggregatedKey: new bytes(0),
            members: new CommitteeMember[](registry.committeeMemberCount()),
            leaderAddress: address(0),
            operatorTakeIndex: 0,
            createdAt: BLOCK_COMMITTEE_2,
            missingData: 10,
            missingCommunicationData: 10,
            isPending: true,
            streamId: SETUP_PENDING_COMMITTEE_STREAM_ID,
            fundingUTXOs: new UTXO[](registry.committeeMemberCount())
        });

        for (uint256 i = 0; i < committee.members.length; i++) {
            committee.fundingUTXOs[i] = generateDefaultUTXO();
        }

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(19 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(16 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(18 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(17 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(15 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(14 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(11 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(13 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(12 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(10 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_getExpectedCommitteeBeforeExpire() internal view returns (Committee memory) {
        // NOTE: This function is tied to the initial setup of members that it's 0 members
        Committee memory committee = Committee({
            aggregatedKey: new bytes(0),
            members: new CommitteeMember[](registry.committeeMemberCount()),
            leaderAddress: address(0),
            operatorTakeIndex: 0,
            createdAt: BLOCK_COMMITTEE_1,
            missingData: 10,
            missingCommunicationData: 10,
            isPending: true,
            streamId: SETUP_PENDING_COMMITTEE_STREAM_ID,
            fundingUTXOs: new UTXO[](registry.committeeMemberCount())
        });

        for (uint256 i = 0; i < committee.members.length; i++) {
            committee.fundingUTXOs[i] = generateDefaultUTXO();
        }

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(6 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(8 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(7 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(5 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(9 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(1 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(3 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(2 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(0 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(4 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_registerMember(uint256 privKey) internal {
        MemberRegistrationKeys memory memberRegistrationKeys = generateRegistrationPublicKeys(privKey);
        address user = vm.addr(privKey);

        memberRegistry.registerMemberHarness(user, memberRegistrationKeys);
    }

    function setup_getExpectedCommitteeAfterExpire() internal view returns (Committee memory) {
        // NOTE: member order is tied to the timeout used in setup_pendingCommitteeAndExpire()
        Committee memory committee = Committee({
            aggregatedKey: new bytes(0),
            members: new CommitteeMember[](registry.committeeMemberCount()),
            leaderAddress: address(0),
            operatorTakeIndex: 0,
            createdAt: BLOCK_COMMITTEE_3,
            missingData: 10,
            missingCommunicationData: 10,
            isPending: true,
            streamId: SETUP_PENDING_COMMITTEE_STREAM_ID,
            fundingUTXOs: new UTXO[](registry.committeeMemberCount())
        });

        for (uint256 i = 0; i < committee.members.length; i++) {
            committee.fundingUTXOs[i] = generateDefaultUTXO();
        }

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(7 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(8 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(6 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(9 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(5 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(2 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(3 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(1 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(4 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(0 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_addMemberNonce(address _memberAddress, bytes32 _txHash, bytes memory _nonce) internal {
        vm.prank(_memberAddress);
        signatureManager.addMemberNonce(_txHash, _nonce);
    }

    function setup_addMemberNonce_MultipleMembers(bytes32 _txHash, uint256 _memberIndexStart, uint256 _memberCount)
        internal
    {
        uint256 memberIndexEnd = _memberIndexStart + _memberCount;
        for (uint256 i = _memberIndexStart; i < memberIndexEnd; i++) {
            // The nonce values are dummy values
            bytes memory nonce =
                hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
            setup_addMemberNonce(vm.addr(i + 1), _txHash, nonce);
        }
    }

    function setup_addMemberSignature(address _memberAddress, bytes32 _pegoutTxHash, bytes32 _signature) internal {
        vm.prank(_memberAddress);
        signatureManager.addMemberSignature(_pegoutTxHash, _signature);
    }

    function setup_addMemberSignature_MultipleMembers(
        bytes32 _pegoutTxHash,
        uint256 _memberIndexStart,
        uint256 _membersCount
    ) internal {
        uint256 memberIndexEnd = _memberIndexStart + _membersCount;
        for (uint256 i = _memberIndexStart; i < memberIndexEnd; i++) {
            // The signarture values are dummy values
            bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            setup_addMemberSignature(vm.addr(i + 1), _pegoutTxHash, signature);
        }
    }

    function setup_operatorTake() internal returns (address operatorAddress, RegisterUserTakeSetup memory setup) {
        // Arrange
        setup = setup_pegoutAndMemberNonces();
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);
        // This depende on how they have been registered. First registered group are the watchtowers
        uint256 firstHonestOpIndex = registry.committeeMemberCount() / 2 + 1;
        operatorAddress = vm.addr(firstHonestOpIndex + 3);

        // Add just 2 signatures for the first and second operators
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxHash, firstHonestOpIndex, 2);

        // Assert
        assertEventOperatorTakeTriggered(setup.pegoutTxHash, setup, operatorAddress, createdAt);

        pm.triggerOperatorTake(setup.pegoutTxHash);
    }

    function assertEventOperatorTakeTriggered(
        bytes32 pegoutTxHash,
        RegisterUserTakeSetup memory setup,
        address operatorAddress,
        uint256 createdAt
    ) internal {
        PegoutTempInfo memory expectedPegoutInfo = PegoutTempInfo({
            userPubKey: setup.userPubKey,
            createdAt: createdAt,
            operatorTakeUpdatedAt: block.timestamp, // Updated when triggerOperatorTake is called
            committeeId: COMMITTEE_ID_STREAM_1_COMMITTEE_1,
            takeOperatorAddress: operatorAddress,
            takeOperatorPubKey: memberRegistry.getMemberTakePubKey(operatorAddress)
        });

        StreamPosition memory expectedStreamPosition = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.OPERATOR_TAKE
        });

        vm.expectEmit(address(pm));
        emit IPegManager.OperatorTakeTriggered(
            pegoutTxHash,
            expectedPegoutInfo,
            expectedStreamPosition,
            block.timestamp,
            block.timestamp + TAKE_1_TIMEOUT_DEFAULT
        );
    }

    // ====== Communication Data Helper Functions ======

    /// @notice Creates communication data chunks for a member using a unique identifier
    /// @param identifier Unique string to generate deterministic chunks
    /// @return chunks Array of 8 bytes32 chunks
    function createCommunicationDataChunks(string memory identifier)
        internal
        pure
        returns (bytes32[COMMUNICATION_DATA_CHUNKS] memory chunks)
    {
        for (uint256 i = 0; i < COMMUNICATION_DATA_CHUNKS; i++) {
            chunks[i] = keccak256(abi.encodePacked(identifier, "chunk", i));
        }
        return chunks;
    }

    /// @notice Creates valid communication data array for a committee member
    /// @param committeeSize Number of members in the committee
    /// @param memberIndex Index of the member depositing data (own slot will be zero)
    /// @return communicationData Array with zeros for own slot, non-zero for others
    function createValidCommunicationData(uint256 committeeSize, uint256 memberIndex)
        internal
        pure
        returns (CommunicationData[] memory communicationData)
    {
        communicationData = new CommunicationData[](committeeSize);

        for (uint256 i = 0; i < committeeSize; i++) {
            if (i != memberIndex) {
                // Other slots - non-zero data
                string memory identifier = string(abi.encodePacked("member", i, "for", memberIndex));
                communicationData[i] = CommunicationData({data: createCommunicationDataChunks(identifier)});
            }
        }

        return communicationData;
    }

    /// @notice Creates minimal communication data for testing with just 1 character per chunk
    /// @param committeeSize Size of the committee
    /// @param memberIndex Index of the member creating the data
    /// @return communicationData Array of communication data with minimal content
    function createMinimalCommunicationData(uint256 committeeSize, uint256 memberIndex)
        internal
        pure
        returns (CommunicationData[] memory communicationData)
    {
        communicationData = new CommunicationData[](committeeSize);

        for (uint256 i = 0; i < committeeSize; i++) {
            if (i != memberIndex) {
                // Other slots - minimal data (just one bit set in first chunk)
                bytes32[COMMUNICATION_DATA_CHUNKS] memory chunks;
                chunks[0] = bytes32(uint256(1)); // Single bit set
                communicationData[i] = CommunicationData({data: chunks});
            }
        }

        return communicationData;
    }

    /// @notice Asserts that two CommunicationData arrays are equal
    /// @param expected Expected communication data array
    /// @param actual Actual communication data array
    /// @param message Error message if assertion fails
    function assertCommunicationDataEqual(
        CommunicationData[] memory expected,
        CommunicationData[] memory actual,
        string memory message
    ) internal pure {
        assertEq(expected.length, actual.length, string(abi.encodePacked(message, ": array lengths differ")));

        for (uint256 i = 0; i < expected.length; i++) {
            for (uint256 j = 0; j < COMMUNICATION_DATA_CHUNKS; j++) {
                assertEq(
                    expected[i].data[j],
                    actual[i].data[j],
                    string(
                        abi.encodePacked(
                            message, ": data differs at index [", Strings.toString(i), "][", Strings.toString(j), "]"
                        )
                    )
                );
            }
        }
    }

    /// @notice Helper to deposit communication data for a specific member
    /// @param streamId Stream ID for the pending committee
    /// @param memberAddress Address of the member depositing data
    /// @param memberIndex Index of the member in the committee (for generating valid data)
    function setup_depositCommunicationData(uint64 streamId, address memberAddress, uint256 memberIndex) internal {
        Committee memory committee = registry.getPendingCommittee(streamId);
        CommunicationData[] memory communicationData =
            createValidCommunicationData(committee.members.length, memberIndex);

        vm.prank(memberAddress);
        registry.depositCommunicationData(streamId, communicationData);
    }

    /// @notice Helper to deposit communication data for multiple members
    /// @param streamId Stream ID for the pending committee
    /// @param startIndex Starting member index
    /// @param count Number of members to deposit data for
    function setup_depositCommunicationData_MultipleMembers(uint64 streamId, uint256 startIndex, uint256 count)
        internal
    {
        for (uint256 i = 0; i < count; i++) {
            uint256 memberIndex = startIndex + i;
            address memberAddress = vm.addr(memberIndex + 1);
            setup_depositCommunicationData(streamId, memberAddress, memberIndex);
        }
    }
}
