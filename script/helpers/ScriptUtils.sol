// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {
    PublicKeyType,
    ECDSAPublicKey,
    RSAPublicKey,
    MemberRegistrationKeys,
    RSA_PUBLIC_KEY_CHUNKS
} from "src/interfaces/ICommitteeRegistry.sol";
import {BtcTxSPVProof} from "src/interfaces/IPegCommonTypes.sol";
import {BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {BtcHelper} from "src/libraries/BtcHelper.sol";
import {BtcTaproot} from "src/libraries/BtcTaproot.sol";
import {OpCodes} from "src/libraries/OpCodes.sol";
import {Constants} from "src/libraries/Constants.sol";

abstract contract ScriptUtils is Script {
    int256 public constant CONFIRMATIONS = 10;
    // Fake amount just for testing purposes
    uint64 constant REIMBURSEMENT_KICKOFF_AMOUNT = 5137;

    function getDeployerKey() public view returns (uint256) {
        return getMemberKey(uint32(vm.envUint("DEPLOYER_INDEX")));
    }

    function getDeployerAddress() public returns (address) {
        return vm.rememberKey(getDeployerKey());
    }

    function getPauserAddress() public returns (address) {
        // Try to get PAUSER_ADDRESS from environment
        // If not set, default to deployer address
        try vm.envAddress("PAUSER_ADDRESS") returns (address pauserAddr) {
            return pauserAddr;
        } catch {
            return getDeployerAddress();
        }
    }

    function getMemberKey(uint32 index) public view returns (uint256) {
        // The deploy contracts scripts use members from 1 to 10 we map them to 0 to 9
        return vm.deriveKey(vm.envString("MNEMONIC"), index);
    }

    function createWallet(uint256 _privateKey, PublicKeyType _keyType) public returns (Vm.Wallet memory) {
        return vm.createWallet(uint256(keccak256(abi.encode(_privateKey, _keyType))));
    }

    function generateECDSAPublicKey(uint256 _privateKey, PublicKeyType _keyType)
        public
        returns (ECDSAPublicKey memory ecdsaPublicKey)
    {
        // Generate a deterministic 'public key' from the private key
        Vm.Wallet memory wallet = createWallet(_privateKey, _keyType);
        // Hash the uncompressed public key
        bytes32 hash = keccak256(abi.encode(wallet.publicKeyX, wallet.publicKeyY));
        // Sign the public key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wallet, hash);
        ecdsaPublicKey = ECDSAPublicKey({
            publicKeyX: bytes32(wallet.publicKeyX),
            publicKeyY: bytes32(wallet.publicKeyY),
            v: v,
            r: r,
            s: s
        });
        return ecdsaPublicKey;
    }

    /// @notice Generates a deterministic emulated RSA public key for the given private key and key type
    /// @dev This is only for testing purposes
    /// @param _privateKey The private key to generate the RSA public key from
    /// @param _keyType The key type to generate the RSA public key for
    /// @return rsaPublicKey The deterministic emulated RSA public key
    function generateRSAPublicKey(uint256 _privateKey, PublicKeyType _keyType)
        public
        pure
        returns (RSAPublicKey memory rsaPublicKey)
    {
        bytes32[RSA_PUBLIC_KEY_CHUNKS] memory rsaPublicKeyArray;
        for (uint256 i = 0; i < RSA_PUBLIC_KEY_CHUNKS; i++) {
            rsaPublicKeyArray[i] = keccak256(abi.encode(_privateKey, "rsa_der", uint8(_keyType), i));
        }
        rsaPublicKey = RSAPublicKey({rsaPublicKey: rsaPublicKeyArray});
        return rsaPublicKey;
    }

    /// @notice Generates a deterministic registration 'public keys' from a private key
    /// @dev This is only for testing purposes
    /// @param _privateKey The private key to generate the public keys from
    /// @return registrationKeys The deterministic registration 'public keys' struct
    function generateRegistrationPublicKeys(uint256 _privateKey)
        public
        returns (MemberRegistrationKeys memory registrationKeys)
    {
        // Generate a deterministic 'public keys' from a private key
        registrationKeys.takeKey = generateECDSAPublicKey(_privateKey, PublicKeyType.TAKE);
        registrationKeys.covenantKey = generateECDSAPublicKey(_privateKey, PublicKeyType.COVENANT);
        registrationKeys.communicationKey = generateRSAPublicKey(_privateKey, PublicKeyType.COMMUNICATION);
    }

    // ========================== Peg in ==========================
    function getAcceptPeginP2TRScriptPub(bytes memory _committeePubKey) internal pure returns (bytes memory) {
        bytes32 tweakedPublicKey = getAcceptPeginTweakedPublicKey(_committeePubKey);
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
    }

    function getAcceptPeginTweakedPublicKey(bytes memory _committeePubKey) internal pure returns (bytes32) {
        // Extract x-coordinate from compressed public key (skip first byte which is prefix)
        // Assembly is required here for BIP340 X-only public key extraction from the 33-byte compressed format.
        // BIP340 specifies Schnorr signatures use only the x-coordinate, stored at bytes 1-32 (skipping the prefix byte).
        bytes32 committeePubKeyX;
        // slither-disable-next-line assembly
        assembly {
            committeePubKeyX := mload(add(_committeePubKey, 33))
        }

        // Currently we only consider the key spend path (user take)
        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(committeePubKeyX));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(committeePubKeyX, tweak);

        return tweakedPublicKey;
    }

    function getRequestPeginP2TRScriptPub(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) internal pure returns (bytes memory) {
        bytes32 tweakedPublicKey = getRequestPeginTweakedPublicKey(
            _timelockBlocks, _rskDestinationAddress, _value, _btcReimbursementPubKey, _committeePubKey
        );
        return BtcTaproot.getP2TRScriptPubKey(tweakedPublicKey);
    }

    function getRequestPeginTweakedPublicKey(
        uint32 _timelockBlocks,
        address _rskDestinationAddress,
        uint64 _value,
        bytes32 _btcReimbursementPubKey,
        bytes memory _committeePubKey
    ) internal pure returns (bytes32) {
        bytes memory timelockScript = BtcScriptParser.getTimelockScript(_timelockBlocks, _btcReimbursementPubKey);
        bytes32 timelockLeaf = BtcTaproot.getLeaf(timelockScript);

        bytes memory extraDataScript =
            abi.encodePacked(OpCodes.OP_RETURN, OpCodes.OP_PUSHBYTES_28, _rskDestinationAddress, _value);
        bytes32 extraDataLeaf = BtcTaproot.getLeaf(extraDataScript);

        bytes32 merkleRoot = BtcTaproot.getBranch(timelockLeaf, extraDataLeaf);

        // Extract x-coordinate from compressed public key (skip first byte which is prefix)
        // Assembly is required here for BIP340 X-only public key extraction from the 33-byte compressed format.
        // BIP340 specifies Schnorr signatures use only the x-coordinate, stored at bytes 1-32 (skipping the prefix byte).
        bytes32 committeePubKeyX;
        // slither-disable-next-line assembly
        assembly {
            committeePubKeyX := mload(add(_committeePubKey, 33))
        }

        bytes32 tweak = BtcTaproot.getTweak(abi.encodePacked(committeePubKeyX, merkleRoot));
        bytes32 tweakedPublicKey = BtcTaproot.getTweakedPublicKey(committeePubKeyX, tweak);

        return tweakedPublicKey;
    }

    // ========================== Peg out ==========================
    function createPegoutTx(bytes32 _acceptPeginTxid, bytes memory _userPubKey, uint64 _amount)
        internal
        pure
        returns (BtcTransaction memory)
    {
        // Inputs: spend the accept peg-in taptree UTXO and enabler UTXO
        BtcTxIn[] memory btcInputs = new BtcTxIn[](2);
        btcInputs[0] = BtcTxIn({
            txId: _acceptPeginTxid,
            vout: Constants.ACCEPT_PEGIN_VOUT_TAPTREE, // P2TR taptree output
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
        btcInputs[1] = BtcTxIn({
            txId: _acceptPeginTxid,
            vout: Constants.ACCEPT_PEGIN_VOUT_ENABLER, // Enabler output
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        // Outputs
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);

        // user output amount
        uint64 userAmount = _amount - 1000; // Subtract fee
        bytes memory userScriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);

        // pay to user's P2WPKH
        btcOutputs[Constants.PEGOUT_VOUT_USER] = BtcTxOut({amount: userAmount, scriptPubKey: userScriptPubKey});

        // speedup
        btcOutputs[Constants.PEGOUT_VOUT_SPEED_UP] = BtcTxOut({amount: 300, scriptPubKey: userScriptPubKey});

        return BtcTransaction({version: Constants.BTC_TX_VERSION, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
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

    function createOperatorTakeTx(
        bytes32 _acceptPeginTxid,
        bytes32 _reimbursementKickoffTxid,
        bytes memory _operatorPubKey,
        uint64 _streamDenomination
    ) internal pure returns (BtcTransaction memory) {
        // Input: spend the accept peg-in UTXO
        BtcTxIn[] memory btcInputs = new BtcTxIn[](2);
        btcInputs[Constants.OPERATOR_TAKE_VIN_ACCEPT_PEGIN] = BtcTxIn({
            txId: _acceptPeginTxid,
            vout: 0, // P2TR output is at index 0
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        btcInputs[Constants.OPERATOR_TAKE_VIN_REIMBURSEMENT_KICKOFF] = BtcTxIn({
            txId: _reimbursementKickoffTxid,
            vout: 0, // P2TR output is at index 0
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        // Outputs
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);

        // operator output amount
        // This should include fee and speedup from accept pegin and from operator take itself.
        uint64 operatorAmount =
            _streamDenomination + REIMBURSEMENT_KICKOFF_AMOUNT - 2 * (Constants.P2TR_FEE + Constants.SPEED_UP_AMOUNT);
        bytes memory operatorScriptPubKey = BtcScriptParser.getP2WPKHScript(_operatorPubKey);

        // pay to operator's P2WPKH
        btcOutputs[Constants.OPERATOR_TAKE_VOUT_OPERATOR] =
            BtcTxOut({amount: operatorAmount, scriptPubKey: operatorScriptPubKey});

        // speedup
        btcOutputs[1] = BtcTxOut({amount: Constants.SPEED_UP_AMOUNT, scriptPubKey: operatorScriptPubKey});

        return BtcTransaction({version: Constants.BTC_TX_VERSION, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function createReimbursementKickoffTx(bytes memory _committeePubKey, uint32 _slotIndex)
        internal
        pure
        returns (BtcTransaction memory)
    {
        // Input: spend Operator Initial deposit UTXO for this particular slot
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            // Input txid is uncheckable by the contract
            txId: bytes32(0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd),
            vout: _slotIndex,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        // Outputs
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);
        bytes memory committeeScriptPubKey = BtcScriptParser.getP2WPKHScript(_committeePubKey);

        // P2TR
        btcOutputs[0] = BtcTxOut({amount: REIMBURSEMENT_KICKOFF_AMOUNT, scriptPubKey: committeeScriptPubKey});

        return BtcTransaction({version: Constants.BTC_TX_VERSION, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    function createAdvanceFundsTx(bytes memory _userPubKey, uint64 _streamDenomination, bytes32 _pegoutId)
        internal
        pure
        returns (BtcTransaction memory)
    {
        // Prepare the inputs
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: hex"0000000000000000000000000000000000000000000000000000000000000000",
            vout: 0,
            scriptSig: bytes(""),
            sequence: Constants.SEQUENCE
        });

        // Prepare the outputs, user and speed up
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](2);

        // Calculate fee and speedUpAmount from amount
        // TODO: atm is returning hardcoded values, should be calculated
        (uint64 fee, uint64 speedUpAmount) = BtcHelper.calculateFeeAndSpeedUp();

        // User pegout
        bytes memory scriptPubKey = BtcScriptParser.getP2WPKHScript(_userPubKey);
        btcOutputs[Constants.ADVANCE_FUNDS_VOUT_USER] =
            BtcTxOut({amount: _streamDenomination - 2 * fee - speedUpAmount, scriptPubKey: scriptPubKey});

        // Pegout ID output
        btcOutputs[Constants.ADVANCE_FUNDS_VOUT_OP_RETURN] =
            BtcTxOut({amount: 0, scriptPubKey: BtcScriptParser.getPegoutIdScript(_pegoutId)});

        // Prepare Btc Transaction
        return BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            locktime: Constants.LOCKTIME,
            inputs: btcInputs,
            outputs: btcOutputs
        });
    }

    // ========================== User Reimbursement ==========================
    function createBtcUserReimbursementTx(bytes32 _requestPeginTxid, uint64 _amount, bytes32 _btcReimbursementPubKey)
        pure
        returns (BtcTransaction memory)
    {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        // Input spends the request pegin taptree output (vout 0)
        btcInputs[0] = BtcTxIn({
            txId: _requestPeginTxid,
            vout: Constants.REQUEST_PEGIN_VOUT_TAPTREE,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });
        // Output: P2WPKH to user's reimbursement pubkey
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);
        btcOutputs[0] = BtcTxOut({
            amount: _amount - Constants.P2TR_FEE,
            scriptPubKey: BtcScriptParser.getP2WPKHScript(BtcHelper.pubKeyXonlyToCompact(_btcReimbursementPubKey))
        });
        return BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: btcInputs,
            outputs: btcOutputs,
            locktime: Constants.LOCKTIME
        });
    }

    // ========================== Challenge ==========================
    function createChallengeTx(bytes32 _reimbursementKickoffTxid, bytes memory _committeePubKey)
        pure
        returns (BtcTransaction memory)
    {
        // Input: spend the reimbursement kickoff UTXO
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _reimbursementKickoffTxid,
            vout: 0, // P2TR output is at index 0
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        // Outputs
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);

        // P2TR to committee
        btcOutputs[0] = BtcTxOut({
            amount: REIMBURSEMENT_KICKOFF_AMOUNT,
            scriptPubKey: getAcceptPeginP2TRScriptPub(_committeePubKey)
        });

        return BtcTransaction({version: Constants.BTC_TX_VERSION, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }

    // ========================== Reject Peg-in ==========================
    function createRejectPeginTx(bytes32 _requestPeginTxid, bytes memory _operatorPubKey)
        internal
        pure
        returns (BtcTransaction memory)
    {
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        // Input spends the request pegin enabler output (vout 2)
        btcInputs[0] = BtcTxIn({
            txId: _requestPeginTxid,
            vout: Constants.REQUEST_PEGIN_VOUT_ENABLER,
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        // Speed up Output: P2WPKH to operator's dispute key
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);
        bytes memory speedUpScriptPubKey = BtcScriptParser.getP2WPKHScript(_operatorPubKey);
        btcOutputs[0] = BtcTxOut({amount: Constants.SPEED_UP_AMOUNT, scriptPubKey: speedUpScriptPubKey});

        return BtcTransaction({
            version: Constants.BTC_TX_VERSION,
            inputs: btcInputs,
            outputs: btcOutputs,
            locktime: Constants.LOCKTIME
        });
    }

    // ========================== Reveal ==========================
    function createRevealTx(bytes32 _challengeTxid, bytes memory _committeePubKey)
        internal
        pure
        returns (BtcTransaction memory)
    {
        // Input: spend the challenge UTXO
        BtcTxIn[] memory btcInputs = new BtcTxIn[](1);
        btcInputs[0] = BtcTxIn({
            txId: _challengeTxid,
            vout: 0, // P2TR output is at index 0
            sequence: Constants.SEQUENCE,
            scriptSig: hex""
        });

        // Outputs
        BtcTxOut[] memory btcOutputs = new BtcTxOut[](1);

        // P2TR to committee
        // This is a fake amount just for testing purposes
        btcOutputs[0] = BtcTxOut({amount: 2000, scriptPubKey: getAcceptPeginP2TRScriptPub(_committeePubKey)});

        return BtcTransaction({version: Constants.BTC_TX_VERSION, inputs: btcInputs, outputs: btcOutputs, locktime: 0});
    }
}
