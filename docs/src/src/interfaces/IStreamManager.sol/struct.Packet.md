# Packet
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/d1d7e57632b0c5f559c5c50994a17b0f4b09c742/src/interfaces/IStreamManager.sol)

Represents a packet within a stream that contains multiple slots

*Each packet is managed by a specific committee*


```solidity
struct Packet {
    uint64 packetNumber;
    uint128 committeeId;
    bytes committeePubKey;
}
```

