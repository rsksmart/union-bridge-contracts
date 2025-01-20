// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {HelperContract} from "test/HelperContract.sol";
import {PegInRequestTxSPVProof} from "src/interfaces/IPegManager.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";

contract TestPegManager is Test, HelperContract {
    function setUp() external {
        setUpPegManager();
    }

    function test_getTemporaryPegInAddress_Success() external view {
        // check that the function returns the correct taproot address
        bytes memory dummyRskAddress = abi.encodePacked(bytes20(0x4C9a9CbFa14106439B0F96a64d9260F3b8947934));
        uint64 value = 100_000; // 0.001 BTC
        bytes memory result = pm.getTemporaryPegInAddress(dummyRskAddress, value);

        console.log("result");
        console.logBytes(result);
    }

    function test_acceptPegInRequest_Success() external {
        // Arrenge
        uint256 blockHeight = 879_500;
        bytes memory blockBytes =
            hex"00600022bd414202c86f2e80aca72283aa584d6ee2b7597b1d6d02000000000000000000f6f5a9ccc718288b2af0c6695fec614550b3a5f4ef4c04d4116faaaa64ece1e0ac0f8967618c02173e6999e2";
        bytes32 blockHash = BtcHelper.hash256(blockBytes);
        // Set Mock Bridge state
        bridgeMock.setHeader(blockHeight, blockBytes);
        bridgeMock.setBtcBlockchainBestChainHeight(int256(blockHeight));
        // Create PegIn struct information
        PegInRequestTxSPVProof memory pegInRequestTxSPVProof = PegInRequestTxSPVProof({
            value: 100_000, // 0.001 BTC
            packetNumber: 0,
            destinationAddress: address(this),
            btcReinburstmentAddress: "1PuJjnF476W3zXfVYmJfGnouzFDAXakkL4",
            // https://www.blockchain.com/explorer/blocks/btc/879500
            blockHash: blockHash,
            blockNumber: blockHeight,
            // https://www.blockchain.com/explorer/transactions/btc/c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
            utxo: "bc1q6w6qghzq5ye7udslwekw4excywv0c5zcvvx4fy",
            txHash: 0xc00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079,
            // Values obtained using https://github.com/rsksmart/pmt-builder
            merkleBranchPath: 4285202432,
            merkleBranchHashes: [
                "3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f",
                "481a71c0478c28b68a698b8e9be317e9a0d9d153b0b2db417a45b5773ef6a0f2",
                "c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079",
                "1780d0b717e2782046036f3a876037b3fe590834aa5da0b9a09b269d29856660",
                "649272353930bb551a61ca491844128dcd33900872bd9387224bbfd3da9906e5",
                "9617e6383b72d518449fc2c5a18cc24d1e1b3a59e7f8dce6dbf7e822275d382b",
                "a07d3b738d7b280b296cd9a11821c375b600c3524849822925f5c11a39878886",
                "9dd03a4e5358ca5c78c1aea47a944dee59a5153e87330c85c218e81f34e46839",
                "8c4a0c760fafa20c98217d482f85f297dcab25facbe8d5eccb3666a75ac7da37",
                "35d4bf31bdcb1dae3fc659536487c492abae0addcdcfe3e9434c0e9b8f552f8c",
                "ae229406e25c7c52450f31b8a106f9cf5e5f8ae688ca7a25408e6bb339251221",
                "8d84f7110e788ec0591feb5c30f83c9bd326a88c2388d6c6ea10b886e360fffe",
                "5f05f1da73fc3498a59a4245e41b52b0a80dbaa3426fbd541c14327c9a362487"
            ]
        });
        // Act
        pm.acceptPegInRequest(pegInRequestTxSPVProof);
        // Assert
    }
}
