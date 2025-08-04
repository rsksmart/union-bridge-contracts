# Packet
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/b41d024ed73655cc3c392a6c92b6259ef625d19d/src/interfaces/IStreamManager.sol)

Represents a packet within a stream that contains multiple slots

*Each packet is managed by a specific committee*


```solidity
struct Packet {
    uint64 packetNumber;
    uint256 committeeId;
    bytes32 committeePubKey;
}
```

