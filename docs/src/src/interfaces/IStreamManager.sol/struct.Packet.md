# Packet
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/8e06478fcc29439a812dd6c68981ff5bb04b9543/src/interfaces/IStreamManager.sol)

Represents a packet within a stream that contains multiple slots

*Each packet is managed by a specific committee*


```solidity
struct Packet {
    uint64 packetNumber;
    uint128 committeeId;
    bytes32 committeePubKey;
}
```

