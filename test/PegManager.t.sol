// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/HelperContract.sol";
import {BtcTransaction, PegInRequestTxSPVProof, IPegManager} from "src/interfaces/IPegManager.sol";
import {Slot, SlotState, Stream} from "src/interfaces/IStreamManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE} from "src/interfaces/Bridge.sol";

contract TestPegManager is Test, HelperContract {
    // Arrenge
    uint64 internal constant value = 100_000; // 0.001 BTC
    // https://www.blockchain.com/explorer/blocks/btc/879500
    bytes32 internal constant blockHash = 0x0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9;
    uint256 internal constant packetNumber = 0;
    // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
    // txID 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
    bytes32 internal constant txHash = 0xda7941bdccc1c040046e9b998e78a7cefec97cadc5a2f561a32afa2700598fcb;
    // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
    bytes internal constant rawTx =
        hex"02000000000101d2b336bde0b006f9d9ffca836627e673bb6d6764a3fe2706f4c2c75d78810b369e06000000fdffffff012601000000000000160014d3b4045c40a133ee361f766ceae4d82398fc505803407bf29bfcee5613d2b5ad37c3a2732f3260938f00e7d2d9da5fdf80213088e25d71048c09449e4fbcca8e69cd84a04973d9b3562d114f26b9daffa6bf3929527d4420afd36e561af10735e88f95d9655e5b3f7bc79de0a4781ef99d1e030c0c567422ac0063036f7264510a746578742f706c61696e000d3837393530302e6269746d61706821c0afd36e561af10735e88f95d9655e5b3f7bc79de0a4781ef99d1e030c0c56742200000000";
    BtcTransaction btcTx;
    string internal constant utxo = "bc1q6w6qghzq5ye7udslwekw4excywv0c5zcvvx4fy";
    string internal constant btcReinburstmentAddress = "1PuJjnF476W3zXfVYmJfGnouzFDAXakkL4";

    function setUp() external {
        setUpPegManager();
    }

    function test_getTemporaryPegInAddress_Success() external view {
        // Arrenge
        // check that the function returns the correct taproot address
        bytes memory dummyRskAddress = abi.encodePacked(bytes20(0x4C9a9CbFa14106439B0F96a64d9260F3b8947934));

        // Act
        bytes memory result = pm.getTemporaryPegInAddress(dummyRskAddress, value);

        console.log("result");
        console.logBytes(result);
    }

    function test_acceptPegInRequest_Success() external {
        // Arrenge
        uint256 expectedSlotId = 0;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(10);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            value: value, // 0.001 BTC
            packetNumber: packetNumber,
            destinationAddress: address(this),
            btcReinburstmentAddress: btcReinburstmentAddress,
            blockHash: blockHash,
            utxo: utxo,
            btcTx: btcTx,
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
        emit IPegManager.PrepareTakeTransaction(
            pegInRequestTxSPVProof.blockHash,
            txHash,
            pegInRequestTxSPVProof.value,
            pegInRequestTxSPVProof.packetNumber,
            expectedSlotId,
            pegInRequestTxSPVProof.destinationAddress,
            pegInRequestTxSPVProof.btcReinburstmentAddress,
            pegInRequestTxSPVProof.utxo
        );

        // Act
        pm.acceptPegInRequest(pegInRequestTxSPVProof);

        // Assert
        Stream memory stream = pm.getStream(value);
        Slot memory slot = pm.getSlot(stream.streamId, packetNumber, expectedSlotId);

        assertEq(slot.pegInTx, txHash, "Incorrect peg in txHash");
        assertEq(slot.utxo, utxo, "Incorrect utxo");
        assertEq(uint256(slot.state), uint256(SlotState.PREPARED), "Incorrect slot state");
    }

    function test_acceptPegInRequest_Revert_notEnoughConfirmations() external {
        // Arrenge
        int256 actualConfirmations = 0;
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(actualConfirmations);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            value: value,
            packetNumber: packetNumber,
            destinationAddress: address(this),
            btcReinburstmentAddress: btcReinburstmentAddress,
            blockHash: blockHash,
            utxo: utxo,
            btcTx: btcTx,
            merkleBranchPath: 1,
            merkleBranchHashes: new bytes32[](1)
        });
        pegInRequestTxSPVProof.merkleBranchHashes[0] =
            0x3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f;

        // Assert
        Stream memory stream = pm.getStream(value);
        vm.expectRevert(
            abi.encodeWithSelector(
                IPegManager.notEnoughConfirmations.selector, actualConfirmations, stream.pegInConfirmations
            )
        );
        // Act
        pm.acceptPegInRequest(pegInRequestTxSPVProof);
    }

    function test_acceptPegInRequest_Revert_bridgeBtcTxInvalidMerkleBranch() external {
        // Arrenge
        // Set Mock Bridge state
        bridgeMock.setBtcTransactionConfirmations(BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE);
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            value: value,
            packetNumber: packetNumber,
            destinationAddress: address(this),
            btcReinburstmentAddress: btcReinburstmentAddress,
            blockHash: blockHash,
            utxo: utxo,
            btcTx: btcTx,
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
                IPegManager.bridgeBtcTxInvalidMerkleBranch.selector,
                pegInRequestTxSPVProof.merkleBranchPath,
                pegInRequestTxSPVProof.merkleBranchHashes
            )
        );
        // Act
        pm.acceptPegInRequest(pegInRequestTxSPVProof);
    }
}
