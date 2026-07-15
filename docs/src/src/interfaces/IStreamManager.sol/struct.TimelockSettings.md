# TimelockSettings
[Git Source](https://github.com/rsksmart/union-bridge-contracts/blob/b56fdca4d854a3d344854107131d121e04834d63/src/interfaces/IStreamManager.sol)

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

