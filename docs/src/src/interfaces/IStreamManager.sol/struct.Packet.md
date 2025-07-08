# Packet
[Git Source](https://github.com/FairgateLabs/bitvmx-union-bridge-contracts/blob/88ae00b3e8fb636de955be6f15b3c84ce2cc3729/src/interfaces/IStreamManager.sol)

Represents a packet within a stream that contains multiple slots

*Each packet is managed by a specific committee*


```solidity
struct Packet {
    uint64 packetNumber;
    uint256 committeeId;
    bytes32 committeePubKey;
}
```

