# BitVMX Union Bridge Contracts
This repository contains the specifications and Solidity code for the Union Bridge Contracts.

## Getting Started
To build and test this repo you can run:

```sh
forge build
forge test
```

## Writing tests
To write new tests for the contracts simply `import forge-std/Test.sol` and inherit it in your test contract. The forge-std Test contract provides a pre-initialized [cheatcodes environment](https://book.getfoundry.sh/cheatcodes/) via the `vm`. It also includes support for [ds-test](https://book.getfoundry.sh/reference/ds-test.html)-style logs and assertions, as well as Hardhat's [console.log](https://github.com/brockelmore/forge-std/blob/master/src/console.sol). Note that logging functionalities require the -vvvv flag.

```solidity
pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract ContractTest is Test {
    function testExample() public {
        vm.roll(100);
        console.log(1);
        emit log("hi");
        assertTrue(true);
    }
}
```

## Development
This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.
