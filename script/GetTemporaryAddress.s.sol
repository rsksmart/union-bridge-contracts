// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PegManager} from "src/PegManager.sol";
import {Stream, Packet} from "src/interfaces/IStreamManager.sol";

contract GetTemporaryAddressScript is Script {
    PegManager pegManager;
    address rootstock_deposit_address;
    uint64 value;
    bytes32 btc_reimbursement_pub_key;

    function setUp() internal {
        pegManager = PegManager(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
        rootstock_deposit_address = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        value = 100_000;
        btc_reimbursement_pub_key = 0xc72a9f6fc8e57f1de528a48b6c4ad7a6db30b24a7bbf8cdd74b0a3b248b6f7f1;
    }

    function run() public {
        setUp();

        address owner = pegManager.owner();
        console.log("owner");
        console.logAddress(owner);

        uint256 streamLen = pegManager.getStreamsLength();
        console.log("streamLen");
        console.log(streamLen);

        Stream memory stream = pegManager.getStream(value);
        console.log("streamId");
        console.log(stream.streamId);
        console.log("stream.peginPointer");
        console.log(stream.peginPointer);

        (uint64 packetNumber, bytes32 committeePubKey) = pegManager.packets(stream.streamId, stream.peginPointer);
        console.log("packetNumber");
        console.logUint(packetNumber);
        console.log("committeePubKey");
        console.logBytes32(committeePubKey);

        string memory result =
            pegManager.getTemporaryPegInAddress(rootstock_deposit_address, value, btc_reimbursement_pub_key);
        console.log("getTemporaryPegInAddress");
        console.log(result);
    }
}
