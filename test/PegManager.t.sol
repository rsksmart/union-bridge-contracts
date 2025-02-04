// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/helpers/HelperContract.sol";
import {BtcTransaction, PegInRequestTxSPVProof, IPegManager} from "src/interfaces/IPegManager.sol";
import {Slot, SlotState, Stream} from "src/interfaces/IStreamManager.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/IBridge.sol";
import {ProofValidator} from "src/ProofValidator.sol";

contract TestPegManager is Test, HelperContract {
    // Arrenge
    // https://www.blockchain.com/explorer/blocks/btc/879500
    bytes32 internal constant BLOCK_HASH = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
    uint64 internal constant PACKET_NUMBER = 0;
    address internal constant DESTINATION_ADDRESS = 0x7Ac5496aee77c1bA1F0854206A26DdA82A81d6d8;

    bytes32 internal constant BTC_REIMBURSEMENT_ADDRESS =
        0x741976f972e9aa5e226eae26289b794aac9bbe702f378aa64c6104f16b79298c;

    function setUp() external {
        setUpPegManager();
    }

    function test_getTemporaryPegInAddress_Success() external view {
        // Arrenge
        // check that the function returns the correct taproot address
        address dummyRskAddress = 0x4C9a9CbFa14106439B0F96a64d9260F3b8947934;

        // Act
        bytes memory result = pm.getTemporaryPegInAddress(dummyRskAddress, BTC_REIMBURSEMENT_ADDRESS, VALUE);

        console.log("result");
        console.logBytes(result);
    }

    function test_registerPegInRequest_Success() external {
        // Arrenge
        uint64 expectedSlotId = 0;
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
            VALUE,
            PACKET_NUMBER,
            expectedSlotId,
            DESTINATION_ADDRESS,
            BTC_REIMBURSEMENT_ADDRESS,
            btcTransaction.outputs[0].scriptPubKey
        );

        // Act
        pm.registerPegInRequest(pegInRequestTxSPVProof);

        // Assert
        Stream memory stream = pm.getStream(VALUE);
        Slot memory slot = pm.getSlot(stream.streamId, PACKET_NUMBER, expectedSlotId);

        assertEq(slot.pegInTx, getExpectedPegInRequestTxHash(), "Incorrect peg in txHash");
        assertEq(slot.utxo, btcTransaction.outputs[0].scriptPubKey, "Incorrect utxo");
        assertEq(uint256(slot.state), uint256(SlotState.PREPARED), "Incorrect slot state");
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
}
