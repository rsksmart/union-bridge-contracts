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
import {BtcTxSPVProof} from "src/PegManager.sol";
import {BtcTransaction, BtcTxIn, BtcTxOut} from "src/interfaces/IBitcoinManager.sol";
import {BtcScriptParser} from "src/libraries/BtcScriptParser.sol";
import {Constants} from "src/libraries/Constants.sol";

abstract contract ScriptUtils is Script {
    function getDeployerKey() public view returns (uint256) {
        return getMemberKey(uint32(vm.envUint("DEPLOYER_INDEX")));
    }

    function getDeployerAddress() public returns (address) {
        return vm.rememberKey(getDeployerKey());
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

    function generateRegistrationPublicKeys(uint256 _privateKey)
        public
        returns (MemberRegistrationKeys memory registrationKeys)
    {
        // Generate a deterministic 'public keys' from a private key
        registrationKeys.takeKey = generateECDSAPublicKey(_privateKey, PublicKeyType.TAKE);
        registrationKeys.covenantKey = generateECDSAPublicKey(_privateKey, PublicKeyType.COVENANT);
        registrationKeys.communicationKey = generateRSAPublicKey(_privateKey, PublicKeyType.COMMUNICATION);
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
}
