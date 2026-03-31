// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

// GENERATED FILE - do not edit manually.
// Run: ./examples/union/scripts/run-example.sh solidity_txs
// from the rust-bitvmx-client directory.

import {BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {CompactPubKey} from "src/interfaces/IMemberRegistry.sol";

contract BitVMXCompatibilityData {
    // All transactions below correspond to slot index 0 and operator index 1.
    // These are fixed for testing purposes.

    bytes constant COMMITTEE_AGGREGATED_KEY = hex"038889df91446abcdf3f64071c8d75355abcd7f674d883d7f5604a73cb47124e15";

    bytes constant USER_COMPRESSED_PUBKEY = hex"02a5a32f1e36335d6c3233bb36c4c5cdb51153a1698399ea0691be6e01a8580573";

    bytes32 constant PEGOUT_ID = 0x0000000000000000000000000000000000000000000000000000000000000001;

    uint256 constant OPERATOR_INDEX = 1;
    uint8 constant OPERATOR_COUNT = 2;
    uint8 constant WATCHTOWER_COUNT = 2;

    bytes32 constant EXPECTED_REQUEST_PEGIN_TXID = 0x22e8bc7b4a70ff1d480ef621c359c78aae9321956f3db74e56f05dad514b88d3;

    bytes32 constant EXPECTED_ACCEPT_PEGIN_TXID = 0x86295648884c670b5ac98930176460d69832151c594096fcc5dc3bb8ff318f29;

    bytes32 constant EXPECTED_REIMBURSEMENT_KICKOFF_TXID =
        0x47b3735f9ff3d53c535d2904142dd26193b02f612da59b7cd7ff565ad871a383;

    bytes32 constant EXPECTED_CHALLENGE_TXID = 0xf82e539f21a14212969c4ad5a66aab41ba7e95359150621903c42b06d11c1348;

    bytes32 constant EXPECTED_REVEAL_INPUT_TXID = 0x9d9273cde832d6c759977be083c96fd2dcb29ef08a42650b37a19ea630077cc1;

    function _getBitVMXDisputeKeys() internal pure returns (CompactPubKey[] memory keys) {
        keys = new CompactPubKey[](4);
        keys[0] =
            CompactPubKey({parity: 0x03, xOnly: 0x3058679f6d60b87ef921d98a2a9a1f1e0779dae27bedbd1cdb2f147a07835ac9});
        keys[1] =
            CompactPubKey({parity: 0x03, xOnly: 0x94cea1919bdcdefc478f8533a7bf8954867dc227da79754642cb2e41f7e300d8});
        keys[2] =
            CompactPubKey({parity: 0x03, xOnly: 0xbba554603171ffcc5e131cd399de0a1709ec52712c10bde061ed615a891af5dc});
        keys[3] =
            CompactPubKey({parity: 0x03, xOnly: 0x0135ce90e0f79390d4a72ce5a44ab64682758d4b74e6df312889f40d1892f9f9});
    }

    function _getBitVMXRequestPeginTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xc6f6b1571fcb8bdbf6231aca61b6354c937d288212fbbbc4557175841210dfac,
            vout: 0,
            scriptSig: hex"",
            sequence: 4294967293
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](3);
        outputs[0] = BtcTxOut({
            amount: 100000,
            scriptPubKey: hex"5120d580721d83c1b7a74062df7838d599172732f741d03de7b289a165d323960b40"
        });

        outputs[1] = BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a4552534b5f504547494e00000000000000007ac5496aee77c1ba1f0854206a26dda82a81d6d8a5a32f1e36335d6c3233bb36c4c5cdb51153a1698399ea0691be6e01a8580573"
        });

        outputs[2] = BtcTxOut({
            amount: 1080,
            scriptPubKey: hex"51209d3e251df2e6d92c41e8c357167a1a172b4cbd66f60386b270f4bfc0763beac2"
        });

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXAdvanceFundsTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0x48f5a0fad64999f3c65400b17f14c87367828afc0df3aa5adf14ce4edb81a6b7,
            vout: 2,
            scriptSig: hex"",
            sequence: 4294967293
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](3);
        outputs[0] = BtcTxOut({amount: 98790, scriptPubKey: hex"00140d5b208aa16e815295f2a2b0989f2bb623665372"});

        outputs[1] = BtcTxOut({
            amount: 0,
            scriptPubKey: hex"6a200000000000000000000000000000000000000000000000000000000000000001"
        });

        outputs[2] = BtcTxOut({amount: 18210, scriptPubKey: hex"001453b0f9d3489e371a924803a4ea6e084757f7b4f2"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXAcceptPeginTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](2);
        inputs[0] = BtcTxIn({
            txId: 0x22e8bc7b4a70ff1d480ef621c359c78aae9321956f3db74e56f05dad514b88d3,
            vout: 0,
            scriptSig: hex"",
            sequence: 4294967293
        });

        inputs[1] = BtcTxIn({
            txId: 0x22e8bc7b4a70ff1d480ef621c359c78aae9321956f3db74e56f05dad514b88d3,
            vout: 2,
            scriptSig: hex"",
            sequence: 4294967293
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](3);
        outputs[0] = BtcTxOut({
            amount: 99125,
            scriptPubKey: hex"5120b9160d26325d9090005fa2bf607679734d623b13e02c8bdeaf6ba5576d23f575"
        });

        outputs[1] = BtcTxOut({
            amount: 1080,
            scriptPubKey: hex"51209d3e251df2e6d92c41e8c357167a1a172b4cbd66f60386b270f4bfc0763beac2"
        });

        outputs[2] = BtcTxOut({amount: 540, scriptPubKey: hex"00140d5b208aa16e815295f2a2b0989f2bb623665372"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXOperatorTakeTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](2);
        inputs[0] = BtcTxIn({
            txId: 0x86295648884c670b5ac98930176460d69832151c594096fcc5dc3bb8ff318f29,
            vout: 0,
            scriptSig: hex"",
            sequence: 4294967293
        });

        inputs[1] = BtcTxIn({
            txId: 0x47b3735f9ff3d53c535d2904142dd26193b02f612da59b7cd7ff565ad871a383,
            vout: 0,
            scriptSig: hex"",
            sequence: 12
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 103375, scriptPubKey: hex"001453b0f9d3489e371a924803a4ea6e084757f7b4f2"});

        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"0014e975df1483a609586816020158aaed1d6def96f4"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXOperatorWonTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](2);
        inputs[0] = BtcTxIn({
            txId: 0x86295648884c670b5ac98930176460d69832151c594096fcc5dc3bb8ff318f29,
            vout: 0,
            scriptSig: hex"",
            sequence: 4294967293
        });

        inputs[1] = BtcTxIn({
            txId: 0x9d9273cde832d6c759977be083c96fd2dcb29ef08a42650b37a19ea630077cc1,
            vout: 0,
            scriptSig: hex"",
            sequence: 150
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({amount: 98790, scriptPubKey: hex"001453b0f9d3489e371a924803a4ea6e084757f7b4f2"});

        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"0014e975df1483a609586816020158aaed1d6def96f4"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXReimbursementKickoffTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xb3f2ac49d38f00819df95a59ea1e24ac2fec722f92c617e1ef7f087fe5b3d967,
            vout: 0,
            scriptSig: hex"",
            sequence: 4294967293
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({
            amount: 5125,
            scriptPubKey: hex"5120ae71fbb70d93e9248dfbe1d0455e34c8de7e322c43376d7ecfa2c4f72c731f07"
        });

        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00140efa7ed3ef1cbbfc3c346997c50fea5b6f33875b"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXChallengeTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0x47b3735f9ff3d53c535d2904142dd26193b02f612da59b7cd7ff565ad871a383,
            vout: 0,
            scriptSig: hex"",
            sequence: 6
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](5);
        outputs[0] = BtcTxOut({
            amount: 2528,
            scriptPubKey: hex"5120637ad6dd3beb6e8a7dc69b61c245d0e832961ac786d5a4e6756ced0127da4828"
        });

        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00149621e35bef10c40acc231164dbb0023ca2088a44"});

        outputs[2] = BtcTxOut({amount: 540, scriptPubKey: hex"00140efa7ed3ef1cbbfc3c346997c50fea5b6f33875b"});

        outputs[3] = BtcTxOut({amount: 540, scriptPubKey: hex"0014c4821c0cdd0d8c73ef6fe3726878916e3356410e"});

        outputs[4] = BtcTxOut({amount: 540, scriptPubKey: hex"0014b5a1d55d0ec0b66715260396ec3b92e5ffbca1a5"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXRevealInputTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xf82e539f21a14212969c4ad5a66aab41ba7e95359150621903c42b06d11c1348,
            vout: 0,
            scriptSig: hex"",
            sequence: 4294967293
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](2);
        outputs[0] = BtcTxOut({
            amount: 540,
            scriptPubKey: hex"512057b4b96b39617ff5bb667b7f2484af83ef7c8de378181ac7540d6091c68c6e62"
        });

        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00140efa7ed3ef1cbbfc3c346997c50fea5b6f33875b"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }

    function _getBitVMXInputNotRevealedTx() internal pure returns (BtcTransaction memory) {
        BtcTxIn[] memory inputs = new BtcTxIn[](1);
        inputs[0] = BtcTxIn({
            txId: 0xf82e539f21a14212969c4ad5a66aab41ba7e95359150621903c42b06d11c1348,
            vout: 0,
            scriptSig: hex"",
            sequence: 8
        });

        BtcTxOut[] memory outputs = new BtcTxOut[](4);
        outputs[0] = BtcTxOut({amount: 540, scriptPubKey: hex"00149621e35bef10c40acc231164dbb0023ca2088a44"});

        outputs[1] = BtcTxOut({amount: 540, scriptPubKey: hex"00140efa7ed3ef1cbbfc3c346997c50fea5b6f33875b"});

        outputs[2] = BtcTxOut({amount: 540, scriptPubKey: hex"0014c4821c0cdd0d8c73ef6fe3726878916e3356410e"});

        outputs[3] = BtcTxOut({amount: 540, scriptPubKey: hex"0014b5a1d55d0ec0b66715260396ec3b92e5ffbca1a5"});

        return BtcTransaction({version: 2, inputs: inputs, outputs: outputs, locktime: 0});
    }
}
