// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract TestECDSA is Test {
    function test_pubKeyToAddress_Success() public pure {
        // Arrange
        // Data obtained form e2e test and keymanager
        bytes32 publicKeyX = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes32 publicKeyY = 0x6321802fbb8c86ffd00a8c6f6ca5acffad1cac77501c58fc29617ebe30debc12;
        bytes memory uncompressedPubKey = abi.encode(publicKeyX, publicKeyY);
        assertEq(
            uncompressedPubKey,
            hex"7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f6321802fbb8c86ffd00a8c6f6ca5acffad1cac77501c58fc29617ebe30debc12"
        );

        bytes32 pubKeyHash = keccak256(uncompressedPubKey);
        assertEq(pubKeyHash, 0x0fab2b153f06671a19de8654b2f73dbe65cd2c4e918d7e3bcb8debebe4bfc161);

        address pubKeyAddress = address(uint160(uint256(pubKeyHash)));
        assertEq(pubKeyAddress, 0xB2F73dbe65Cd2c4e918d7E3BCB8dEbEBE4bfc161);
    }

    function test_ecrecover_Success() public pure {
        // Arrange
        // Data obtained form e2e test and keymanager
        bytes32 publicKeyX = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
        bytes32 publicKeyY = 0x6321802fbb8c86ffd00a8c6f6ca5acffad1cac77501c58fc29617ebe30debc12;
        bytes32 pubKeyHash = keccak256(abi.encode(publicKeyX, publicKeyY));

        bytes32 r = 0x082651c6c94503226b0a93189ea9bb44a6bb476b4babfde1d97f1950938be78a;
        bytes32 s = 0x5078f55b77f576d96bc8c152669ac5891fb839c35c4d0c564b5e27a86adade12;
        uint8 v = 27;
        address recovered = ECDSA.recover(pubKeyHash, v, r, s);
        assertEq(recovered, 0xB2F73dbe65Cd2c4e918d7E3BCB8dEbEBE4bfc161);
    }
}
