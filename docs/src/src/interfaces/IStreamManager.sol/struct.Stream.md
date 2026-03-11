# Stream
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/aa0c5b500b0a03f68164877ee0ab01eebfbdfa68/src/interfaces/IStreamManager.sol)

Represents a stream that manages funds of a specific denomination

*Each stream handles a specific Bitcoin amount for efficient fund management*


```solidity
struct Stream {
    uint64 streamId;
    uint64 denomination;
    uint64 peginPacketPointer;
    uint8 peginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

