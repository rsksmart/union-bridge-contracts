# Constants
[Git Source](https://github.com/temp-rsk/bitvmx-union-bridge-contracts/blob/2c7f90ba21d83a98b646123c60d27a00fe0644fd/src/interfaces/IBridge.sol)

### RSK_BRIDGE_ADDRESS
*The RSK Bridge contract address for pow-peg bridge operations*

*This is the address of the RSK Bridge contract that handles pow-peg operations*


```solidity
address payable constant RSK_BRIDGE_ADDRESS = payable(0x0000000000000000000000000000000001000006);
```

### BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH
*Maximum depth for Bitcoin transaction confirmation searches*

*Enough depth to search backwards one month worth of blocks*

*(6 blocks/hour, 24 hours/day, 30 days/month)*


```solidity
int256 constant BTC_TRANSACTION_CONFIRMATION_MAX_DEPTH = 4320;
```

### BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE
*Error code for non-existent block hash in Bitcoin transaction confirmation*

*From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100*


```solidity
int256 constant BTC_TRANSACTION_CONFIRMATION_INEXISTENT_BLOCK_HASH_ERROR_CODE = -1;
```

### BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE
*Error code for block not in best chain in Bitcoin transaction confirmation*

*From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100*


```solidity
int256 constant BTC_TRANSACTION_CONFIRMATION_BLOCK_NOT_IN_BEST_CHAIN_ERROR_CODE = -2;
```

### BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE
*Error code for inconsistent block in Bitcoin transaction confirmation*

*From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100*


```solidity
int256 constant BTC_TRANSACTION_CONFIRMATION_INCONSISTENT_BLOCK_ERROR_CODE = -3;
```

### BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE
*Error code for block too old in Bitcoin transaction confirmation*

*From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100*


```solidity
int256 constant BTC_TRANSACTION_CONFIRMATION_BLOCK_TOO_OLD_ERROR_CODE = -4;
```

### BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE
*Error code for invalid merkle branch in Bitcoin transaction confirmation*

*From RSK Bridge implementation https://github.com/rsksmart/rskj/blob/master/rskj-core/src/main/java/co/rsk/peg/BridgeSupport.java#L89C1-LL93C100*


```solidity
int256 constant BTC_TRANSACTION_CONFIRMATION_INVALID_MERKLE_BRANCH_ERROR_CODE = -5;
```

