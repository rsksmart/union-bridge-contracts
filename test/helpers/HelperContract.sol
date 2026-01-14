// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployScript} from "script/deploy/DeployScript.s.sol";
import {StreamManagerHarness} from "test/helpers/StreamManagerHarness.sol";
import {MemberRegistryHarness} from "test/helpers/MemberRegistryHarness.sol";
import {PeginManagerHarness} from "test/helpers/PeginManagerHarness.sol";
import {PegoutManagerHarness} from "test/helpers/PegoutManagerHarness.sol";
import {SignatureManager} from "src/SignatureManager.sol";
import {PauseManager} from "src/PauseManager.sol";
import {Role, CommitteeMember, Committee, MemberRegistrationKeys, UTXO} from "src/CommitteeRegistry.sol";
import {CommunicationData, COMMUNICATION_DATA_CHUNKS} from "src/interfaces/ICommitteeRegistry.sol";
import {StreamDenomination, Slot} from "src/interfaces/IStreamManager.sol";
import {
    BtcTxIn, BtcTxOut, BtcTransaction, BitcoinSignatureData, PrevoutData
} from "src/interfaces/IBitcoinManager.sol";
import {BtcTxSPVProof, StreamPosition, PegStatus} from "src/interfaces/IPegCommonTypes.sol";
import {PegoutTempInfo} from "src/interfaces/IPegoutManager.sol";
import {IPegoutManager} from "src/interfaces/IPegoutManager.sol";
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
import {RbtcBridge} from "src/RbtcBridge.sol";

