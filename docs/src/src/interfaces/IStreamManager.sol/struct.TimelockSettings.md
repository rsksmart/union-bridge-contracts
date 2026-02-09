# TimelockSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/835a0374fad05fe95d66ed5d56f02d5826093237/src/interfaces/IStreamManager.sol)

Bitcoin Timelock settings in blocks for the stream

*These are the timelock settings used to verify the Bitcoin transactions for the stream*


```solidity
struct TimelockSettings {
    uint8 shortTimelock;
    uint8 longTimelock;
    uint8 requestPeginTimelock;
    uint8 opWonTimelock;
    uint8 claimGateTimelock;
    uint8 inputNotRevealedTimelock;
    uint8 opNoCosignTimelock;
    uint8 wtNoChallengeTimelock;
}
```

