# BitVMX Union Bridge Contracts

This repository contains the specifications and Solidity code for the Union Bridge Contracts.

## Table of Contents

### Development & Operations

- [Development](#development)
- [Tests and Reporting](#tests-and-reporting)
- [Release](#release)

### Project Documentation

- [How it Works](#how-it-works)
- [Smart Contracts Architecture](#smart-contracts-architecture)
- [Bitcoin Transactions](./bitcoin-transactions.md)
- [Musig2](#musig2---multi-signatures-on-bitcoin)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

---

## Development

### Pre requisites

- You'll need the [Rust](https://www.rust-lang.org/) compiler and Cargo, Rust's package manager. The easiest way to install both is by using [rustup.rs.](https://rustup.rs/)
- [Foundry v1.3.0](https://book.getfoundry.sh/getting-started/installation) running `foundryup -v v1.3.0`
- [Node.js LTS (22)](https://nodejs.org/en/download)

### Install dependencies

- Run `forge install` to install smart contract dependencies
- Run `npm install -g @openzeppelin/upgrades-core@1.44.0` to install open zepelin upgrade validations dependencies

### Best Practices

We are following [Foundry introduction](https://getfoundry.sh/introduction/overview) and here are the sections of:  
[best practices - writing contracts](https://getfoundry.sh/guides/best-practices/writing-contracts)  
[best practices - writing tests](https://getfoundry.sh/guides/best-practices/writing-tests)  
[best practices - writing scripts](https://getfoundry.sh/guides/best-practices/writing-scripts)  
[best practices - security](https://getfoundry.sh/guides/best-practices/security)  
[best practices - key management](https://getfoundry.sh/guides/best-practices/key-management)  
[best practices - commenting](https://getfoundry.sh/guides/best-practices/commenting)

### NatSpec

We use solidity [NatSpec format](https://docs.soliditylang.org/en/latest/natspec-format.html) in all interfaces, libraries, structs, events, errors, and both external and public, functions and variables.

### Precompiled Bridge contract (aka PowPeg or Legacy Bridge)

We use a soldity interface called [IBridge.sol](./src/interfaces/IBridge.sol) to interact with the pre compiled contract, this information was obtained from the [FastBtc bridge contracts](https://github.com/rsksmart/liquidity-bridge-contract/tree/master).
Since the pow peg bridge is not available locally, we use [BridgeMock.sol](./test/helpers/BridgeMock.sol)

### RbtcBridge - RSKIP-502 Intermediary Contract

The **RbtcBridge** is a critical intermediary contract that enables RBTC minting and burning operations through the RSK PowPeg Bridge, implementing [RSKIP-502](https://github.com/rsksmart/RSKIPs/blob/master/IPs/RSKIP502.md).

**Why RbtcBridge is needed:**

RSKIP-502 requires that the PowPeg Bridge authorize **only ONE contract address** for minting and burning RBTC. Since the Union Bridge architecture splits responsibilities between `PeginManager` (handles peg-ins) and `PegoutManager` (handles peg-outs), we need a single intermediary contract that both managers can use.

**Architecture:**

```
┌─────────────────┐
│  PowPeg Bridge  │ (authorizes only ONE address)
└────────┬────────┘
         │ authorizes
         ▼
┌─────────────────┐
│   RbtcBridge    │ (single authorized intermediary)
│  - mintRbtc()   │ ← Called by PeginManager during pegin acceptance
│  - burnRbtc()   │ ← Called by PegoutManager during pegout request
└────────┬────────┘
         │ authorized callers
    ┌────┴────┐
    ▼         ▼
┌──────────────┐  ┌──────────────┐
│ PeginManager │  │PegoutManager │
└──────────────┘  └──────────────┘
```

**Key Features:**
- **Access Control**: Only `PeginManager` can call `mintRbtc()`, only `PegoutManager` can call `burnRbtc()`
- **Gas Limit Protection**: RBTC transfers use a 100k gas limit to prevent DoS attacks
- **Upgradeable**: Uses UUPS pattern for future improvements
- **Reentrancy Protection**: Implements OpenZeppelin's `nonReentrant` modifier

See [RbtcBridge.sol](./src/RbtcBridge.sol) for implementation details.

## Tests and Reporting

### Unit test

You can run unit test with:

```sh
bash test.sh
```

### Integration test

You can run the local integration test suit with:

```sh
bash run.sh
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

### Gas usage

Also you can check the gas used the contracts:

```sh
bash shell/gas-report.sh
```

Contracts size needs to be lower than 24kb

## Release

Once we are code ready for a realease, we will run the following command:

```sh
bash release.sh
```

This will auto generate the [docs](./docs) and [bindings for the rust crate](./crate/src/bindings/)
Then we commit this changes and after they are merge we tag the release on github.

### Deployment

Use [deployment script](https://book.getfoundry.sh/guides/scripting-with-solidity#deploying-our-contract) to deploy:

```sh
bash shell/script/deploy/deploy.sh
```

It will ask for a private key interactively in order to perform the deployment. The address associated with that private key must have sufficient funds to complete the deployment.
If you want to deploy to a local network (regtest) use `deploy-local.sh`.

### RSKIP-502 PowPeg Bridge Configuration

After deploying the contracts to testnet or alphanet, you must configure the PowPeg Bridge to authorize the RbtcBridge contract for RBTC minting and burning operations.

#### Prerequisites

- Deployed contracts (see Deployment section above)
- RbtcBridge contract address from deployment
- Private key with authorization to configure the PowPeg Bridge
- `cast` CLI tool from Foundry

#### Step 1: Register RbtcBridge as Authorized Union Bridge Contract

The RbtcBridge must be registered as the single authorized union bridge contract:

```bash
# Replace placeholders with actual values:
# - <BRIDGE_ADDRESS>: RSK PowPeg Bridge address (0x0000000000000000000000000000000001000006)
# - <RBTC_BRIDGE_ADDRESS>: Your deployed RbtcBridge contract address
# - <RPC_URL>: Your RSK testnet/alphanet/mainnet RPC endpoint
# - <PRIVATE_KEY>: Private key with authorization rights

cast send 0x0000000000000000000000000000000001000006 \
  "setUnionBridgeContractAddressForTestnet(address)" \
  <RBTC_BRIDGE_ADDRESS> \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --legacy
```

#### Step 2: Verify Initial Locking Cap

Check the current locking cap:

```bash
cast call 0x0000000000000000000000000000000001000006 \
  "getUnionBridgeLockingCap()" \
  --rpc-url <RPC_URL>

# Expected output on alphanet: 400000000000000000000 (400 RBTC in wei)
```

**Note:** Alphanet already has an initial locking cap of 400 RBTC configured. If you need a higher cap, use `increaseUnionBridgeLockingCap()` (see "Increasing the Locking Cap" section below).

#### Step 3: Verify RbtcBridge Registration

Verify that the RbtcBridge was registered successfully:

```bash
# Verify RbtcBridge is registered as union bridge contract
cast call 0x0000000000000000000000000000000001000006 \
  "getUnionBridgeContractAddress()" \
  --rpc-url <RPC_URL>

# Expected output: Your RbtcBridge address (should match deployed address)
```

#### Increasing the Locking Cap

As bridge usage grows, you may need to increase the locking cap:

```bash
# RSKIP-502 allows cap increases up to 2x the current total cap
# Current total cap = current lockingCap + already minted amount

cast send 0x0000000000000000000000000000000001000006 \
  "increaseUnionBridgeLockingCap(uint256)" \
  <NEW_CAP_IN_WEI> \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --legacy
```

**Important:** RSKIP-502 enforces that cap increases:
- Must be greater than the current total cap (available + locked)
- Cannot exceed 2x the current total cap (security measure)

#### Local Testing (Anvil/Regtest)

For local testing with Anvil or Regtest, the deployment script automatically:
- Configures BridgeMock with RbtcBridge as the authorized union bridge
- Funds BridgeMock with 400 RBTC for testing
- Sets appropriate confirmations for fast testing
- **Note:** BridgeMock has a default `lockingCap = 400 ether` hardcoded, so Step 2 above is not needed locally

No manual configuration is required for local development. See `script/deploy/01_DeployImplAndProxy.s.sol` for implementation details.

### Rust crate with Bindings

To generate the new bindings for the smart contracts run :

```sh
bash bind.sh
```

It will automatically generate the rust files for the smart contracts using Alloy

### Docs

To generate the documentation using forge doc:

```sh
bash shell/generate-doc.sh
```

To view the generated documentation run:

```sh
bash doc.sh
```

---

## How it Works

The Union Bridge system uses a trust minimized committee approach to manage Bitcoin peg-in and peg-out operations. The process involves members applying to streams, forming committees, and creating packets for processing transactions.

### Key Concepts

- **Stream**: A stream in the Union Bridge is a logical channel that defines parameters such as denomination and operational rules for peg-in and peg-out flows. Streams allow the bridge to support multiple independent flows of assets, each with its own configuration. Committees, composed of operators, and watchtowers, are assigned to each packet within a stream.

- **Packet**: A packet represents a discrete operational period or batch within a stream, during which a specific committee is responsible for processing peg-in and peg-out requests. Each packet contains up to 100 slots. The creation of a new packet is triggered either when the current packet nears capacity or when no packets are available (e.g. at system start). However, the packet is only finalized once a new committee is formed to manage it. Packets track the lifecycle of their peg slots and handle the registration and processing of peg-in and peg-out operations. Committee members secure the packet by depositing security bonds.

- **Slot**: A slot represents a single peg-in or peg-out operation. It's a storage unit within a packet that holds a specific Bitcoin UTXO (Unspent Transaction Output) resulting from a successful peg-in. Slots are created on demand, and when first created, they enter the Prepared state, indicating that all dispute resolution information is in place and the slot is ready to be assigned to a peg-in request. These slots are later used to fulfill peg-out requests, ensuring that the Bitcoin funds are properly accounted for and can be transferred back to users during peg-out operations.

!["Streams Diagram"](./specs/imgs/streams.png)

A slot can have the following states:

- `Prepared`, when all the dispute resolution information is linked to the slot (setup completed). In this state the slot is ready to be assigned to a request peg-in operation.
- `Filled`, when the Committee members have confirmed and registered a peg-in. In this state the slot is ready for peg-out.
- `Locked`, when the slot is assigned to a peg-out operation.
- `Advanced`: when the operator advanced funds.
- `Completed`: when the peg-out is processed (happy path) or the operator receives the reimbursement after advance.

<img src="./specs/imgs/slots_transitions.png" alt="Slots transitions" width="400">

### Packet Creation Flow

The packet creation process follows four main phases:

#### Phase 1: Member Application

1. **Member applies to stream**: The member calls `applyToStream()` with their role (Operator/Watchtower) and public keys
2. **Validation**: CommitteeRegistry validates public keys and signatures
3. **Registration**: Member is registered and added as a candidate for their requested role
4. **Committee creation trigger**: When enough members apply (minimum 3 operators + 3 watchtowers and at least 10 total) AND `shouldCreateCommittee` for the stream is true AND there is no pending committee or the pending committee has expired, a pending committee is created

```mermaid
sequenceDiagram
    participant M as Member
    participant CR as CommitteeRegistry
    participant MR as MemberRegistry
    participant ENV as Environment

    Note over M,ENV: Phase 1: Member Application
    Note over M,ENV: Member applies to stream with role (Operator/Watchtower)

    M->>+CR: applyToStream(stream, OPERATOR, publicKeys, fundingUTXO)
    Note right of M: Sends bond amount + public keys + funding UTXO
    CR->>+MR: applyToStream(memberAddress, stream, OPERATOR, publicKeys, fundingUTXO)
    Note right of CR: Delegates to MemberRegistry
    MR->>MR: _validatePublicKeys()
    MR->>MR: _getOrRegisterMember()
    MR->>MR: _registerCandidateToStream()
    MR-->>-CR: NewSecurityBondDeposit event
    CR->>CR: _createCommitteeAfterApplyToStream()
    CR-->>-M: NewSecurityBondDeposit event

    Note over M,ENV: Additional members apply similarly...
    Note over M,ENV: Committee creation triggered when minimum requirements met AND no pending committee exists or the pending committee has expired
```

#### Phase 2: Committee Creation

1. **Automatic creation**: When the committee creation trigger is met (i.e. `shouldCreateCommittee` for the stream is true, and there is no pending committee or the pending committee has expired), the system automatically trys to create a committee.

   > `shouldCreateCommittee` is set to true when the stream is first created or when the current packet slot usage hits 80%.

2. **Member selection**: Uses Fisher-Yates shuffle to randomly select operators and watchtowers from candidates
3. **Committee composition**: Ensures at least 10 members have applied, including at least 3 operators and at least 3 watchtowers
4. **Pending committee creation**: Creates a pending committee with selected members and sets missingData counter

```mermaid
sequenceDiagram
    participant CR as CommitteeRegistry
    participant MR as MemberRegistry
    participant ENV as Environment

    Note over CR,ENV: Phase 2: Committee Creation
    Note over CR,ENV: Committee creation is triggered only when: at least 10 members have applied, including at least 3 operators and at least 3 watchtowers, shouldCreateCommittee for the stream is true, and there is no pending committee or the pending committee has expired
    Note over CR,ENV: System creates committee by selecting members

    CR->>CR: _createCommittee(streamId)
    CR->>+MR: selectCommittee(streamId, minWatchtowers, minOperators, committeeMemberCount)
    Note right of CR: Delegates member selection to MemberRegistry
    MR->>MR: _selectCommittee()
    Note right of MR: Check minimum requirements (3 operators + 3 watchtowers)
    MR->>MR: Randomly select operators from candidates
    Note right of MR: Use Fisher-Yates shuffle for selection
    MR->>MR: Randomly select watchtowers from candidates
    Note right of MR: Ensure at least 10 members selected
    MR-->>-CR: (CommitteeMember[], PendingCommitteeStatus)
    CR->>CR: Create pending committee with selected members
    CR->>CR: Set missingData counter to member count
    CR-->>ENV: NewPendingCommittee event
    Note right of CR: Pending committee ready for key deposits
```

#### Phase 3: Committee Formation

1. **Deposit communication data**: Each selected member in the pending committee deposits their communication data with call depositCommunicationData().
2. **Deposit aggregated key**: Each selected member in the pending committee deposits their aggregated key with call depositAggregatedKey().
3. **Key validation**: All members must provide the same aggregated key
4. **Committee completion**: When all selected members have deposited their keys (missingData reaches 0), the committee is ready

```mermaid
sequenceDiagram
    participant M as Member
    participant CR as CommitteeRegistry
    participant ENV as Environment

    Note over M,ENV: Phase 3: Committee Formation
    Note over M,ENV: Selected members deposit communication data and then aggregated keys for pending committee

    M->>+CR: depositCommunicationData(committeeId, communicationData)
    Note right of M: Provides encrypted IP/Port data
    CR->>CR: Validate member is in pending committee
    CR->>CR: Store communication data
    CR->>CR: Decrement missingCommunicationData counter
    CR-->>-M: MemberCommunicationDataDeposited event

    M->>+CR: depositAggregatedKey(committeeId, aggregatedKey)
    Note right of M: Provides aggregated public key (33 bytes)
    CR->>CR: Validate member is in pending committee
    CR->>CR: Store aggregated key
    CR->>CR: Decrement missingData counter
    CR-->>-M: MemberInfoDeposited event

    Note over M,ENV: All selected committee members deposit their communication data and keys...
    Note over M,ENV: When missingData reaches 0, committee is complete!
```

#### Phase 4: Committee Registration & Packet Creation

1. **Committee registration**: A unique committee ID is generated and the committee is registered
2. **Balance updates**: Pre-staked amounts are moved to staked amounts for all committee members
3. **Packet creation**: StreamManager creates a new packet with the committee
4. **Cleanup**: Pending committee data is cleaned up
5. **Committee ready**: The committee is now active and ready to handle peg-in and peg-out operations

```mermaid
sequenceDiagram
    participant CR as CommitteeRegistry
    participant MR as MemberRegistry
    participant SM as StreamManager
    participant PM as PegManager
    participant ENV as Environment

    Note over CR,ENV: Phase 4: Committee Registration & Packet Creation
    Note over CR,ENV: Committee is registered and new packet is created

    CR->>CR: Generate committeeId (hash of streamId + packetNumber)
    CR->>+MR: removeCandidatesAndUpdateBalance(committeeMembers, streamDenomination, packetNumber)
    Note right of CR: Delegates balance updates to MemberRegistry
    MR->>MR: Move pre-staked to staked for all members
    MR->>MR: Remove members from candidates pool
    MR-->>-CR: Balance updates completed
    CR->>CR: _registerCommittee()
    CR-->>ENV: NewCommittee event
    CR->>+SM: createNewPacket(streamId, committeeId, aggregatedKey)
    SM->>SM: Create new packet with committee
    SM-->>-CR: Packet created
    CR->>CR: _deletePendingCommittee()
    Note right of CR: Clean up pending committee data

    Note over CR,ENV: Committee Ready for Operations
    Note over CR,ENV: Committee is now active and ready for peg operations
```

## Peg-In Process (Bitcoin → RSK)

### Phase 1: Request Peg-In

1. **User generates temporary address**: User calls `getTemporaryPeginAddress()` to get a Bitcoin committee address for deposit
2. **User deposits BTC**: User sends Bitcoin to the generated temporary address, including an OP_RETURN output with the RSK address where they want to receive the funds. For detailed information about the [REQUEST_PEGIN_TX](./bitcoin-transactions.md#1-request_pegin_tx-request-pegin-transaction) transaction structure, inputs/outputs, and Taproot script details.
3. **Member submits request**: A committee member who monitors the Bitcoin network calls `requestPegin()` with the Bitcoin transaction and SPV proof
4. **System validates**: System validates the transaction and stores the request
5. **Generate accept transaction**: System generates the Bitcoin accept peg-in transaction and emits an event with the signature hash for committee members to sign

```mermaid
sequenceDiagram
    participant U as User
    participant M as Member
    participant PIM as PeginManager
    participant ENV as Environment

    Note over U,ENV: Phase 1: Request Peg-In
    Note over U,ENV: User requests to peg-in Bitcoin to RSK

    U->>+PIM: getTemporaryPeginAddress(rootstockAddress, value, btcReimbursementPubKey)
    PIM-->>-U: temporaryPeginAddress

    U->>U: Send BTC to temporaryPeginAddress
    Note right of U: User deposits Bitcoin to the generated address

    M->>+PIM: requestPegin(btcTxSPVProof)
    Note right of M: Committee member monitors Bitcoin network and submits transaction
    PIM->>PIM: Validate BTC transaction and SPV proof
    PIM->>PIM: Store pegin request data
    PIM->>PIM: Generate accept peg-in transaction
    PIM-->>-M: PeginRequested event
    Note right of PIM: Event includes signature hash for committee members
```

### Phase 2: Committee Signatures for Peg-In

1. **Operators register take tx hash**: Committee members with the operator role call `addOperatorTakeTxHash()` to register the operator take transaction hash before signatures are collected. For detailed information about the [OPERATOR_TAKE_TX](./bitcoin-transactions.md#2-operator_take_tx-operator-take-transaction) transaction structure, inputs/outputs, and spending conditions.
2. **Create accept pegin transaction**: System creates the ACCEPT_PEGIN_TX transaction that will spend the REQUEST_PEGIN_TX output. For detailed information about the [ACCEPT_PEGIN_TX](./bitcoin-transactions.md#1-accept_pegin_tx-accept-pegin-transaction) transaction structure, inputs/outputs, and committee signature requirements.
3. **Committee members sign**: Each committee member signs the accept peg-in transaction using `addMemberNonce()` and `addMemberSignature()` from SignatureManager
4. **Signature collection**: Signatures are collected and validated by the SignatureManager
5. **Ready for broadcast**: Once all committee members have signed, the signed transaction is ready to be broadcast to the Bitcoin network

```mermaid
sequenceDiagram
    participant O as Operator
    participant M as Member
    participant SM as SignatureManager
    participant ENV as Environment

    Note over O,ENV: Phase 2: Committee Signatures for Peg-In
    Note over O,ENV: Operators register the operator take transaction hash before signatures

    loop For each operator
        O->>+SM: addOperatorTakeTxHash(acceptPeginTxid, operatorTakeTxid)
        Note right of O: Operator registers the operator take transaction hash
        SM-->>-ENV: OperatorTakeTxHashAdded event
    end

    Note over M,ENV: Committee members sign the accept peg-in transaction

    loop For each committee member
        M->>+SM: addMemberNonce(hashToSign, nonce)
        Note right of M: Member provides their nonce
        SM->>SM: Store member nonce
        SM-->>-M: Nonce stored
        M->>+SM: addMemberSignature(hashToSign, signature)
        Note right of M: Member signs the accept peg-in transaction hash
        SM->>SM: Validate and store signature
        SM-->>-ENV: MemberSignatureAdded event
    end

    SM-->>ENV: AllSignaturesCollected event
    Note right of SM: Event emitted when all members have signed
    Note right of SM: Signed transaction is ready for broadcast to Bitcoin network
```

### Phase 3: Accept Peg-In

1. **Member submits accept**: A committee member who monitors the Bitcoin network calls `acceptPegin()` with the broadcasted transaction and SPV proof
2. **System validates**: System validates the accept transaction and proof
3. **Store UTXO in slot**: The accept peg-in UTXO is stored in a slot for future use in peg-out operations
4. **Mint RBTC**: PeginManager calls `RbtcBridge.mintRbtc()` which requests RBTC from the PowPeg Bridge and sends it to the user's RSK address

```mermaid
sequenceDiagram
    participant M as Member
    participant PIM as PeginManager
    participant ENV as Environment

    Note over M,ENV: Phase 3: Accept Peg-In
    Note over M,ENV: Member submits the broadcasted accept peg-in transaction

    M->>+PIM: acceptPegin(btcTxSPVProof)
    Note right of M: Committee member monitors Bitcoin network and submits broadcasted transaction
    PIM->>PIM: Validate BTC transaction and SPV proof
    PIM->>PIM: Validate committee signatures
    PIM->>PIM: Process pegin acceptance
    PIM->>PIM: Mint RBTC to user via RbtcBridge
    PIM-->>-ENV: PeginAccepted event
    Note right of PIM: BTC is now pegged-in to RSK, RBTC minted to user's address
```

## Peg-Out Process (RSK → Bitcoin)

### Phase 1: Peg-Out Request

1. **User requests pegout**: User calls `tryPegout()` with the Bitcoin public key where they want to receive funds and sends RBTC equal to the stream denomination
2. **Validate request**: System validates the Bitcoin compressed public key format and amount limits
3. **Store request**: Peg-out request is stored with all the necessary data
4. **Generate user take transaction**: System generates the Bitcoin user take transaction using the stored UTXO from the previous accept peg-in and emits an event with the signature hash for committee members to sign
5. **Burn RBTC**: PegoutManager calls `RbtcBridge.burnRbtc()` which releases RBTC back to the PowPeg Bridge, preparing for the Bitcoin peg-out

```mermaid
sequenceDiagram
    participant U as User
    participant POM as PegoutManager
    participant ENV as Environment

    Note over U,ENV: Phase 1: Peg-Out Request
    Note over U,ENV: User requests to peg-out RBTC to Bitcoin

    U->>+POM: tryPegout(userPubKey)
    Note right of U: Provides Bitcoin public key and sends RBTC
    POM->>POM: Validate request
    POM->>POM: Store pegout request data
    POM->>POM: Generate user take transaction
    POM->>POM: Burn RBTC via RbtcBridge
    POM-->>-ENV: PegoutRequested event
    Note right of POM: Event includes signature hash for committee members
    Note right of POM: RBTC burned and returned to PowPeg Bridge via RbtcBridge
```

### Phase 2: Committee Signatures for Peg-Out

1. **Committee members sign**: Each committee member signs the user take pegout hash and registers their signature with the SignatureManager using `addMemberNonce()` and `addMemberSignature()`
2. **Signature validation**: System tracks when all signatures are collected
3. **Emit completion event**: System emits an event when all committee members have signed

```mermaid
sequenceDiagram
    participant M as Member
    participant SM as SignatureManager
    participant ENV as Environment

    Note over M,ENV: Phase 2: Committee Signatures for Peg-Out
    Note over M,ENV: Committee members sign the user take pegout

    loop For each committee member
        M->>+SM: addMemberNonce(hashToSign, nonce)
        Note right of M: Member provides their nonce
        SM->>SM: Store member nonce
        SM-->>-M: Nonce stored
        M->>+SM: addMemberSignature(hashToSign, signature)
        Note right of M: Member signs user take pegout hash
        SM->>SM: Validate and store signature
        SM-->>-ENV: MemberSignatureAdded event
    end

    SM->>SM: Signature validation - The system controls that all signatures are collected.
    SM-->>ENV: AllSignaturesCollected event
    Note right of SM: Event emitted when all members have signed
```

### Phase 3: Register Peg-Out

#### Normal Case: UserTake (Take0) - All Members Signed

1. **Execute pegout**: Member executes the Bitcoin transaction sending BTC to the user's Bitcoin address when all signatures are collected. For detailed information about the [USER_TAKE_TX](./bitcoin-transactions.md#1-user_take_tx-user-take-transaction) transaction structure, inputs/outputs, and spending conditions.
2. **Submit BTC transaction**: Member calls `registerUserTake()` with the Bitcoin transaction and SPV proof
3. **Validate transaction**: System validates the BTC transaction and proof
4. **Validate signatures**: Committee signatures are validated
5. **Peg-out Registered**: System emits an event PegoutRegistered informing that RBTC is now linked to Bitcoin

```mermaid
sequenceDiagram
    participant M as Member
    participant POM as PegoutManager
    participant ENV as Environment

    Note over M,ENV: Normal Case: UserTake (Take0) - All Members Signed
    Note over M,ENV: Member executes pegout and registers it

    M->>M: Bitcoin pegout transaction
    Note right of M: BTC sent to user's Bitcoin address when all signatures collected

    M->>+POM: registerUserTake(btcTxSPVProof)
    Note right of M: Member calls `registerUserTake()` with the Bitcoin transaction and SPV proof
    POM->>POM: Validate BTC transaction and SPV proof
    POM->>POM: Validate committee signatures
    POM-->>-ENV: PegoutRegistered event
    Note right of POM: RBTC is now pegged-out to Bitcoin
```

#### Alternative Case: Operator Take (Take1) - Not all members signed

If not all committee members sign within the timeout period:

1. **Trigger operator take**: A member calls `triggerOperatorTake()` to start the operator take process, which emits an event indicating which operator needs to do the funds advancement
2. **Operator advances funds**: An operator advances BTC to the user's Bitcoin address. For detailed information about the [ADVANCE_FUNDS_TX](./bitcoin-transactions.md#1-advance_funds_tx-advance-funds-transaction) transaction structure, inputs/outputs, and spending conditions.
3. **Broadcast Reimbursement Kickoff**: The operator broadcasts a Reimbursement Kickoff Bitcoin transaction
4. **Challenge period**: If no one challenges within the timeout period, the member proceeds
5. **Broadcast Operator Take transaction**: The operator broadcasts the Operator Take (Take1) Bitcoin transaction. For detailed information about the [OPERATOR_TAKE_TX](./bitcoin-transactions.md#2-operator_take_tx-operator-take-transaction) transaction structure, inputs/outputs, and spending conditions.
6. **Submit BTC transaction**: Operator calls `registerOperatorTake()` with the Bitcoin transaction and SPV proof
7. **Validate transaction**: System validates the BTC transaction and proof
8. **Peg-out Registered**: System emits an event PegoutRegistered informing that RBTC is now linked to Bitcoin via operator take

```mermaid
sequenceDiagram
    participant M as Member
    participant POM as PegoutManager
    participant ENV as Environment

    Note over M,ENV: Alternative: Operator Take (Take1) - not all members signed
    Note over M,ENV: When not all members sign within timeout

    M->>+POM: triggerOperatorTake(pegoutTxid)
    Note right of M: Member triggers operator take after timeout
    POM->>POM: Validate timeout and signatures status
    POM-->>-ENV: OperatorTakeTriggered event

    M->>M: Bitcoin user funds advancement
    Note right of M: Operator advances BTC to user's Bitcoin address

    M->>M: Bitcoin Reimbursement Kickoff
    Note right of M: Operator broadcasts Reimbursement Kickoff Bitcoin transaction

    Note over M,ENV: Challenge period timeout
    Note over M,ENV: If no one challenges within timeout period

    M->>M: Bitcoin Operator Take (Take1)
    Note right of M: Operator broadcasts the final Operator Take Bitcoin transaction

    M->>+POM: registerOperatorTake(btcTxSPVProof)
    Note right of M: Operator calls `registerOperatorTake()` with the Bitcoin transaction and SPV proof
    POM->>POM: Validate BTC transaction and SPV proof
    POM-->>-ENV: PegoutRegistered event
    Note right of POM: RBTC is now pegged-out to Bitcoin via operator take
```

---

## Fee Mechanism

The Union Bridge employs a fee mechanism to cover Bitcoin network transaction costs. Here's how fees work in the current implementation:

### Pegin Flow (Bitcoin → RSK)

1. **User sends BTC**: User sends the full stream denomination (e.g., 100,000 satoshis) to the temporary pegin address
2. **BTC transaction fees deducted**: The accept pegin transaction deducts fees for Bitcoin network operations:
   - `P2TR_FEE`: 335 satoshis (Taproot transaction fee)
   - `SPEED_UP_AMOUNT`: 540 satoshis (fee for speed-up output)
   - **Total deducted**: 875 satoshis
3. **RBTC minted**: User receives RBTC equivalent to `acceptPeginAmount = denomination - fees`
   - Example: 100,000 - 875 = **99,125 satoshis worth of RBTC**

### Pegout Flow (RSK → Bitcoin)

1. **User sends RBTC**: User must send the **full stream denomination** in RBTC (e.g., 100,000 satoshis worth)
2. **RBTC burned**: Contract burns only what was originally minted during pegin:
   - Burned amount: `acceptPeginAmount` (e.g., 99,125 satoshis worth)
   - See `PegoutManager.sol:110`
3. **Fee accumulation**: The difference between what the user sent and what was burned remains in the contract:
   - Accumulated fees: `msg.value - acceptPeginAmount` (e.g., 875 satoshis worth of RBTC)
   - These fees accumulate in `PegoutManager`

### Why This Design?

Users effectively pay BTC transaction fees twice:
- **Once in BTC** during the pegin (deducted from their Bitcoin deposit)
- **Once in RBTC** during the pegout (paid as part of the full denomination requirement)

This ensures the bridge system has funds to cover Bitcoin network fees for both pegin and pegout operations.

### Current Fee Distribution

**Status: Not yet implemented**

Currently, accumulated fees remain in the `PegoutManager` contract and can only be withdrawn by the contract owner.

**Future implementation:** Fees will be distributed to operators and watchtowers as compensation for their services in running the bridge, including:
- Operating committee members who sign transactions
- Watchtowers who monitor for disputes
- Operators who advance funds in timeout scenarios

### Fee Constants

Fee amounts are defined in `src/libraries/Constants.sol`:
- `P2TR_FEE = 335` satoshis
- `SPEED_UP_AMOUNT = 540` satoshis

**Note:** This is the initial implementation. Fee structure and distribution mechanisms may be refined in future versions based on operational requirements and economic analysis.

### TL;DR - Complete Example

Using the 0.001 BTC (100,000 satoshis) stream denomination:

**Pegin:**
- User sends: **100,000 sats** in BTC
- Pegin BTC tx fees deducted: **875 sats** (335 P2TR + 540 speed-up)
- User receives: **99,125 sats worth of RBTC**

**Pegout:**
- User sends: **100,000 sats worth of RBTC** (full denomination required)
- RBTC burned: **99,125 sats worth** (only what was minted)
- Fees kept in contract: **875 sats worth of RBTC**
- Pegout starts with the already-reduced amount: **99,125 sats BTC UTXO**
- Pegout BTC tx fees deducted: **~875 sats** (assuming similar network conditions)
- User receives: **~98,250 sats in BTC** (99,125 - 875)

**Total User Cost:**
- Lost to pegin fees: **875 sats** (paid in BTC during pegin)
- Lost to pegout RBTC fees: **875 sats** (paid in RBTC, kept by contract)
- Lost to pegout BTC network fees: **~875 sats** (deducted from the 99,125 sat UTXO)
- **Total: ~2,625 satoshis** for a complete round-trip (pegin + pegout)

---

## Smart Contracts Architecture

### Overview

The BitVMX Union Bridge is a sophisticated smart contract system that enables secure Bitcoin peg-in and peg-out operations between Bitcoin and Rootstock (RSK). The system uses a committee-based approach with multiple specialized contracts working together to manage the bridge operations.

### Smart Contracts Diagram

```mermaid
graph TB
    %% Core Contracts
    PIM[PeginManager<br/>Handles Bitcoin → RSK operations]
    POM[PegoutManager<br/>Handles RSK → Bitcoin operations]
    PMB[PegManagerBase<br/>Shared abstract base contract]
    PAM[PauseManager<br/>Centralized pause controller]
    BM[BitcoinManager<br/>Bitcoin address generation and validation]
    CR[CommitteeRegistry<br/>Committee formation and management]
    MR[MemberRegistry<br/>Member registration and balance tracking]
    SM[StreamManager<br/>Stream and packet management]
    SigM[SignatureManager<br/>Multi-signature operations]
    RB[RbtcBridge<br/>RSKIP-502 RBTC mint/burn intermediary]

    %% External Dependencies
    Bridge[RSK PowPeg Bridge<br/>External Precompiled Contract]

    %% Inheritance
    PIM -.inherits.-> PMB
    POM -.inherits.-> PMB

    %% RbtcBridge - RSKIP-502 Single Authorized Address
    Bridge -->|authorizes<br/>single address| RB
    RB -->|mintRbtc| PIM
    RB -->|burnRbtc| POM

    %% PeginManager Relationships
    PIM --> BM
    PIM --> CR
    PIM --> SM
    PIM --> SigM
    PIM -->|calls mintRbtc| RB

    %% PegoutManager Relationships
    POM --> BM
    POM --> CR
    POM --> SM
    POM --> SigM
    POM --> MR
    POM -->|calls burnRbtc| RB

    %% PauseManager Relationships
    PAM -.controls pause.-> PIM
    PAM -.controls pause.-> POM
    PAM -.controls pause.-> CR
    PAM -.controls pause.-> MR

    %% Other Relationships
    CR --> MR
    CR --> SM
    CR --> PIM
    CR --> POM

    MR --> SM
    MR --> CR

    SigM --> CR
    SigM --> PIM
    SigM --> POM

    SM --> PIM
    SM --> POM
    SM --> CR

    %% Styling
    classDef coreContract fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef baseContract fill:#c5e1a5,stroke:#33691e,stroke-width:2px
    classDef pauseContract fill:#f8bbd0,stroke:#880e4f,stroke-width:2px
    classDef bridgeContract fill:#ffe0b2,stroke:#e65100,stroke-width:3px
    classDef external fill:#fff3e0,stroke:#e65100,stroke-width:2px

    class PIM,POM,BM,CR,MR,SM,SigM coreContract
    class PMB baseContract
    class PAM pauseContract
    class RB bridgeContract
    class Bridge external
```

### Core Smart Contracts

#### 1. **PeginManager**

- **Purpose**: Manages peg-in operations from Bitcoin to Rootstock
- **Key Features**:
  - Handles Bitcoin peg-in requests with SPV proofs
  - Processes peg-in acceptance with committee signatures
  - Generates temporary Bitcoin addresses for deposits
  - Mints RBTC to users via RbtcBridge after successful peg-in
  - Coordinates with StreamManager for slot allocation
  - Integrates with CommitteeRegistry for committee management
  - Inherits shared functionality from PegManagerBase
- **Security Features**: Pausable (via PauseManager), UUPS upgradeable, non-reentrant

#### 2. **PegoutManager**

- **Purpose**: Manages peg-out operations from Rootstock to Bitcoin
- **Key Features**:
  - Processes peg-out requests and burns RBTC via RbtcBridge
  - Manages user take and operator take flows
  - Handles timeout-based operator advancement
  - Coordinates committee signatures for peg-outs
  - Integrates with MemberRegistry for operator management
  - Inherits shared functionality from PegManagerBase
- **Security Features**: Pausable (via PauseManager), UUPS upgradeable, non-reentrant

#### 3. **PegManagerBase**

- **Purpose**: Abstract base contract providing shared functionality for PeginManager and PegoutManager
- **Key Features**:
  - Centralizes common state variables (bitcoinManager, streamManager, committeeRegistry, signatureManager, rbtcBridge)
  - Provides shared initialization logic
  - Implements common setter functions (setStreamManager, setSignatureManager, setPauser)

#### 4. **RbtcBridge**

- **Purpose**: RSKIP-502 intermediary contract that serves as the single authorized address for RBTC minting and burning with the PowPeg Bridge
- **Key Features**:
  - Acts as the single authorized contract registered with the PowPeg Bridge (RSKIP-502 requirement)
  - Provides `mintRbtc()` function exclusively for PeginManager to mint RBTC during peg-in acceptance
  - Provides `burnRbtc()` function exclusively for PegoutManager to burn RBTC during peg-out requests
  - Implements strict access control: only authorized managers can call mint/burn functions
  - Enforces 100k gas limit on RBTC transfers to prevent DoS attacks
  - Handles all PowPeg Bridge error codes (cap exceeded, transfers disabled, unauthorized caller)
- **Security Features**: UUPS upgradeable, non-reentrant, owner-controlled manager address updates
- **Critical Role**: Without RbtcBridge, both managers cannot interact with PowPeg Bridge due to single-address constraint

#### 5. **BitcoinManager**

- **Purpose**: Handles Bitcoin address generation and transaction validation
- **Key Features**:
  - Creates temporary Bitcoin addresses for peg-in requests
  - Validates Bitcoin transactions and SPV proofs
  - Generates signature hashes for Bitcoin transactions
  - Manages Taproot addresses with key spend and script spend paths
- **Security Features**: UUPS upgradeable

#### 6. **CommitteeRegistry**

- **Purpose**: Manages committee formation, selection, and lifecycle
- **Key Features**:
  - Creates and manages committees for different Bitcoin denominations
  - Handles committee member selection and rotation
  - Manages pending committee formation with timeouts
  - Coordinates with MemberRegistry for member management
- **Security Features**: Pausable (via PauseManager), UUPS upgradeable, non-reentrant

#### 7. **MemberRegistry**

- **Purpose**: Manages member registration, applications, and balance tracking
- **Key Features**:
  - Handles member registration with public key validation
  - Manages security bond deposits and withdrawals
  - Tracks member balances (available, pre-staked, staked)
  - Supports member applications to different streams
- **Security Features**: Pausable (via PauseManager), UUPS upgradeable, non-reentrant

#### 8. **StreamManager**

- **Purpose**: Manages streams and packet allocation for different Bitcoin denominations
- **Key Features**:
  - Creates and manages streams for different Bitcoin amounts
  - Handles packet creation and slot allocation
  - Manages committee assignments to packets
  - Tracks stream usage and committee rotation
- **Security Features**: UUPS upgradeable

#### 9. **SignatureManager**

- **Purpose**: Manages multi-signature operations for committee members
- **Key Features**:
  - Handles Musig2 protocol for committee signatures
  - Manages signature collection for peg-in/peg-out operations
  - Tracks operator take transaction IDs
  - Coordinates with CommitteeRegistry for member verification
- **Security Features**: UUPS upgradeable

#### 10. **PauseManager**

- **Purpose**: Centralized pause controller for emergency stops
- **Key Features**:
  - Single control point for pausing all contracts
  - Coordinates pause/unpause across PeginManager, PegoutManager, CommitteeRegistry, and MemberRegistry
  - Owner-controlled with single transaction emergency stop
  - Provides system-wide pause status checking
- **Security Features**: UUPS upgradeable, owner access control

### Key Features and Security

#### Upgradeability

- All contracts use **UUPS (Universal Upgradeable Proxy Standard)** for upgradeability
- Only the contract owner can authorize upgrades
- Implementation contracts can be upgraded without changing proxy addresses

#### Pausability

- **PeginManager**, **PegoutManager**, **CommitteeRegistry**, and **MemberRegistry** are pausable
- **PauseManager** provides centralized pause control for all contracts
- Pause functionality allows emergency stops of critical operations with a single transaction
- Only PauseManager owner can pause/unpause the system
- All pausable contracts delegate pause authority to PauseManager

#### Access Control

- **BaseProxy** provides ownership functionality through OpenZeppelin's OwnableUpgradeable
- **AccessControl** contract provides role-based access control
- **PegManager** has administrative privileges over other contracts

#### Reentrancy Protection

- All contracts implement non-reentrant patterns
- External calls are made after state changes (checks-effects-interactions pattern)
- Reentrancy guards prevent recursive calls

#### Committee-Based Security

- Multi-signature operations using Musig2 protocol
- Committee rotation and member selection
- Security bonds and staking mechanisms
- Timeout-based committee formation

### Contract Interactions

1. **PeginManager** manages peg-in operations, coordinating with BitcoinManager, CommitteeRegistry, StreamManager, SignatureManager, and RbtcBridge for minting RBTC
2. **PegoutManager** manages peg-out operations, coordinating with BitcoinManager, CommitteeRegistry, StreamManager, SignatureManager, MemberRegistry, and RbtcBridge for burning RBTC
3. **RbtcBridge** serves as the single authorized intermediary between both managers and the PowPeg Bridge (RSKIP-502), handling all RBTC minting and burning operations
4. **PauseManager** controls pause state for PeginManager, PegoutManager, CommitteeRegistry, and MemberRegistry
5. **CommitteeRegistry** manages committee lifecycle and coordinates with MemberRegistry and StreamManager
6. **StreamManager** handles stream and packet management, working with CommitteeRegistry
7. **SignatureManager** processes multi-signature operations for committees
8. **BitcoinManager** provides Bitcoin-specific functionality as a utility contract
9. **MemberRegistry** manages member data and balances across all other contracts

### Deployment Architecture

The system is deployed using a proxy pattern where:

- Each contract has an implementation contract
- A proxy contract delegates calls to the implementation
- The proxy stores the state while the implementation contains the logic
- Upgrades are performed by changing the implementation address in the proxy

The deployment is created using the [deployment scripts](script/deploy/) and information about deployed contracts can be found in the [broadcast folder](broadcast/).

This architecture ensures security, upgradeability, and maintainability while providing a robust foundation for Bitcoin-RSK bridge operations.

---

## Musig2 - Multi-Signatures on Bitcoin

MuSig2 allows groups of mutually distrusting parties to cooperatively sign data and aggregate their signatures into a single aggregated signature which is indistinguishable from a signature made by a single private key. The group collectively controls an aggregated public key which can only create signatures if everyone in the group cooperates (AKA an *N-of-N multisignature scheme*). MuSig2 is optimized to support secure signature aggregation with only *two round-trips of network communication*.

Specifically we use the [smart contracts to verify Musig2](./src/Musig2.sol) partial signatures, in order to slash dishonest committee participants. We followed [rust musgi2 library](https://docs.rs/musig2/latest/musig2/) implementation that uses [BIP-0327: MuSig2 for BIP340-compatible Multi-Signatures](https://github.com/bitcoin/bips/blob/master/bip-0327.mediawiki), for creating and verifying signatures which validate under Bitcoin consensus rules.

### Musig2 Overview

If you’re not already familiar with MuSig2, the process of cooperative signing runs like so:

1. All signers share their public keys with one-another. The group computes an `aggregated public` key which they collectively control.

2. In the *first signing round*, signers generate and share nonces (random numbers) with one-another. These nonces have both secret and public versions. Only the public nonce (AKA PubNonce) should be shared, while the corresponding secret nonce (AKA SecNonce) must be kept secret.

3. Once every signer has received the public nonces of every other signer, each signer makes a partial signature for a message using their secret key and secret nonce.

4. In the *second signing round*, signers share their partial signatures with one-another. Partial signatures can be verified to place blame on misbehaving signers (but are not themselves unforgeable).

5. A valid set of partial signatures can be aggregated into a final signature, which is just a normal Schnorr signature, valid under the aggregated public key.

---

## Security

### Slither

We are using [Slither](https://github.com/crytic/slither) static analyzer to check for potentials threats. We are running it through the docker image [eth-security-toolbox](https://github.com/trailofbits/eth-security-toolbox/) from trail of bits.
Using the following command:

```sh
docker compose up
```

### Open Zeppelin upgrades plugin

We are also using [Open Zeppelin foundry upgrades](https://docs.openzeppelin.com/upgrades-plugins/foundry-upgrades) for deploying and managing upgradeable contracts, which includes upgrade safety validations.

## Troubleshooting

### ValidateCommandError

If you see something like

```sh
[FAIL: revert: Failed to run upgrade safety validation: /Users/pmprete/.npm/_npx/e9c2fe9985ed1095/node_modules/@openzeppelin/upgrades-core/dist/cli/validate/build-info-file.js:127
            throw new error_1.ValidateCommandError(`Build info file ${buildInfoFilePath} is not from a full compilation.`, () => PARTIAL_COMPILE_HELP);
                  ^

ValidateCommandError: Build info file out/build-info/001d9012b78cf83be88732141551bdb6.json is not from a full compilation.
```

Then recompile all contracts with the following commands and try again:

```sh
forge clean && forge build
```
