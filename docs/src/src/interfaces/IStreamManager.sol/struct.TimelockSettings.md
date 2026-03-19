# TimelockSettings
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/ee0115174aa9f16d975ad140f940d23fb1883b23/src/interfaces/IStreamManager.sol)

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

