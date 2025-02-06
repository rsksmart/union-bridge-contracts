# BitVMX Union Bridge Contracts
This repository contains the specifications and Solidity code for the Union Bridge Contracts.

## Testing

You can run the full test suit with:

 ```sh
bash run.sh
```

What it does is runs the followgin steps

1. [Formats the code](https://book.getfoundry.sh/reference/config/formatter):

```sh
bash format.sh
```

2. Run the [test suite](https://book.getfoundry.sh/forge/tests):

```sh
bash test.sh
```

3. Create [gas snapshot](https://book.getfoundry.sh/forge/gas-function-snapshots):

```sh
bash gas-snapshot.sh
```

4. Run [Slither](https://github.com/crytic/slither) in a docker image:

```sh
bash slither.sh
```

5. Use [deployment script](https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract) to run a simulation:

```sh
bash simulate-deploy.sh
```


## Deployment

Use [deployment script] (https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract) to deploy:

```sh
bash deploy.sh
```

It will ask for a private key interactivly in order to performe the deployment. The address of the private key needs to have funds in order to perform the deployment.

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

### Best Practices

We are following [https://book.getfoundry.sh/tutorials/best-practices](https://book.getfoundry.sh/tutorials/best-practices)

### Precompiled Bridge contract (aka PowPeg or Legacy Bridge)

We use a soldity interface called [Bridge.sol](./src//interfaces/Bridge.sol) to interact with the pre compiled contract, this information was obtained from the [FastBtc bridge contracts](https://github.com/rsksmart/liquidity-bridge-contract/tree/master)

### Partial Merkle Tree Generation

We use https://github.com/rsksmart/pmt-builder in order to obtain the`merkleBranchPath` and `merkleBranchHashes` used in the bitcoin transaction SPV (proof). Usage example:

```sh
node tool/pmt-builder.js mainnet 0000000000000000000282fa21665766e58eb6cb94e458c3ef6d4af1121e38d9 c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079
```

Result

```js
Result: {
  totalTX: 3009,
  hashes: [
    '3fcef4a1ddf759a858190b89ecbd1ff3dffb49704e110b68baf5b5de7021910f',
    '481a71c0478c28b68a698b8e9be317e9a0d9d153b0b2db417a45b5773ef6a0f2',
    'c00e989a80847a9e2d3e605904ae24c097b1e5abcfa6805434ab802abfcfd079',
    '1780d0b717e2782046036f3a876037b3fe590834aa5da0b9a09b269d29856660',
    '649272353930bb551a61ca491844128dcd33900872bd9387224bbfd3da9906e5',
    '9617e6383b72d518449fc2c5a18cc24d1e1b3a59e7f8dce6dbf7e822275d382b',
    'a07d3b738d7b280b296cd9a11821c375b600c3524849822925f5c11a39878886',
    '9dd03a4e5358ca5c78c1aea47a944dee59a5153e87330c85c218e81f34e46839',
    '8c4a0c760fafa20c98217d482f85f297dcab25facbe8d5eccb3666a75ac7da37',
    '35d4bf31bdcb1dae3fc659536487c492abae0addcdcfe3e9434c0e9b8f552f8c',
    'ae229406e25c7c52450f31b8a106f9cf5e5f8ae688ca7a25408e6bb339251221',
    '8d84f7110e788ec0591feb5c30f83c9bd326a88c2388d6c6ea10b886e360fffe',
    '5f05f1da73fc3498a59a4245e41b52b0a80dbaa3426fbd541c14327c9a362487'
  ],
  flags: 4285202432,
  ...
```

Where hashes are the `merkleBranchHashes` and flags is the `merkleBranchPath`

## Security

We are using [Slither](https://github.com/crytic/slither) static analyzer to check for potentials threats. We are running it through the docker image [eth-security-toolbox](https://github.com/trailofbits/eth-security-toolbox/) from trail of bits.
Using the following command:

```sh
docker-compose up
```