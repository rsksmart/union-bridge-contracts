// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {
    PrevoutData,
    BtcTransaction,
    PegInRequestTxSPVProof,
    StreamPosition,
    PegInTempInfo,
    IPegManager
} from "src/interfaces/IPegManager.sol";
import {Slot, SlotState, Packet, Stream, IStreamManager} from "src/interfaces/IStreamManager.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/IBridge.sol";
import {ProofValidator} from "src/ProofValidator.sol";
import {BtcTaprootParser} from "test/libraries/BtcTaprootParser.t.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestPegManager is Test, HelperContract {
    // Arrenge
    // https://www.blockchain.com/explorer/blocks/btc/879500
    bytes32 internal constant BLOCK_HASH = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant RSK_DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;

    bytes32 internal constant BTC_REIMBURSEMENT_PUBKEY =
        0x5d238354a7e74c9e373317053226537dec221c5c775bcca01e806ec358c5c08d;

    function setUp() external {
        runTestDeployScript();
    }

    function test_getTemporaryPegInAddress_Success() external view {
        address dummyRskAddress = 0x4C9a9CbFa14106439B0F96a64d9260F3b8947934;
        string memory tempAddress = "bcrt1ptp8gw3yt9rjavkrlxhwmlm9y5w4c5u6yeeltmupanle76eq4ftrszyjhnn";

        string memory result = pm.getTemporaryPegInAddress(dummyRskAddress, VALUE, BTC_REIMBURSEMENT_PUBKEY);
        assertEq(result, tempAddress, "Incorrect temporary peg in address");
    }

    function test_registerPegInRequest_Success() external {
        // Arrenge
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // Values obtained using https://github.com/rsksmart/pmt-builder
            // TODO fix this values as it's returning -5 in the bridge
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        // TODO set actual mainnet values
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        vm.expectEmit(address(pm));
        // We emit the event we expect to see.
        emit IPegManager.RegisteredPegInRequest(
            pegInRequestTxSPVProof.blockHash,
            getExpectedPegInRequestTxHash(),
            1,
            VALUE,
            PACKET_NUMBER,
            RSK_DESTINATION_ADDRESS,
            BTC_REIMBURSEMENT_PUBKEY,
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        bytes32 txHash = getExpectedPegInRequestTxHash();
        // Registered Peg In
        StreamPosition memory streamPosition = pm.getPegInRequest(txHash);
        assertEq(streamPosition.streamId, 0, "Incorrect streamId registered");
        assertEq(streamPosition.packetNumber, 0, "Incorrect packetNumber registered");
        assertEq(streamPosition.registered, true, "PegIn Request was not registered");
        // Registered Peg In Temp info
        PegInTempInfo memory pegInTempInfo = pm.getPegInTempInfo(txHash);
        assertEq(pegInTempInfo.value, VALUE, "Incorrect peg in temp info value");
        assertEq(
            pegInTempInfo.rskDestinationAddress,
            RSK_DESTINATION_ADDRESS,
            "Incorrect peg in temp info destinationAddress"
        );
        assertEq(
            pegInTempInfo.btcReimbursementPubKey,
            BTC_REIMBURSEMENT_PUBKEY,
            "Incorrect peg in temp info btcReimbursementPubKey"
        );
        assertEq(
            pegInTempInfo.utxoScriptPubKey,
            btcTransaction.outputs[0].scriptPubKey,
            "Incorrect peg in temp info utxo script pub key"
        );
    }

    function test_registerPegInRequest_Revert_AlreadyRegistered() external {
        // Arrenge
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // Values obtained using https://github.com/rsksmart/pmt-builder
            // TODO fix this values as it's returning -5 in the bridge
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](1)
        });
        // TODO set actual mainnet values
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(IPegManager.AlreadyRegisteredPegIn.selector, getExpectedPegInRequestTxHash())
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_NotEnoughConfirmations() external {
        // Arrenge
        int256 actualConfirmations = 0;
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            merkleBranchPath: 1,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        Stream memory stream = pm.getStream(VALUE);
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.NotEnoughConfirmations.selector, actualConfirmations, stream.pegInConfirmations
            )
        );
        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_registerPegInRequest_Revert_BridgeBtcTxInvalidMerkleBranch() external {
        // Arrenge
        BtcTransaction memory btcTransaction = getBtcPegInRequestTx();
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            blockHash: BLOCK_HASH,
            btcTx: btcTransaction,
            // Values obtained using https://github.com/rsksmart/pmt-builder
            merkleBranchPath: 4285202432,
            merkleBranchHashes: new bytes32[](13)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;
        pegInRequestTxSPVProof.merkleBranchHashes[1] =
            0x481a71c0478c28b68a698b8e9be317e9a0d9d153b0b2db417a45b5773ef6a0f2;
        pegInRequestTxSPVProof.merkleBranchHashes[2] =
            0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079;
        pegInRequestTxSPVProof.merkleBranchHashes[3] =
            0x1780d0b717e2782046036f3a876037b3fe590834aa5da0b9a09b269d29856660;
        pegInRequestTxSPVProof.merkleBranchHashes[4] =
            0x649272353930bb551a61ca491844128dcd33900872bd9387224bbfd3da9906e5;
        pegInRequestTxSPVProof.merkleBranchHashes[5] =
            0x9617e6383b72d518449fc2c5a18cc24d1e1b3a59e7f8dce6dbf7e822275d382b;
        pegInRequestTxSPVProof.merkleBranchHashes[6] =
            0xa07d3b738d7b280b296cd9a11821c375b600c3524849822925f5c11a39878886;
        pegInRequestTxSPVProof.merkleBranchHashes[7] =
            0x9dd03a4e5358ca5c78c1aea47a944dee59a5153e87330c85c218e81f34e46839;
        pegInRequestTxSPVProof.merkleBranchHashes[8] =
            0x8c4a0c760fafa20c98217d482f85f297dcab25facbe8d5eccb3666a75ac7da37;
        pegInRequestTxSPVProof.merkleBranchHashes[9] =
            0x35d4bf31bdcb1dae3fc659536487c492abae0addcdcfe3e9434c0e9b8f552f8c;
        pegInRequestTxSPVProof.merkleBranchHashes[10] =
            0xae229406e25c7c52450f31b8a106f9cf5e5f8ae688ca7a25408e6bb339251221;
        pegInRequestTxSPVProof.merkleBranchHashes[11] =
            0x8d84f7110e788ec0591feb5c30f83c9bd326a88c2388d6c6ea10b886e360fffe;
        pegInRequestTxSPVProof.merkleBranchHashes[12] =
            0x5f05f1da73fc3498a59a4245e41b52b0a80dbaa3426fbd541c14327c9a362487;

        // Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                ProofValidator.BridgeBtcTxInvalidMerkleBranch.selector,
                getExpectedPegInRequestTxHash(),
                pegInRequestTxSPVProof.merkleBranchPath,
                pegInRequestTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);
    }

    function test_computePegOutTxHash() external view {
        // Arrange
        bytes32 p2tr_spk = 0x18f69d27d77e37a024c1b4663403c3205443f76609451cd85fce13d4dccc98c7;
        bytes memory usrPubKey = hex"02733ecfb4641477d17f412bc8cb20bbfa429f7b8352977623c04177382843af08";
        PrevoutData[] memory prevoutsData = new PrevoutData[](1);
        prevoutsData[0] = PrevoutData({
            txid: 0xa33c0cab77c7036b7e51ab63945a204c5417f89fcbdb8e3e841779238cca5eff,
            vout: 0,
            value: 10000000,
            scriptPubKey: BtcTaprootParser.getP2TRScriptPubKey(p2tr_spk)
        });

        uint64 amount = 9979999; // 0.0998 BTC - 0.0001 BTC (dust)

        // Act
        (bytes32 result,) = pm.computePegOutTxHash(usrPubKey, prevoutsData, amount, 1);

        // ExpectedHash hash computed externally from a python tool using the same inputs and running on regtest
        // required inputs:
        // - usrPubKey = 02733ecfb4641477d17f412bc8cb20bbfa429f7b8352977623c04177382843af08
        // - prevoutsData = [
        //     {
        //         "txid": "a33c0cab77c7036b7e51ab63945a204c5417f89fcbdb8e3e841779238cca5eff",
        //         "vout": 0,
        //         "value": 10000000,
        //         "scriptPubKey": P2TR script from (hex"0x18f69d27d77e37a024c1b4663403c3205443f76609451cd85fce13d4dccc98c7")
        //     }
        // ]
        // - amount = 999979999; // 0.0998 BTC - 0.0001 BTC (dust)
        // - dust = 1
        bytes32 expectedHash = 0x4c13945bbd5d62034040012df31b72a52cf69340490ec8081bbde5535b7c2374;

        // Assert
        assertEq(result, expectedHash, "Encoded data does not match expectedHash value");
    }

    function test_requestPegOut_Success() external {
        // Arrenge
        bytes32 expectedHash = 0x9addac826ff94bb0277ac41c1aea1588d71d7bb24db52ce56d82a7e266a5b47c;
        bytes memory expectedDigest =
            hex"00000200000000000000234337e863e00e6ff45f167a14f3963bea912bc0d739c2b402d04f376e814ae2e247139cedddd1ee740814e7de2e771c3745091bbb7af21d4122087c8bc17a36a0c6dbc3091625a23fd870bf8d09182484c12fa63a5c29045a431cf445f153e5ad95131bc0b799c0b1af477fb14fcf26a6a9f76079e48bf090acb7e8367bfd0eefa2c948f4d34b1cb0bccb25ebf3a221deb515ba5afd92f3c81d7601457e26e70000000000";

        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";

        bytes32 txId = 0xb24858ade3e5be49ae63facb93524ddf460d0771f093525dae328b6c435516a2;
        bytes memory scriptPubKey = hex"02f519f51e435c20d38af683ea86862f4591ce8cda248077c2d9a72a76b62f32";

        uint64 amount = 10000000; // 0.1 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = pm.getStream(uint64(amount));
        uint64 packetNumber = 0;
        uint64 slotId = 0;

        pm.setSlotHarness(stream.streamId, packetNumber, slotId, SlotState.FILLED, scriptPubKey, txId);

        // Assert
        vm.expectEmit(address(pm));
        emit IPegManager.PegOutRequested(
            usrPubKey, amount, expectedHash, expectedDigest, stream.streamId, packetNumber, slotId
        );

        // Act
        pm.requestPegOut{value: amountInWei}(usrPubKey, false);

        // Assert
        bytes32 result = pm.getPegOutTxHash(keccak256(abi.encodePacked(usrPubKey, amount)));
        assertEq(result, expectedHash, "expected hash doesn't match the pegout computed one");

        // Assert
        Slot memory slot = pm.getSlot(stream.streamId, packetNumber, slotId);
        assertEq(uint64(slot.state), uint64(SlotState.LOCKED), "Slot was not locked");
    }

    function test_requestPegOut_Revert_InvalidPublicKeyLength() external {
        // Arrange
        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b00";

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IPegManager.InvalidPubKeyLength.selector, usrPubKey.length));

        // Act
        pm.requestPegOut(usrPubKey, false);
    }

    function test_requestPegOut_Revert_StreamNotFoundByDenomination() external {
        // Arrange
        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 5;
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.StreamNotFoundByDenomination.selector, amount));

        // Act
        pm.requestPegOut{value: amountInWei}(usrPubKey, false);
    }

    function test_requestPegOut_Revert_NoFilledSlot() external {
        // Arrange
        bytes memory usrPubKey = hex"02d56ad001b55eabf431e602599fcc0d7ed9d676ac93c2be11d0de6e25dd598d8b";
        uint64 amount = 100000; // 0.1 BTC
        uint256 amountInWei = BtcHelper.satoshiToWei(amount);

        Stream memory stream = pm.getStream(uint64(amount));
        uint64 packetNumber = 0;

        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, stream.streamId, packetNumber));

        // Act
        pm.requestPegOut{value: amountInWei}(usrPubKey, false);
    }

    function test_getFirstFilledSlot_Success() external {
        // Arrenge
        pm.setSlotHarness(0, 0, 0, SlotState.FILLED, hex"00", 0);

        // Act
        (Slot memory slot,) = pm.getFirstFilledSlot(0);
        assertEq(uint64(slot.state), uint64(SlotState.FILLED), "Incorrect slot state");
    }

    function test_getFirstFilledSlot_NoFilledSlot() external {
        // Assert
        vm.expectRevert(abi.encodeWithSelector(IStreamManager.NoFilledSlot.selector, 0, 0));

        // Act
        pm.getFirstFilledSlot(0);
    }
}