abstract contract HelperContract is Test, TestUtils {
    bytes32 internal constant BTC_REIMBURSEMENT_PUBKEY =
        0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;

    bytes32 internal constant PEGOUT_ID = 0x2752c0d7974fcf16967915fa3d5e005af8d3993980c48145aa591ebcc6117776;

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

    int256 constant BEST_CHAIN_HEIGHT = 1000;

    // Dummy requested roles and streams for the members
    StreamDenomination internal constant DEFAULT_STREAM = StreamDenomination._0_01BTC;
    Role internal constant DEFAULT_ROLE = Role.OPERATOR;

    BitcoinManager internal bitcoinManager;
    BridgeMock internal bridgeMock;
    CommitteeRegistryHarness internal registry;
    MemberRegistryHarness internal memberRegistry;
    SignatureManager internal signatureManager;
    StreamManagerHarness internal streamManager;
    RbtcBridge internal rbtcBridge;
    PeginManagerHarness internal peginManager;
    PegoutManagerHarness internal pegoutManager;
    PauseManager internal pauseManager;

    // Arrange
    uint64 internal constant VALUE = 1_000_000; // 0.01 BTC
    uint256 registeredMembersCounter = 0; // Counter to keep track of registered members
    address globalUserAddress;

    function runTestDeployScript() internal {
        // Using the deployment script in tests like in
        // https://github.com/Cyfrin/foundry-smart-contract-lottery-cu/blob/main/test/unit/RaffleTest.t.sol#L38
        DeployScript deployScript = new DeployScript();
        deployScript.run();
        bitcoinManager = deployScript.bitcoinManager();
        registry = CommitteeRegistryHarness(address(deployScript.committeeRegistry()));
        memberRegistry = MemberRegistryHarness(address(deployScript.memberRegistry()));
        streamManager = StreamManagerHarness(address(deployScript.streamManager()));
        rbtcBridge = RbtcBridge(payable(address(deployScript.rbtcBridge())));
        peginManager = PeginManagerHarness(address(deployScript.peginManager()));
        pegoutManager = PegoutManagerHarness(address(deployScript.pegoutManager()));
        pauseManager = PauseManager(deployScript.pauseManager());
        // Set up bridge mock at bridge precompiled address
        bridgeMock = BridgeMock(deployScript.bridgeAddress());
        signatureManager = SignatureManager(deployScript.signatureManager());

        globalUserAddress = address(this);
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

    /**
     * @notice Registers a batch of new members (watchtowers first, then operators)
     */
    function setup_registerNewMembers(uint256 numWatchtowers, uint256 numOperators, StreamDenomination denomination)
        internal
    {
        uint256 startingMemberIndex = registeredMembersCounter;
        _applyMembersByCounts(denomination, numWatchtowers, numOperators, startingMemberIndex);
        registeredMembersCounter = startingMemberIndex + numWatchtowers + numOperators;
    }

    /**
     * @notice Applies a single address to a stream by sending the minimum deposit and calling the registry.                   Role requested by the member (WATCHTOWER or OPERATOR).
     */
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

    /**
     * @notice Applies an explicit list of committee members to a stream.
     */
    function setup_applyToStream_MultipleMembers(
        StreamDenomination _denomination,
        CommitteeMember[] memory _committeeMembers
    ) internal {
        uint256 totalMembers = _committeeMembers.length;

        for (uint256 memberIndex = 0; memberIndex < totalMembers; memberIndex++) {
            CommitteeMember memory committeeMember = _committeeMembers[memberIndex];
            _applyMemberToStream(_denomination, committeeMember.memberAddress, committeeMember.role);
        }
    }

    function getMemberDisputePubKey(address _memberAddress) internal returns (bytes32) {
        return generateRegistrationPublicKeys(uint256(uint160(_memberAddress))).covenantKey.publicKeyX;
    }

    /**
     * @notice Applies a batch of members determined by counts and a base index.
     * Should be used for members that has been already registered; it won't fail if the member is not registered.
     * It will just apply to the stream with the given denomination and role.
     */
    function setup_applyToStream_MultipleMembers(
        StreamDenomination _denomination,
        uint256 _numWatchtowers,
        uint256 _numOperators,
        uint256 _startingMemberIndex
    ) internal {
        _applyMembersByCounts(_denomination, _numWatchtowers, _numOperators, _startingMemberIndex);
    }

    /**
     * @notice Derives deterministic mock registration keys from an EOA address.
     */
    function _deriveRegistrationKeysFromAddress(address memberAddress)
        internal
        returns (MemberRegistrationKeys memory keys)
    {
        return generateRegistrationPublicKeys(uint256(uint160(memberAddress)));
    }

    /**
     * @notice Applies a single member to a stream with keys derived from their address.
     */
    function _applyMemberToStream(StreamDenomination denomination, address memberAddress, Role memberRole) internal {
        MemberRegistrationKeys memory keys = _deriveRegistrationKeysFromAddress(memberAddress);
        setup_applyToStream(denomination, memberAddress, keys, memberRole);
    }

    /**
     * @notice Returns a deterministic address for a given position, based on a starting index.
     */
    function _addressForIndex(uint256 startingMemberIndex, uint256 memberOffset)
        internal
        pure
        returns (address memberAddress)
    {
        // +1 to avoid returning address(0) at offset 0
        return vm.addr(startingMemberIndex + memberOffset + 1);
    }

    /**
     * @notice Computes the role for a member position in a watchtower-first layout.
     */
    function _roleForMemberIndex(uint256 memberIndex, uint256 numWatchtowers)
        internal
        pure
        returns (Role roleForPosition)
    {
        return memberIndex < numWatchtowers ? Role.WATCHTOWER : Role.OPERATOR;
    }

    /**
     * @notice Shared implementation used by the count-based entry points.
     */
    function _applyMembersByCounts(
        StreamDenomination denomination,
        uint256 numWatchtowers,
        uint256 numOperators,
        uint256 startingMemberIndex
    ) internal {
        uint256 totalMembers = numWatchtowers + numOperators;
        for (uint256 memberIndex = 0; memberIndex < totalMembers; memberIndex++) {
            Role roleForPosition = _roleForMemberIndex(memberIndex, numWatchtowers);
            address memberAddress = _addressForIndex(startingMemberIndex, memberIndex);
            _applyMemberToStream(denomination, memberAddress, roleForPosition);
        }
    }

    // ========================== Peg In Request ==========================
    // This counter is added to the txId from getRequestPeginTxIn to avoid collisions when doing multiple pegin's
    uint256 internal txIdCounter = 0;

    function getRequestPeginTxIn() internal returns (BtcTxIn memory) {
        return BtcTxIn({
            txId: bytes32(uint256(0x360b81785dc7c2f40627fea364676dbb73e6276683caffd9f906b0e0bd36b3d2) + txIdCounter++),
            vout: 1694,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
    }

    function getRequestPeginP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: VALUE,
            scriptPubKey: hex"5120705364e5015f051b3c85957d8e2c581c17318b50156a68c333739720d388ddfc"
        });
    }

    function getRequestPeginPacket() internal pure returns (uint64) {
        return 0;
    }

    function getPeginRskDestinationAddress() internal pure returns (address) {
        return 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;
    }

    function getPeginBtcReimbursementPubKey() internal pure returns (bytes32) {
        return 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
    }

    function getRequestPeginOpReturnOut(
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

    function getRequestPeginEnablerOut() internal view returns (BtcTxOut memory) {
        // Get committee members and dispute keys
        Stream memory stream = streamManager.getStream(VALUE);
        uint128 committeeId = streamManager.getCommitteeId(stream.streamId, stream.peginPacketPointer);

        bytes32[] memory disputeKeys = registry.getCommitteeDisputeKeys(committeeId);

        // Get the enabler output script using the BitcoinManager
        bytes memory enablerScript = bitcoinManager.getEnablerOutputP2TRScriptPub(COMMITTEE_PUB_KEY(), disputeKeys);

        return BtcTxOut({amount: Constants.ENABLER_AMOUNT, scriptPubKey: enablerScript});
    }

    function getBtcRequestPeginTx() internal returns (BtcTransaction memory, uint64 slotId) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = getRequestPeginTxIn();
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](Constants.REQUEST_PEGIN_OUTPUT_COUNT);
        btcOutputs[0] = getRequestPeginP2TROut();

        Stream memory stream = streamManager.getStream(VALUE);
        uint64 packetNumber = stream.peginPacketPointer;
        slotId = streamManager.getPacketSlotsLength(stream.streamId, packetNumber);

        address rskDestinationAddress = getPeginRskDestinationAddress();
        bytes32 btcReimbursementPubKey = getPeginBtcReimbursementPubKey();
        btcOutputs[1] = getRequestPeginOpReturnOut(packetNumber, rskDestinationAddress, btcReimbursementPubKey);
        btcOutputs[2] = getRequestPeginEnablerOut();

        return (
            BtcTransaction({
                version: Constants.BTC_TX_VERSION,
                inputs: btcInputs,
                outputs: btcOutputs,
                locktime: Constants.LOCKTIME
            }),
            slotId
        );
    }

    function getBtcTxid(BtcTransaction memory _tx) internal pure returns (bytes32) {
        return BtcHelper.hash256(BtcTxEncoder.encodeTx(_tx));
    }

    // ========================== Peg In Accept ==========================
    function getBtcAcceptPeginTx(BtcTransaction memory _tx) internal view returns (BtcTransaction memory) {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](2);
        btcInputs[0] = getAcceptPeginTxIn(_tx);
        btcInputs[1] = getAcceptPeginEnablerTxIn(_tx);
        // Output
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](Constants.ACCEPT_PEGIN_OUTPUT_COUNT);
        btcOutputs[0] = getAcceptPeginP2TROut();
        btcOutputs[1] = getAcceptPeginEnablerOut(_tx);
        btcOutputs[2] = getUserSpeedUpOut();
        // Locktime
        return BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: btcInputs,
            outputs: btcOutputs,
            locktime: Constants.LOCKTIME
        });
    }

    function getAcceptPeginTxIn(BtcTransaction memory _tx) internal pure returns (BtcTxIn memory) {
        return BtcTxIn({txId: getBtcTxid(_tx), vout: 0, sequence: Constants.SEQUENCE, scriptSig: hex""});
    }

    function getAcceptPeginEnablerTxIn(BtcTransaction memory _tx) internal pure returns (BtcTxIn memory) {
        return BtcTxIn({
            txId: getBtcTxid(_tx),
            vout: Constants.REQUEST_PEGIN_VOUT_ENABLER,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
    }

    function getUserSpeedUpOut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            amount: Constants.SPEED_UP_AMOUNT,
            // TODO we consider the btc reimbursement public key as even
            // this may not be the case in the future and we should change this
            scriptPubKey: BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(BTC_REIMBURSEMENT_PUBKEY))
        });
    }

    function getAcceptPeginP2TROut() internal pure returns (BtcTxOut memory) {
        return BtcTxOut({
            // we subtract the fee, speed up amount from the value
            // the enabler amount cancels out between the input and the output
            amount: VALUE - (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT),
            scriptPubKey: hex"51209687ca13c4fb3fa3ba05c2f9119dda026bfe66f0098dcf9b896a98ecb2e96702"
        });
    }

    function getAcceptPeginEnablerOut(BtcTransaction memory _requestTx) internal view returns (BtcTxOut memory) {
        // Extract packet number from the request pegin transaction's OP_RETURN output
        (uint64 packetNumber,,) =
            bitcoinManager.getPeginOpReturnData(_requestTx.outputs[Constants.REQUEST_PEGIN_VOUT_OP_RETURN]);

        uint128 committeeId = streamManager.getCommitteeId(uint64(DEFAULT_STREAM), packetNumber);
        bytes32[] memory disputeKeys = registry.getCommitteeDisputeKeys(committeeId);
        bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), packetNumber);
        bytes memory enablerScript = bitcoinManager.getEnablerOutputP2TRScriptPub(committeePubKey, disputeKeys);

        return BtcTxOut({amount: Constants.ENABLER_AMOUNT, scriptPubKey: enablerScript});
    }

    // ========================== User Reimbursement ==========================
    function getBtcUserReimbursementTx(bytes32 _requestPeginTxid) internal pure returns (BtcTransaction memory) {
        return createBtcUserReimbursementTx(_requestPeginTxid, VALUE, BTC_REIMBURSEMENT_PUBKEY);
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
            (BtcTransaction memory btcTx,) = setup_requestPeginFlow();
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
        bridgeMock.setBtcBlockchainBestChainHeight(BEST_CHAIN_HEIGHT);
        bridgeMock.setBtcTransactionConfirmations(CONFIRMATIONS);
        // Create Pegin accepted tx struct information
        BtcTxSPVProof memory peginAcceptedTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Act
        peginManager.acceptPegin(peginAcceptedTxSPVProof);

        bridgeMock.setBtcBlockchainBestChainHeight(BEST_CHAIN_HEIGHT + 1);

        return btcTransaction;
    }

    function setup_requestPeginFlow() public returns (BtcTransaction memory btcTransaction, uint64 slotId) {
        // Arrange
        (btcTransaction, slotId) = getBtcRequestPeginTx();
        Stream memory stream = streamManager.getStream(VALUE);

        // Set Mock Bridge state
        bridgeMock.setBtcBlockchainBestChainHeight(BEST_CHAIN_HEIGHT);
        bridgeMock.setBtcTransactionConfirmations(CONFIRMATIONS);
        // Create Pegin struct information
        BtcTxSPVProof memory requestPeginTxSPVProof = createBtcTxSPVProof(btcTransaction);

        // Act
        peginManager.requestPegin(requestPeginTxSPVProof);

        // Update the best chain for timelock verifications
        bridgeMock.setBtcBlockchainBestChainHeight(
            BEST_CHAIN_HEIGHT + int256(uint256(stream.timelockSettings.requestPeginTimelock))
        );
        // Assert
        Slot memory slot = streamManager.getSlot(stream.streamId, stream.peginPacketPointer, slotId);
        assertEq(uint256(slot.state), uint256(SlotState.RESERVED), "Slot state should be RESERVED after pegin request");
    }

    function setup_requestAndAcceptPeginFlow(uint128 _committeeId)
        public
        returns (BtcTransaction memory, BtcTransaction memory)
    {
        (BtcTransaction memory peginTx, uint64 peginSlotId) = setup_requestPeginFlow();
        BtcTransaction memory acceptPeginTx = setup_acceptPeginFlow(peginTx);
        bytes32 acceptPeginTxid = bitcoinManager.getBtcTxid(acceptPeginTx);

        // This cover all operators in the committee
        setup_addOperatorTakeTxids_MultipleOperators(
            acceptPeginTxid, _committeeId, uint32(peginSlotId), registry.committeeMemberCount()
        );

        return (peginTx, acceptPeginTx);
    }

    // ========================== Register Pegout Setup ==========================
    struct RegisterUserTakeSetup {
        BtcTransaction pegoutTx;
        BtcTxSPVProof pegoutTxSPVProof;
        BtcTxSPVProof advanceFundsSPV;
        BtcTxSPVProof reimbursementKickoffSPV;
        BtcTxSPVProof operatorTakeSPV;
        BtcTxSPVProof challengeSPV;
        BtcTxSPVProof inputRevealedSPV;
        Stream stream;
        uint64 packetNumber;
        uint64 slotId;
        bytes32 acceptPeginTxid;
        bytes userPubKey;
        bytes32 pegoutTxid;
        bytes32 pegoutSignatureHash;
        bytes32 pegoutId;
    }

    function setup_pegout() internal returns (RegisterUserTakeSetup memory setup) {
        // =========== Request Peg-In & Accept Peg-In ============
        (, BtcTransaction memory acceptPeginTx) = setup_requestAndAcceptPeginFlow(COMMITTEE_ID_STREAM_1_COMMITTEE_1);

        // Get the accept peg-in tx id that will be spent in the peg-out
        setup.acceptPeginTxid = bitcoinManager.getBtcTxid(acceptPeginTx);
        setup.stream = streamManager.getStream(VALUE);
        setup.userPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        // =================== Request Peg-Out ===================
        uint64 pegoutAmount = VALUE; // Same amount as peg-in
        uint256 pegoutAmountInWei = BtcHelper.satoshiToWei(pegoutAmount);

        // Calculate expected values
        Stream memory stream = streamManager.getStream(pegoutAmount);
        setup.packetNumber = stream.pegoutPacketPointer;
        setup.slotId = stream.pegoutSlotPointer;

        // Set up mock to allow burning this amount
        // Add capacity to support multiple pegout calls in sequence
        bridgeMock.setWeisTransferredToUnionBridge(pegoutAmountInWei);

        // Request peg-out
        vm.prank(globalUserAddress);
        pegoutManager.tryPegout{value: pegoutAmountInWei}(setup.userPubKey);

        // Verify slot was locked
        Slot memory slot = streamManager.getSlot(stream.streamId, setup.packetNumber, setup.slotId);
        assertEq(uint256(slot.state), uint256(SlotState.LOCKED), "Slot should be locked after peg-out request");
        assertEq(slot.acceptPeginTx, setup.acceptPeginTxid, "Slot should reference the correct accept peg-in tx");

        // Prepare prevout data for both inputs: taptree and enabler outputs
        // Read both from slot (matching production code in _preparePegoutPrevoutDatas)
        PrevoutData[] memory prevoutDatas = new PrevoutData[](2);
        prevoutDatas[0] = PrevoutData({value: slot.acceptPeginAmount, scriptPubKey: slot.scriptPubKey});
        prevoutDatas[1] = PrevoutData({value: Constants.ENABLER_AMOUNT, scriptPubKey: slot.enablerScriptPubKey});

        BitcoinSignatureData memory pegoutSignatureData =
            bitcoinManager.getPegoutTxData(setup.userPubKey, setup.acceptPeginTxid, prevoutDatas);

        // Create a peg-out transaction that spends the accept peg-in UTXO
        setup.pegoutTx = pegoutSignatureData.tx;

        // Create SPV proof for the peg-out transaction
        setup.pegoutTxSPVProof = createBtcTxSPVProof(setup.pegoutTx);

        setup.pegoutSignatureHash = pegoutSignatureData.signatureHash;
        setup.pegoutTxid = pegoutSignatureData.txid;

        setup.pegoutId = keccak256(
            abi.encode(
                stream.streamId,
                setup.packetNumber,
                setup.slotId,
                globalUserAddress,
                BtcHelper.hash256(bridgeMock.getBtcBlockchainBestBlockHeader())
            )
        );

        setup.advanceFundsSPV = createBtcTxSPVProof(createAdvanceFundsTx(setup.userPubKey, VALUE, setup.pegoutId));
    }

    function setup_pegFlow() internal returns (RegisterUserTakeSetup memory setup) {
        setup = setup_pegout();
        pegoutManager.registerUserTake(setup.pegoutTxSPVProof);

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
        setup_addMemberNonce_MultipleMembers(setup.pegoutTxid, 0, registry.committeeMemberCount());
    }

    function setup_addOperatorTakeTxids_MultipleOperators(
        bytes32 _acceptPeginTxid,
        uint128 _committeeId,
        uint32 _slotId,
        uint256 _operatorCount
    ) internal {
        CommitteeMember[] memory members = registry.getCommitteeMembers(_committeeId);
        uint256 operatorAdded = 0;
        for (uint256 i = 0; i < members.length && operatorAdded < _operatorCount; i++) {
            if (members[i].role == Role.OPERATOR) {
                (BtcTransaction memory opTakeTx,) =
                    setup_getOperatorTakeData(_acceptPeginTxid, members[i].memberAddress, _slotId);

                bytes32 takeTxid = bitcoinManager.getBtcTxid(opTakeTx);
                bytes32 wonTxid = hex"feedfacefeedfacefeedfacefeedfacefeedfacefeedfacefeedfacefeedface";

                setup_addOperatorTakeTxids(members[i].memberAddress, _acceptPeginTxid, takeTxid, wonTxid);
                operatorAdded++;
            }
        }
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

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(18 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(15 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(19 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(16 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(17 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(13 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(10 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(14 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(11 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(12 + 1), role: Role.WATCHTOWER});

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

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(8 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(5 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(9 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(6 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(7 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(3 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(0 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(4 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(1 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(2 + 1), role: Role.WATCHTOWER});

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

        committee.members[0] = CommitteeMember({memberAddress: vm.addr(8 + 1), role: Role.OPERATOR});
        committee.members[1] = CommitteeMember({memberAddress: vm.addr(5 + 1), role: Role.OPERATOR});
        committee.members[2] = CommitteeMember({memberAddress: vm.addr(9 + 1), role: Role.OPERATOR});
        committee.members[3] = CommitteeMember({memberAddress: vm.addr(6 + 1), role: Role.OPERATOR});
        committee.members[4] = CommitteeMember({memberAddress: vm.addr(7 + 1), role: Role.OPERATOR});
        committee.members[5] = CommitteeMember({memberAddress: vm.addr(3 + 1), role: Role.WATCHTOWER});
        committee.members[6] = CommitteeMember({memberAddress: vm.addr(0 + 1), role: Role.WATCHTOWER});
        committee.members[7] = CommitteeMember({memberAddress: vm.addr(4 + 1), role: Role.WATCHTOWER});
        committee.members[8] = CommitteeMember({memberAddress: vm.addr(1 + 1), role: Role.WATCHTOWER});
        committee.members[9] = CommitteeMember({memberAddress: vm.addr(2 + 1), role: Role.WATCHTOWER});

        return committee;
    }

    function setup_addMemberNonce(address _memberAddress, bytes32 _txid, bytes memory _nonce) internal {
        vm.prank(_memberAddress);
        signatureManager.addMemberNonce(_txid, _nonce);
    }

    function setup_addOperatorTakeTxids(
        address _memberAddress,
        bytes32 _acceptPeginTxid,
        bytes32 _takeTxid,
        bytes32 _wonTxid
    ) internal {
        vm.prank(_memberAddress);
        signatureManager.addOperatorTakeTxids(_acceptPeginTxid, _takeTxid, _wonTxid);
    }

    function setup_addMemberNonce_MultipleMembers(bytes32 _txid, uint256 _memberIndexStart, uint256 _memberCount)
        internal
    {
        uint256 memberIndexEnd = _memberIndexStart + _memberCount;
        for (uint256 i = _memberIndexStart; i < memberIndexEnd; i++) {
            // The nonce values are dummy values
            bytes memory nonce =
                hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a00000";
            setup_addMemberNonce(vm.addr(i + 1), _txid, nonce);
        }
    }

    function setup_addMemberSignature(address _memberAddress, bytes32 _pegoutTxid, bytes32 _signature) internal {
        vm.prank(_memberAddress);
        signatureManager.addMemberSignature(_pegoutTxid, _signature);
    }

    function setup_addMemberSignature_MultipleMembers(
        bytes32 _pegoutTxid,
        uint256 _memberIndexStart,
        uint256 _membersCount
    ) internal {
        uint256 memberIndexEnd = _memberIndexStart + _membersCount;
        for (uint256 i = _memberIndexStart; i < memberIndexEnd; i++) {
            // The signarture values are dummy values
            bytes32 signature = hex"f8c0b1a2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0";
            setup_addMemberSignature(vm.addr(i + 1), _pegoutTxid, signature);
        }
    }

    function setup_advanceFunds() internal returns (address operatorAddress, RegisterUserTakeSetup memory setup) {
        // Arrange
        setup = setup_pegoutAndMemberNonces();
        uint256 createdAt = block.timestamp;
        // Expire TAKE_0
        vm.warp(createdAt + TAKE_0_TIMEOUT_DEFAULT + 1);
        // This depende on how they have been registered. First registered group are the watchtowers
        uint256 firstHonestOpIndex = registry.committeeMemberCount() / 2 + 1;

        // Add just 2 signatures for the first and second operators (by registration order)
        setup_addMemberSignature_MultipleMembers(setup.pegoutTxid, firstHonestOpIndex, 2);

        // Trigger operator take and get the actual operator address selected by the contract
        pegoutManager.triggerOperatorTake(setup.pegoutTxid);

        // Get the actual operator that was selected from the contract state
        PegoutTempInfo memory actualPegoutInfo = pegoutManager.getPegoutTempInfo(setup.acceptPeginTxid);
        operatorAddress = actualPegoutInfo.takeOperatorAddress;

        BtcTransaction memory opTakeTx;
        (opTakeTx, setup.reimbursementKickoffSPV) =
            setup_getOperatorTakeData(setup.acceptPeginTxid, operatorAddress, uint32(setup.slotId));
        setup.operatorTakeSPV = createBtcTxSPVProof(opTakeTx);

        bytes32 reimbursementTxid = bitcoinManager.getBtcTxid(setup.reimbursementKickoffSPV.btcTx);
        bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), setup.packetNumber);

        setup.challengeSPV = createBtcTxSPVProof(createChallengeTx(reimbursementTxid, committeePubKey));
    }

    function setup_getOperatorTakeData(bytes32 _acceptPeginTxid, address _operatorAddress, uint32 _slotId)
        internal
        returns (BtcTransaction memory opTakeTx, BtcTxSPVProof memory reimbursementKickoffSPV)
    {
        bytes32 operatorPubKey = getMemberDisputePubKey(_operatorAddress);
        bytes memory operatorDisputePubKeyCompact = BtcHelper.pubKeyXonlyToCompact(operatorPubKey);

        BtcTransaction memory reimbursementKickoffTx =
            createReimbursementKickoffTx(operatorDisputePubKeyCompact, _slotId);

        reimbursementKickoffSPV = createBtcTxSPVProof(reimbursementKickoffTx);

        bytes32 reimbursementTxid = bitcoinManager.getBtcTxid(reimbursementKickoffTx);

        opTakeTx = createOperatorTakeTx(_acceptPeginTxid, reimbursementTxid, operatorDisputePubKeyCompact, VALUE);
    }

    function setup_operatorTake() internal returns (address operatorAddress, RegisterUserTakeSetup memory setup) {
        (operatorAddress, setup) = setup_reimbursementKickoff();

        vm.prank(operatorAddress);
        pegoutManager.registerReimbursementKickoff(setup.acceptPeginTxid, setup.reimbursementKickoffSPV);
    }

    function setup_challenge() internal returns (address operatorAddress, RegisterUserTakeSetup memory setup) {
        (operatorAddress, setup) = setup_operatorTake();

        bytes memory committeePubKey = streamManager.getCommitteePubKey(uint64(DEFAULT_STREAM), setup.packetNumber);
        bytes32 challengeTxid = bitcoinManager.getBtcTxid(setup.challengeSPV.btcTx);
        setup.inputRevealedSPV = createBtcTxSPVProof(createRevealTx(challengeTxid, committeePubKey));

        vm.prank(operatorAddress);
        pegoutManager.registerChallenge(setup.acceptPeginTxid, setup.challengeSPV);
    }

    function setup_reimbursementKickoff()
        internal
        returns (address operatorAddress, RegisterUserTakeSetup memory setup)
    {
        bridgeMock.setBtcBlockchainBestChainHeight(BEST_CHAIN_HEIGHT);
        (operatorAddress, setup) = setup_advanceFunds();

        vm.prank(operatorAddress);
        pegoutManager.registerAdvanceFunds(setup.acceptPeginTxid, setup.advanceFundsSPV);

        bridgeMock.setBtcBlockchainBestChainHeight(BEST_CHAIN_HEIGHT + 1);
    }

    function assertStreamPositionAndSlotStateByRequestPegin(
        bytes32 _requestPeginTxid,
        uint64 _streamId,
        uint64 _packetNumber,
        uint64 _slotId,
        SlotState _expectedSlotState
    ) internal view {
        // Verify each request gets correct slotId
        StreamPosition memory streamPosition = peginManager.getStreamPositionByRequestPegin(_requestPeginTxid);
        assertEq(streamPosition.streamId, _streamId, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, _packetNumber, "Incorrect packetNumber registered");
        assertEq(streamPosition.slotId, _slotId, "Incorrect slotId registered");

        // Verify slot state
        Slot memory reservedSlot =
            streamManager.getSlot(streamPosition.streamId, streamPosition.packetNumber, streamPosition.slotId);
        assertEq(uint256(reservedSlot.state), uint256(_expectedSlotState), "Incorrect slot state registered");
        assertEq(reservedSlot.slotId, streamPosition.slotId, "Slot ID should match StreamPosition");
    }

    function assertEventOperatorTakeTriggered(
        bytes32 pegoutTxid,
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
            operatorDisputePubKey: getMemberDisputePubKey(operatorAddress),
            pegoutId: setup.pegoutId,
            advanceFundsBlockNumber: 0,
            reimbursementKickoffTxid: bytes32(0),
            challengeTxid: bytes32(0),
            revealTxid: bytes32(0)
        });

        StreamPosition memory expectedStreamPosition = StreamPosition({
            streamId: setup.stream.streamId,
            packetNumber: setup.packetNumber,
            slotId: setup.slotId,
            pegStatus: PegStatus.OP_SELECTED
        });

        vm.expectEmit(address(pegoutManager));
        emit IPegoutManager.OperatorTakeTriggered(
            pegoutTxid,
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

    function pauseContracts() internal {
        vm.prank(pauseManager.owner());
        pauseManager.pause();
    }

    function pauseAndUnpauseContracts() internal {
        vm.startPrank(pauseManager.owner());
        pauseManager.pause();
        pauseManager.unpause();
        vm.stopPrank();
    }

    function calculatePegoutId(uint64 _streamId, uint64 _packetNumber, uint64 _slotId, address _userAddress)
        internal
        pure
        returns (bytes32)
    {
        // Calculate expected PegoutId using mock block hash
        bytes32 mockBlockHash = 0x0000000000000000000049b460f18614380a01b8709d2c3a8ddf451d08d862b8;
        return keccak256(abi.encode(_streamId, _packetNumber, _slotId, _userAddress, mockBlockHash));
    }

    /// @notice Gets the dispute key 33 bytes compact format for a member by address
    /// @param _memberAddress The address of the member
    /// @return disputeKey The dispute key 33 bytes compact format for the member
    function getDisputeKeyByAddress(address _memberAddress) internal view returns (bytes memory disputeKey) {
        bytes32 operatorXOnlyPubKey = memberRegistry.getMemberPublicKeys(_memberAddress).covenantPubKey;
        disputeKey = BtcHelper.pubKeyXonlyToCompact(operatorXOnlyPubKey);
        return disputeKey;
    }
}
