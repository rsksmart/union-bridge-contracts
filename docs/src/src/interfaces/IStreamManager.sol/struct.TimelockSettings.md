# TimelockSettings
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/dd34207db3c68e4260aba3e2d2660c73733e6970/src/interfaces/IStreamManager.sol)

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

