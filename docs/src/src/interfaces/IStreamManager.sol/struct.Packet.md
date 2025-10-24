# Packet
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/3db9056f26f2b3b61c05819d9eb725e59c32f233/src/interfaces/IStreamManager.sol)

Represents a packet within a stream that contains multiple slots

*Each packet is managed by a specific committee*


```solidity
struct Packet {
    uint64 packetNumber;
    uint128 committeeId;
    bytes committeePubKey;
}
```

