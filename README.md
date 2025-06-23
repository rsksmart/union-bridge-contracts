# BitVMX Union Bridge Contracts

This repository contains the specifications and Solidity code for the Union Bridge Contracts.

## Pre requisites

- You’ll need the [Rust](https://www.rust-lang.org/) compiler and Cargo, Rust’s package manager. The easiest way to install both is by using [rustup.rs.](https://rustup.rs/)
- [Foundry v1.2.3](https://book.getfoundry.sh/getting-started/installation) running `foundryup -v v1.2.3`
- [Node.js LTS (22)](https://nodejs.org/en/download)

## Install dependencies

- Run `forge install` to install smart contract dependencies
- Run `npm install -g @openzeppelin/upgrades-core@1.44.0` to install open zepelin upgrade validations dependencies

## Testing

### Tests

You can run unit test with:

```sh
bash test.sh
```

### Coverage

Show coverage report and create [lcov file](https://lcov-viewer.netlify.app/)

```sh
bash coverage.sh
```

### Contract size

Also you can check the contract size using:

```sh
bash shell/size-report.sh
```

Contracts size needs to be lower than 24kb

### Integration test

You can run the local integration test suit with:

```sh
bash run.sh
```

What it does is runs the followgin steps

1. [Formats the code](https://book.getfoundry.sh/reference/config/formatter):

```sh
bash shell/format.sh
```

2. Run the [test suite](https://book.getfoundry.sh/forge/tests):

```sh
bash shell/test.sh
```

3. Create [gas snapshot](https://book.getfoundry.sh/forge/gas-function-snapshots):

```sh
bash shell/gas-snapshot.sh
```

4. [Run pegin/pegout flow](#run-peginpegout-flow):

```sh
bash ./shell/script/local-peg-full-flow.sh
```

5. Run [Slither](https://github.com/crytic/slither) in a docker image:

```sh
bash shell/slither.sh
```

6. Use [deployment script](https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract) to run a simulation:

```sh
bash shell/sscript/deploy/simulate-deploy.sh
```

## Deployment

Use [deployment script] (https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract) to deploy:

```sh
bash shell/script/deploy/deploy.sh
```

It will ask for a private key interactivly in order to performe the deployment. The address of the private key needs to have funds in order to perform the deployment.
If you want to deploy to a local network (regtest) use `deploy-local.sh`.

### Rust crate with Bindings

To generate the new bindings for the smart contracts run :

```sh
bash bind.sh
```

It will automatically generate the rust files for the smart contracts using Alloy

## Scripts

We have scripts to interact with the deployed contracts

### Set Mock Bridge Confirmations

In order to use the smart contracts on localnet we will need to set the number of confirmations of the BTC transactions because the Powpeg bridge does not exists on our local network.
To do this we will run:

```sh
bash shell/script/set-mock-bridge-confirmations.sh
```

### Get temporary address

Returns the address where the user have to send funds to PegIn, set the corresponding arguments at [GetTemporaryAddress.s.sol](./script/GetTemporaryAddress.s.sol)

```solidity
// ====== Arguments ======
rootstock_deposit_address = 0x7ac5496aee77c1ba1f0854206a26dda82a81d6d8;
value = 100_000;
btc_reimbursement_pub_key = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
```

Then run:

```sh
bash shell/script/get-temporary-address.sh
```

### Request peg in

Register the peg in request transaction sent by the user in Bitcoin, set the corresponding arguments at [RequestPegout.s.sol](./script/RequestPegout.s.sol)

```solidity
// ====== Arguments ======
address rskDestinationAddress = 0x7ac5496aee77c1ba1f0854206a26dda82a81d6d8;
uint64 value = 100_000;
bytes32 btcReimbursementPubKey = 0x7d235c24420b2f55450c8414725aa74e6db01035245efdab0e1cfa7ab29aca0f;
pegManager = PegManager(0x0165878A594ca255338adfa4d48449f69242Eb8F);
```

Then run:

```sh
bash shell/script/request-pegin.sh
```

### Accept peg in

Register the accept peg in request transaction sent by the committee in Bitcoin, set the corresponding arguments at [AcceptPegin.s.sol](./script/AcceptPegin.s.sol)

Then run:

```sh
bash shell/script/accept-pegin.sh
```

### Request peg out

Request the peg out request, set the corresponding arguments at [RequestPegout.s.sol](./script/RequestPegout.s.sol)

Then run:

```sh
bash shell/script/request-pegout.sh
```

### Run Pegin/Pegout Flow

For easier testing of the complete pegin/pegout flow, we provide a script that automates the entire sequence. The script performs the following steps:

1. Terminates any existing `anvil` instance
2. Starts a fresh `anvil` instance (local Ethereum node)
3. Deploys all required contracts
4. Simulates a complete pegin/pegout cycle:
   - Registers a pegin request (user deposits BTC)
   - Accepts the pegin request (committee confirms BTC deposit)
   - Registers a pegout request (user requests BTC withdrawal)
   - Adds committee member signatures (to authorize BTC withdrawal)

To run the automated flow:

```sh
bash ./shell/script/local-peg-full-flow.sh
```

## Development

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.

### Best Practices

We are following [https://book.getfoundry.sh/tutorials/best-practices](https://book.getfoundry.sh/tutorials/best-practices)

### Precompiled Bridge contract (aka PowPeg or Legacy Bridge)

We use a soldity interface called [Bridge.sol](./src//interfaces/Bridge.sol) to interact with the pre compiled contract, this information was obtained from the [FastBtc bridge contracts](https://github.com/rsksmart/liquidity-bridge-contract/tree/master)

### Partial Merkle Tree Generation

We use https://github.com/FairgateLabs/rust-bitvmx-transactions/blob/main/src/bin/bridge-pmt.rs in order to obtain the `merkleBraMerkle Branch PathnchPath` and `Merkle Branch Hashes` used in the bitcoin transaction SPV (proof).

Usage example:

```sh
BITVMX_ENV=mainnet cargo run --bin bridge-pmt -- 000000000000000000002be6a1ba34b051410802db784554909a7370ae139555 b079712132ca577d11d3ce0d849c4d1e7fc927ca83d7fe831701f4aa7cd66670
```

BITVMX_ENV indicates the bitcoin network, the first argument 000000000000000000002be6a1ba34b051410802db784554909a7370ae139555 is the `block hash` , the second argument b079712132ca577d11d3ce0d849c4d1e7fc927ca83d7fe831701f4aa7cd66670 is the `tx hash`

Result:

```js
...
Merkle Branch Path: 949
Merkle Branch Hashes [
    "0x480fd40f2e47eeea8edeef2f7f3e2c680642f748c989ed2e542fe5d28164da51",
    "0x95c002b26f393d620ca12515bb4ff266617f56efe6b944e5e284f5124a1310ea",
    "0x5c6e854f9a71ae76fd2ae7ee98b25cf452d49731a70e00bd10aca0bee7265b2e",
    "0xaa27307f38abf6c00f34941cefffcba573dc6eb4220e46b13a9230f49d2a7d20",
    "0x93835ab7468acbd3ba3baef1a014787d391a9a11cae31f06037ac87cfde469e5",
    "0x25877bd79f156e5f242142d34968aada8ac92cf0908aacc9f48313b6b2a73adb",
    "0xa1a1e0737442b3e1248e88c5a6cac8307cd3e788e654b20809529d7765b84e33",
    "0x232432f75c9a979619d3315d65634ac83c2c778cedfd4cdfdf05baf363c43c8c",
    "0xbb822f3484e435d95647c70e837f11fb5287cd4477acd021b462b0cb8b7cb893",
    "0x46f6681d15564294d83a040b5e42403d2d594d4a55aebecd1f5264be9b9f1563",
    "0xfe31a4dff5d25fa665b18afea5256f9f71cfdabdd55930eccdf418414cfefd99",
    "0x512113f66433c1db50f001198988b3a187390df8b52afb48cedae934ae022998",
]
...
```

Where hashes are the `Merkle Branch Hashes` and flags is the `Merkle Branch Path`

Result can be checked using the [RSK Explorer at Bridge Address](https://explorer.rootstock.io/address/0x0000000000000000000000000000000001000006?__ctab=Contract%20Interaction) with the method `26. getBtcTransactionConfirmations`.
`MAKE SURE YOU HAVE METAMASK CONNECTER` otherwise you'll the following error

```
Cannot read properties of null(reading 'getBtcTransactionsConfirmations')
```

## Security

We are using [Slither](https://github.com/crytic/slither) static analyzer to check for potentials threats. We are running it through the docker image [eth-security-toolbox](https://github.com/trailofbits/eth-security-toolbox/) from trail of bits.
Using the following command:

```sh
docker-compose up
```

## Troubleshooting

### ValidateCommandError

If you see something like

```
[FAIL: revert: Failed to run upgrade safety validation: /Users/pmprete/.npm/_npx/e9c2fe9985ed1095/node_modules/@openzeppelin/upgrades-core/dist/cli/validate/build-info-file.js:127
            throw new error_1.ValidateCommandError(`Build info file ${buildInfoFilePath} is not from a full compilation.`, () => PARTIAL_COMPILE_HELP);
                  ^

ValidateCommandError: Build info file out/build-info/001d9012b78cf83be88732141551bdb6.json is not from a full compilation.
```

Then recompile all contracts withthe following commands and try again:

```sh
forge clean && forge build
```
