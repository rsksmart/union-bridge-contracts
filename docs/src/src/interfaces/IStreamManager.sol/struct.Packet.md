# Packet
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/IStreamManager.sol)

Represents a packet within a stream that contains multiple slots

*Each packet is managed by a specific committee*


```solidity
struct Packet {
    uint64 packetNumber;
    uint128 committeeId;
    bytes committeePubKey;
    bytes enablerScriptPubKey;
    uint64 finishedSlots;
}
```

