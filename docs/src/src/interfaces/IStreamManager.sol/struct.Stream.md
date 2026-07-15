# Stream
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/6c85aeb17a23ee9d675a92f8655a551ecca7b4c9/src/interfaces/IStreamManager.sol)

Represents a stream that manages funds of a specific denomination

*Each stream handles a specific Bitcoin amount for efficient fund management*


```solidity
struct Stream {
    uint64 streamId;
    uint64 denomination;
    uint64 peginPacketPointer;
    uint8 peginConfirmations;
    uint8 rejectPeginConfirmations;
    uint8 pegoutConfirmations;
    TimelockSettings timelockSettings;
}
```

