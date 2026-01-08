# Union Bridge Bitcoin Transactions Documentation

This document describes the Bitcoin transactions created by the Union Bridge protocols in the BitVMX system. The Accept PegIn Protocol creates several interconnected transactions that handle the acceptance of peg-in requests and provide mechanisms for operators to claim funds.

## Table of Contents

- [Union Bridge Context](#union-bridge-context)
- [Overview](#overview)
  - [User Transaction](#user-transaction)
  - [Reject Pegin](#reject-pegin)
  - [Accept PegIn Protocol](#accept-pegin-protocol)
  - [User Take Protocol](#user-take-protocol)
  - [Advance Funds Protocol](#advance-funds-protocol)
  - [Transaction Relationships](#transaction-relationships)
- [Transaction Lifecycle](#transaction-lifecycle)
  - [Pre-Signing Mechanism](#pre-signing-mechanism)
  - [Transaction Flow Context](#transaction-flow-context)
- [Accept PegIn Protocol - Transaction Details](#accept-pegin-protocol---transaction-details)
  - [1. REQUEST_PEGIN_TX (Request PegIn Transaction)](#1-request_pegin_tx-request-pegin-transaction)
    - [Inputs](#request_pegin_tx-inputs)
    - [Outputs](#request_pegin_tx-outputs)
    - [Transaction Flow](#request_pegin_tx-transaction-flow)
  - [1. USER_REIMBURSMENT_TX (User Reimbursement Transaction)](#1-user_reimbursment_tx-user-reimbursement-transaction)
    - [Inputs](#user_reimbursment_tx-inputs)
    - [Outputs](#user_reimbursment_tx-outputs)
    - [Transaction Flow](#user_reimbursment_tx-transaction-flow)
  - [1. REJECT_PEGIN_TX (Reject Pegin Transaction)](#1-reject_pegin_tx-reject-pegin-transaction)
    - [Inputs](#reject_pegin_tx-inputs)
    - [Outputs](#reject_pegin_tx-outputs)
    - [Transaction Flow](#reject_pegin_tx-transaction-flow)
  - [1. ACCEPT_PEGIN_TX (Accept PegIn Transaction)](#1-accept_pegin_tx-accept-pegin-transaction)
    - [Inputs](#accept_pegin_tx-inputs)
    - [Outputs](#accept_pegin_tx-outputs)
    - [Transaction Flow](#accept_pegin_tx-transaction-flow)
  - [2. OPERATOR_TAKE_TX (Operator Take Transaction)](#2-operator_take_tx-operator-take-transaction)
    - [Inputs](#operator_take_tx-inputs)
    - [Outputs](#operator_take_tx-outputs)
    - [Transaction Flow](#operator_take_tx-transaction-flow)
  - [3. OPERATOR_WON_TX (Operator Won Transaction)](#3-operator_won_tx-operator-won-transaction)
    - [Inputs](#operator_won_tx-inputs)
    - [Outputs](#operator_won_tx-outputs)
    - [Transaction Flow](#operator_won_tx-transaction-flow)
  - [Accept PegIn Protocol Integration with Dispute Core](#accept-pegin-protocol-integration-with-dispute-core)
- [Dispute Core Protocol - Transaction Details](#dispute-core-protocol---transaction-details)
  - [1. REIMBURSEMENT_KICKOFF_TX (Reimbursement Kickoff Transaction)](#1-reimbursement_kickoff_tx-reimbursement-kickoff-transaction)
    - [Inputs](#reimbursement_kickoff_tx-inputs)
    - [Outputs](#reimbursement_kickoff_tx-outputs)
    - [Transaction Flow](#reimbursement_kickoff_tx-transaction-flow)
    - [Dispute Core Protocol Integration with Accept PegIn](#dispute-core-protocol-integration-with-accept-pegin)
  - [2. CHALLENGE_TX (Challenge Transaction)](#2-challenge_tx-challenge-transaction)
    - [Inputs](#challenge_tx-inputs)
    - [Outputs](#challenge_tx-outputs)
    - [Transaction Flow](#challenge_tx-transaction-flow)
    - [CHALLENGE_TX Registration and Validation](#challenge_tx-registration-and-validation)
    - [CHALLENGE_TX Integration with Dispute Resolution](#challenge_tx-integration-with-dispute-resolution)
- [User Take Protocol - Transaction Details](#user-take-protocol---transaction-details)
  - [1. USER_TAKE_TX (User Take Transaction)](#1-user_take_tx-user-take-transaction)
    - [Inputs](#user_take_tx-inputs)
    - [Outputs](#user_take_tx-outputs)
    - [Transaction Flow](#user_take_tx-transaction-flow)
- [Advance Funds Protocol - Transaction Details](#advance-funds-protocol---transaction-details)
  - [1. ADVANCE_FUNDS_TX (Advance Funds Transaction)](#1-advance_funds_tx-advance-funds-transaction)
    - [Inputs](#advance_funds_tx-inputs)
    - [Outputs](#advance_funds_tx-outputs)
    - [Transaction Flow](#advance_funds_tx-transaction-flow)
  - [Advance Funds Protocol Integration with Dispute Core](#advance-funds-protocol-integration-with-dispute-core)
- [Glossary](#glossary)
  - [Transaction Types](#transaction-types)
  - [Key Types](#key-types)
  - [Transaction Output Types](#transaction-output-types)
  - [Spending Modes](#spending-modes)
  - [Fee Structure](#fee-structure)
  - [Protocol Terms](#protocol-terms)

## Union Bridge Context

The **Accept PegIn Protocol** is part of the larger Union Bridge system that facilitates cross-chain asset transfers between Bitcoin and Rootstock:

- **REQUEST_PEGIN_TX** and **ACCEPT_PEGIN_TX** are part of the **peg-in flow** (Bitcoin → Rootstock)
- **USER_REIMBURSEMENT_TX** and **REJECT_PEGIN_TX** cancel the **peg-in flow** (Bitcoin → Rootstock)
- **USER_TAKE_TX**, **OPERATOR_TAKE_TX**, and **OPERATOR_WON_TX** are part of the **peg-out flow** (Rootstock → Bitcoin)
- **USER_TAKE_TX** is the **common case** for peg-out (optimistic path)
- **OPERATOR_TAKE_TX** is the **fallback** when not all committee signatures are available
- **OPERATOR_WON_TX** is the **disputed fallback** when operator transactions are challenged and operator wins

## Overview

The Union Bridge system includes multiple BitVMX protocols. This document covers the following BitVMX union protocols and their transaction types:

### User Transaction

1. **REQUEST_PEGIN_TX** - Initial transaction created by user to request peg-in (peg-in flow)

2. **USER_REIMBURSEMENT_TX** - User sends this transaction after a time window to recover the funds

### Reject Pegin

1. **REJECT_PEGIN_TX** - Committee members can reject a pegin transaction to avoid accepting a pegin.

### Accept PegIn Protocol

1. **ACCEPT_PEGIN_TX** - Main transaction that accepts the peg-in request (peg-in flow)
2. **OPERATOR_TAKE_TX** - Fallback transaction allowing operators to claim funds (peg-out flow, one per operator)
3. **OPERATOR_WON_TX** - Disputed fallback transaction for operators to claim funds after winning a challenge (peg-out flow, one per operator)

### User Take Protocol

1. **USER_TAKE_TX** - Transaction allowing users to claim their portion of peg-in funds (peg-out flow, **common case**)

### Advance Funds Protocol

1. **ADVANCE_FUNDS_TX** - Transaction allowing operators to advance funds to users before executing operator take transactions (peg-out flow, **proof of payment**)

### Dispute Core Protocol

1. **REIMBURSEMENT_KICKOFF_TX** - Transaction that enables operators to claim funds through OPERATOR_TAKE_TX (peg-out flow, one per operator per slot)
2. **CHALLENGE_TX** - Transaction that allows committee members to challenge operator actions if they detect incorrect behavior (peg-out flow, dispute resolution)
3. **REVEAL_INPUT_TX** - Transaction that allows operators to reveal the input (slot ID signature) during dispute resolution, proving they correctly advanced funds (peg-out flow, dispute resolution)

### Transaction Relationships

The following diagram shows how all transactions across the different protocols relate to each other:

```mermaid
graph TD
    A[REQUEST_PEGIN_TX<br/>User Transaction<br/>created by user] -->|Output 0 and 2: Key path<br/>spends with committee aggregated key| B[ACCEPT_PEGIN_TX<br/>Accept PegIn Protocol]
    A -->|Output 0: Script path<br/>spends with timelock| O[USER_REIMBURSEMENT_TX<br/>User Transaction<br/>User recovers funds]
    A -->|Output 2: Script path<br/>spends with dispute key| P[REJECT_PEGIN_TX<br/>Reject Pegin<br/>Committee member rejects pegin]
    B -->|Output 0| C[USER_TAKE_TX<br/>User Take Protocol<br/>Common Case]
    B -->|Output 0| D[OPERATOR_TAKE_TX<br/>Accept PegIn Protocol<br/>Fallback]
    B -->|Output 0| E[OPERATOR_WON_TX<br/>Accept PegIn Protocol<br/>Disputed Fallback]
    B -->|Output 2| F[User speedup P2WPKH<br/>Accept PegIn Protocol]
    
    %% Advance Funds Protocol
    G[ADVANCE_FUNDS_TX<br/>Advance Funds Protocol<br/>Operator advances funds to user] -->|Proof of payment| M
    
    %% Dispute Core Protocol
    I[Dispute Core<br/>OP_INITIAL_DEPOSIT_TX] -->|spends with Winternitz signature| M[REIMBURSEMENT_KICKOFF_TX<br/>Dispute Core Protocol]
    M -->|Output 0: OPERATOR_TAKE_ENABLER| J[OPERATOR_TAKE_TX input 1<br/>Accept PegIn Protocol]
    M -->|Output 0| N[CHALLENGE_TX<br/>Dispute Core Protocol<br/>Challenge operator actions]
    N -->|Output 0: REVEAL_INPUT Output| K[REVEAL_INPUT_TX<br/>Dispute Core Protocol<br/>Operator reveals input]
    K -->|Output 0: OPERATOR_WON_ENABLER| L[OPERATOR_WON_TX input 1<br/>Accept PegIn Protocol]
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#e8f5e8
    style D fill:#e8f5e8
    style E fill:#e8f5e8
    style F fill:#fff3e0
    style G fill:#fff3e0
    style I fill:#fce4ec
    style K fill:#fce4ec
    style M fill:#fce4ec
    style N fill:#fce4ec
    style O fill:#ffe0b2
    style P fill:#ffe0b2
```

**Prerequisites**: The Accept PegIn Protocol requires that a **REQUEST_PEGIN_TX** transaction must be created by the user and confirmed on the blockchain before the ACCEPT_PEGIN_TX can be executed, as it serves as the input source for the accept transaction.

## Peg-Out Flow with Rootstock Contract Integration

The peg-out flow involves both Bitcoin transactions and Rootstock smart contract calls. The following diagram shows the complete sequence:

```mermaid
sequenceDiagram
    participant Op as Operator
    participant BTC as Bitcoin Blockchain
    participant RSK as Rootstock Contract
    participant User as User

    Note over Op,RSK: Operator Selected (Status: OP_SELECTED)
    
    Op->>BTC: 1. Dispatch ADVANCE_FUNDS_TX
    BTC-->>Op: Transaction mined
    Op->>RSK: 2. registerAdvanceFunds(SPV proof)
    RSK-->>Op: Status: ADVANCED<br/>Event: AdvanceFundsRegistered
    RSK->>User: Funds advanced
    
    Op->>BTC: 3. Dispatch REIMBURSEMENT_KICKOFF_TX
    BTC-->>Op: Transaction mined
    Op->>RSK: 4. registerReimbursementKickoff(SPV proof)
    RSK-->>Op: Status: KICKOFF<br/>Event: ReimbursementKickoffRegistered
    
    Note over Op,BTC: Wait for long timelock expiry
    
    Op->>BTC: 5. Dispatch OPERATOR_TAKE_TX
    BTC-->>Op: Transaction mined
    Op->>RSK: 6. registerOperatorTake(SPV proof)
    RSK-->>Op: Status: COMPLETED<br/>Event: PegoutRegistered
```

**Key Steps**:

1. **ADVANCE_FUNDS_TX**: Operator dispatches transaction on Bitcoin to advance funds to user
2. **registerAdvanceFunds**: Operator submits SPV proof to Rootstock contract; status changes to `ADVANCED`
3. **REIMBURSEMENT_KICKOFF_TX**: Operator dispatches transaction on Bitcoin to enable OPERATOR_TAKE_TX
4. **registerReimbursementKickoff**: Operator submits SPV proof to Rootstock contract; status changes to `KICKOFF`
5. **OPERATOR_TAKE_TX**: After long timelock expires, operator dispatches transaction on Bitcoin to claim funds
6. **registerOperatorTake**: Operator submits SPV proof to Rootstock contract; status changes to `COMPLETED`

**Contract Validations**:

- **registerAdvanceFunds**: Validates caller is selected operator, verifies output amounts and OP_RETURN data
- **registerReimbursementKickoff**: Validates caller is selected operator, verifies ADVANCE_FUNDS_TX was previously registered, checks block height ordering
- **registerOperatorTake**: Validates inputs connect to ACCEPT_PEGIN_TX and registered REIMBURSEMENT_KICKOFF_TX, verifies txid matches pre-registered transaction

## Transaction Lifecycle

### Pre-Signing Mechanism

All transactions in the Accept PegIn Protocol are **pre-signed** during the protocol setup phase:

- **Committee Participants**: All committee members pre-sign all transactions during Accept PegIn Protocol setup
- **Operator Exclusion**: The specific operator who will later execute their transaction does NOT pre-sign their own OPERATOR_TAKE_TX or OPERATOR_WON_TX
- **Broadcast Control**: Operators can later add their signature and broadcast their transactions when needed
- **Security**: This ensures that operators cannot be forced to broadcast transactions against their will

### Transaction Flow Context

```mermaid
graph TD
    A[User send<br/>REQUEST_PEGIN_TX<br/>Peg-in Flow] --> B[ACCEPT_PEGIN_TX<br/>Peg-in Flow]
    B --> C[USER_TAKE_TX<br/>Peg-out Flow - Common Case]
    B --> D[OPERATOR_TAKE_TX<br/>Peg-out Flow - Fallback]
    B --> E[OPERATOR_WON_TX<br/>Peg-out Flow - Disputed Fallback]
    
    F[Pre-signed by Committee] --> B
    F --> C
    F --> D
    F --> E
    
    G[Operator Signs Later] --> D
    G --> E
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#e8f5e8
    style D fill:#fff3e0
    style E fill:#fce4ec
    style F fill:#fff3e0
    style G fill:#fce4ec
```

**Key Points**:

- **User Responsibility**: User creates, signs, and broadcasts REQUEST_PEGIN_TX to initiate the protocol
- **Peg-in Flow**: REQUEST_PEGIN_TX (created and signed by user) → ACCEPT_PEGIN_TX (Bitcoin to Rootstock)
- **Peg-out Flow**: USER_TAKE_TX (common case), OPERATOR_TAKE_TX (fallback), OPERATOR_WON_TX (disputed fallback) (Rootstock to Bitcoin)
- **Simultaneous Creation**: In each protocol, all transactions corresponding to that protocol are created together during setup
- **Selective Execution**: OPERATOR_TAKE_TX and OPERATOR_WON_TX peg-out transactions wait for appropriate conditions. The other are brodcasted is immediately after setup

## Accept PegIn Protocol - Transaction Details

### 1. REQUEST_PEGIN_TX (Request PegIn Transaction)

**Purpose**: Initial transaction created by the user to request a peg-in operation (Bitcoin → Rootstock). This transaction must be created, signed, and broadcast by the user before the Accept PegIn Protocol can proceed.

#### REQUEST_PEGIN_TX Inputs

##### Input 0: User's Bitcoin UTXO

- **Type**: Any Bitcoin input type (P2PKH, P2SH, P2WPKH, P2TR, etc.)
- **Spend Mode**: Depends on input type (KeyOnly, Script path, etc.)
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: User's private key corresponding to the UTXO
- **Previous Transaction**: User's existing Bitcoin transaction output
- **Description**: Spends the user's Bitcoin UTXO to fund the peg-in request

#### REQUEST_PEGIN_TX Outputs

##### Output 0: PegIn Request Output

- **Type**: Taproot (P2TR)
- **Amount**: `pegin_amount`
- **Key**: Committee aggregated key (`take_aggregated_key`)
- **Leaves**: Contains timelock and OP_RETURN script leaves
- **Purpose**: Main output that will be spent by ACCEPT_PEGIN_TX
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Contains two script leaves:
    1. **Timelock Script**: `OP_1 <TIMELOCK_BLOCKS> OP_CHECKSEQUENCEVERIFY OP_DROP <reimbursement_pubkey> OP_CHECKSIG` (1 block timelock for user reimbursement)
    2. **OP_RETURN Script**: `OP_RETURN <rootstock_address_bytes><amount_bytes>` (contains Rootstock address and amount data)
  - **REQUEST_PEGIN_TX Script Tree**:

    ```mermaid
    graph TD
        A[REQUEST_PEGIN_TX Taproot Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf 1: Timelock Script]
        C --> E[Leaf 2: OP_RETURN Script]
        
        D --> F["OP_1 <TIMELOCK_BLOCKS> OP_CHECKSEQUENCEVERIFY OP_DROP <reimbursement_pubkey> OP_CHECKSIG"]
        E --> G["OP_RETURN <rootstock_address_bytes><amount_bytes><br/>vec![rootstock_address, value.to_be_bytes().as_slice()].concat()"]
        
        style A fill:#e1f5fe
        style B fill:#f3e5f5
        style C fill:#e8f5e8
        style D fill:#fff3e0
        style E fill:#fff3e0
    ```

##### Output 1: OP_RETURN Output

- **Type**: OP_RETURN
- **Amount**: 0 sats
- **Purpose**: Contains RSK pegin metadata for transaction monitoring
- **Data Format**: `RSK_PEGIN + packet_number + rootstock_address + reimbursement_xpk`
- **Description**: This output contains structured data that allows the system to detect and monitor the RSK pegin transaction
- **OP_RETURN Data Structure**:
  - **Prefix**: `RSK_PEGIN` (9 bytes)
  - **Packet Number**: `packet_number` (8 bytes, big-endian)
  - **Rootstock Address**: `rootstock_address` (20 bytes)
  - **Reimbursement XPK**: `reimbursement_pubkey` (32 bytes)
  - **Total Size**: 69 bytes

##### Output 2: Pegin Request Accept Enabler

- **Type**: Taproot (P2TR)
- **Amount**: `ENABLER_AMOUNT` (540 sats)
- **Key**: Committee aggregated key (`take_aggregated_key`)
- **Leaves**: Contains script leaves for each committee member's dispute key
- **Purpose**: Enabler output that can be consumed by ACCEPT_PEGIN_TX (via key path) or REJECT_PEGIN_TX (via script path with dispute key) to control whether the pegin can be accepted
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending at accept pegin
  - **Script Tree**: Contains multiple script leaves, one per committee member dispute key to reject the pegin:
    - **verify_signature Script**: `<dispute_xonly_pubkey> OP_CHECKSIG`
  - **REQUEST_PEGIN_TX Enabler Script Tree**:

    ```mermaid
    graph TD
        A[REQUEST_PEGIN_TX Enabler Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf N: verify_signature Script]
        
        D --> E["<dispute_xonly_pubkey> OP_CHECKSIG"]
        
        style A fill:#e1f5fe
        style B fill:#f3e5f5
        style C fill:#e8f5e8
        style D fill:#fff3e0
    ```

##### Output 3: Change Output (Optional)

- **Type**: SegWit (P2WPKH)
- **Amount**: `input_value - pegin_amount - ENABLER_AMOUNT - fees` (if > 546 sats)
- **Key**: User's public key
- **Purpose**: Returns unused funds to the user
- **Condition**: Only created if change amount > 546 sats (dust threshold)

#### REQUEST_PEGIN_TX Transaction Flow

```mermaid
graph LR
    A[User's Bitcoin UTXO] --> B[REQUEST_PEGIN_TX<br/>Inputs:<br/>• Input 0: User's Bitcoin UTXO<br/>  User's private key]
    B --> C[REQUEST_PEGIN_TX<br/>Outputs:<br/>• Output 0: PegIn Request Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: OP_RETURN Output<br/>  RSK pegin metadata<br/><br/>--------------------------------<br/><br/>• Output 2: Pegin Request Accept Enabler<br/>  P2TR - Members dispute Key<br/><br/>--------------------------------<br/><br/>• Output 3: Change Output<br/>  P2WPKH - User's key]
    
    %% Flow to next transaction
    C --> D[ACCEPT_PEGIN_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#e1f5fe
    style D fill:#f3e5f5
```

### 1. USER_REIMBURSMENT_TX (User Reimbursement Transaction)

**Purpose**: This transaction can be sent by the user to recover their funds after the timelock to accept the pegin expires. It consumes Output 0 (PegIn Request Output) from REQUEST_PEGIN_TX via script path using the timelock script.

#### USER_REIMBURSMENT_TX Inputs

##### USER_REIMBURSMENT_TX Input 0: From REQUEST_PEGIN_TX Output 0

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (timelock)
- **Sighash Type**: SIGHASH_ALL
- **Timelock**: LONG_TIMELOCK blocks (from StreamSettings)
- **Key Required**: User reimbursement key `reimbursement_pubkey`
- **Previous Transaction**: REQUEST_PEGIN_TX Output 0 (PegIn Request Output)
- **Description**: Spends Output 0 (PegIn Request Output) from the request peg-in transaction using the user reimbursement key after the timelock expires. This provides an alternative path for the user to recover their funds if the committee does not accept the pegin within the timelock period.
- **Taproot Script Details**:
  - **Key Path**: Uses the committee aggregated key for direct spending
  - **Script Tree**: Contains two script leaves:
    1. **Timelock Script**: `OP_1 <TIMELOCK_BLOCKS> OP_CHECKSEQUENCEVERIFY OP_DROP <reimbursement_pubkey> OP_CHECKSIG` (1 block timelock for user reimbursement)
    2. **OP_RETURN Script**: `OP_RETURN <rootstock_address_bytes><amount_bytes>` (contains Rootstock address and amount data)
    3. **OP_RETURN Data Format**: `vec![rootstock_address, value.to_be_bytes().as_slice()].concat()` (concatenated rootstock address and big-endian amount bytes)
  - **REQUEST_PEGIN_TX Output 0 Script Tree**:

    ```mermaid
    graph TD
        A[REQUEST_PEGIN_TX Output 0<br/>PegIn Request Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf 1: Timelock Script]
        C --> E[Leaf 2: OP_RETURN Script]
        
        D --> F["OP_1 <TIMELOCK_BLOCKS> OP_CHECKSEQUENCEVERIFY OP_DROP <reimbursement_pubkey> OP_CHECKSIG"]
        E --> G["OP_RETURN <rootstock_address_bytes><amount_bytes><br/>vec![rootstock_address, value.to_be_bytes().as_slice()].concat()"]
        
        style A fill:#e1f5fe
        style B fill:#f3e5f5
        style C fill:#e8f5e8
        style D fill:#fff3e0
        style E fill:#fff3e0
    ```

#### USER_REIMBURSMENT_TX Outputs

As this is a user transaction he can decide any output.

#### USER_REIMBURSMENT_TX Transaction Flow

```mermaid
graph LR
    A[User's Bitcoin UTXO] --> B[REQUEST_PEGIN_TX<br/>Inputs:<br/>• Input 0: User's Bitcoin UTXO<br/>  User's private key]
    B --> C[REQUEST_PEGIN_TX<br/>Outputs:<br/>• Output 0: PegIn Request Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: OP_RETURN Output<br/>  RSK pegin metadata<br/><br/>--------------------------------<br/><br/>• Output 2: Pegin Request Accept Enabler<br/>  P2TR - Members dispute Key<br/><br/>--------------------------------<br/><br/>• Output 3: Change Output<br/>  P2WPKH - User's key]
    
    %% Flow to USER_REIMBURSMENT_TX
    C -->|Output 0: Script path<br/>spends with timelock| D[USER_REIMBURSMENT_TX<br/>Inputs:<br/>• Input 0: REQUEST_PEGIN_TX Output 0<br/>  Script Path: Timelock Script]
    
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#e1f5fe
    style D fill:#f3e5f5
```

### 1. REJECT_PEGIN_TX (Reject Pegin Transaction)

**Purpose**: This transaction can be sent by any member of the committee, consuming the enabler output (Output 2) from REQUEST_PEGIN_TX to prevent the committee from accepting the pegin. Once this enabler output is consumed, ACCEPT_PEGIN_TX cannot be executed since it requires both Output 0 and Output 2 from REQUEST_PEGIN_TX.

#### REJECT_PEGIN_TX Inputs

##### REJECT_PEGIN_TX Input 0: From REQUEST_PEGIN_TX Output 2 (Enabler Output)

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (dispute key)
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee member dispute key `dispute_xonly_pubkey`
- **Previous Transaction**: REQUEST_PEGIN_TX Output 2 (Pegin Request Accept Enabler)
- **Description**: Spends the enabler output (Output 2) from the request peg-in transaction using the committee member's dispute key. This prevents ACCEPT_PEGIN_TX from being executed, as ACCEPT_PEGIN_TX requires both Output 0 and Output 2 from REQUEST_PEGIN_TX.
- **Taproot Script Details**:
  - **Key Path**: Uses the committee aggregated key for direct spending at accept pegin
  - **Script Tree**: Contains multiple script leaves, one per committee member dispute key to reject the pegin:
    - **verify_signature Script**: `<dispute_xonly_pubkey> OP_CHECKSIG`
  - **REQUEST_PEGIN_TX Enabler Output (Output 2) Script Tree**:

    ```mermaid
    graph TD
        A[REQUEST_PEGIN_TX Output 2<br/>Enabler Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf N: verify_signature Script]
        
        D --> E["<dispute_xonly_pubkey> OP_CHECKSIG"]
        
        style A fill:#e1f5fe
        style B fill:#f3e5f5
        style C fill:#e8f5e8
        style D fill:#fff3e0
    ```

#### REJECT_PEGIN_TX Outputs

Output is not important as we only want to consume the enabler.

#### REJECT_PEGIN_TX Transaction Flow

```mermaid
graph LR
    A[User's Bitcoin UTXO] --> B[REQUEST_PEGIN_TX<br/>Inputs:<br/>• Input 0: User's Bitcoin UTXO<br/>  User's private key]
    B --> C[REQUEST_PEGIN_TX<br/>Outputs:<br/>• Output 0: PegIn Request Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: OP_RETURN Output<br/>  RSK pegin metadata<br/><br/>--------------------------------<br/><br/>• Output 2: Pegin Request Accept Enabler<br/>  P2TR - Members dispute Key <br/><br/>--------------------------------<br/><br/>• Output 3: Change Output<br/>  P2WPKH - User's key]
    
    %% Flow to REJECT_PEGIN_TX
    C -->|Output 2: Script path<br/>spends with dispute key| D[REJECT_PEGIN_TX<br/>Inputs:<br/>• Input 0: REQUEST_PEGIN_TX Output 2<br/>  Script Path: Dispute Key]
    
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#e1f5fe
    style D fill:#ffebee
```

### 1. ACCEPT_PEGIN_TX (Accept PegIn Transaction)

**Purpose**: This is the main transaction that accepts a peg-in request from a user and creates outputs that can be claimed by operators.

#### ACCEPT_PEGIN_TX Inputs

##### ACCEPT_PEGIN_TX Input 0: From REQUEST_PEGIN_TX Output 0

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: REQUEST_PEGIN_TX (must be created by user and mined before this transaction)
- **Description**: Spends Output 0 (PegIn Request Output) from the request peg-in transaction using the committee's aggregated key signature. The REQUEST_PEGIN_TX must be confirmed on the blockchain before this transaction can be executed.
- **Taproot Script Details**:
  - **Key Path**: Uses the committee aggregated key for direct spending
  - **Script Tree**: Contains two script leaves:
    1. **Timelock Script**: `OP_1 <TIMELOCK_BLOCKS> OP_CHECKSEQUENCEVERIFY OP_DROP <reimbursement_pubkey> OP_CHECKSIG` (1 block timelock for user reimbursement)
    2. **OP_RETURN Script**: `OP_RETURN <rootstock_address_bytes><amount_bytes>` (contains Rootstock address and amount data)
    3. **OP_RETURN Data Format**: `vec![rootstock_address, value.to_be_bytes().as_slice()].concat()` (concatenated rootstock address and big-endian amount bytes)
  - **REQUEST_PEGIN_TX Script Tree**:

    ```mermaid
    graph TD
        A[REQUEST_PEGIN_TX Taproot Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf 1: Timelock Script]
        C --> E[Leaf 2: OP_RETURN Script]
        
        D --> F["OP_1 <TIMELOCK_BLOCKS> OP_CHECKSEQUENCEVERIFY OP_DROP <reimbursement_pubkey> OP_CHECKSIG"]
        E --> G["OP_RETURN <rootstock_address_bytes><amount_bytes><br/>vec![rootstock_address, value.to_be_bytes().as_slice()].concat()"]
        
        style A fill:#e1f5fe
        style B fill:#f3e5f5
        style C fill:#e8f5e8
        style D fill:#fff3e0
        style E fill:#fff3e0
    ```

##### ACCEPT_PEGIN_TX Input 1: From REQUEST_PEGIN_TX Output 2 (Enabler Output)

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: REQUEST_PEGIN_TX Output 2 (Enabler Output)
- **Description**: Spends Output 2 (Pegin Request Accept Enabler) from the request peg-in transaction using the committee's aggregated key signature. This input must be consumed along with Input 0 to accept the pegin. If this output is consumed by REJECT_PEGIN_TX instead, the pegin cannot be accepted.
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending at accept pegin
  - **Script Tree**: Contains multiple script leaves, one per committee member dispute key to reject the pegin:
    - **verify_signature Script**: `<dispute_xonly_pubkey> OP_CHECKSIG`
  - **REQUEST_PEGIN_TX Enabler Script Tree**:

    ```mermaid
    graph TD
        A[REQUEST_PEGIN_TX Enabler Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf N: verify_signature Script]
        
        D --> E["<dispute_xonly_pubkey> OP_CHECKSIG"]
        
        style A fill:#e1f5fe
        style B fill:#f3e5f5
        style C fill:#e8f5e8
        style D fill:#fff3e0
    ```

#### ACCEPT_PEGIN_TX Outputs

##### Output 0: Main PegIn Output

- **Type**: Taproot (P2TR)
- **Amount**: `pegin_request.amount - P2TR_FEE - SPEEDUP_VALUE - ENABLER_AMOUNT`
- **Key**: Committee aggregated key (`take_aggregated_key`)
- **Leaves**: Empty (no script paths)
- **Purpose**: Main output that can be spent by operators in subsequent transactions
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Empty (no script leaves) - only key path spending is allowed
  - **Spending Conditions**: Can only be spent using the committee aggregated key signature
  - **ACCEPT_PEGIN_TX Script Structure**:

    ```mermaid
    graph TD
        A[ACCEPT_PEGIN_TX Output] --> B[Committee Aggregated Key]
        A --> C[Empty Script Tree]
        
        style A fill:#f3e5f5
        style B fill:#e8f5e8
        style C fill:#ffebee
    ```

##### Output 1: CANCEL_TAKE_0 Enabler Output

- **Type**: Taproot (P2TR)
- **Amount**: `ENABLER_AMOUNT` (540 sats)
- **Key**: Committee aggregated key (`take_aggregated_key`)
- **Leaves**: Contains script leaves for each operator's dispute key
- **Purpose**: Enabler output that can be consumed to cancel operator take transactions. Contains operator-only dispute keys, allowing operators to cancel their own take transactions if needed.
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Contains multiple script leaves, one per operator dispute key:
    - **verify_signature Script**: `<operator_dispute_xonly_pubkey> OP_CHECKSIG`
  - **ACCEPT_PEGIN_TX CANCEL_TAKE_0 Enabler Script Tree**:

    ```mermaid
    graph TD
        A[ACCEPT_PEGIN_TX CANCEL_TAKE_0 Enabler Output] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D[Leaf N: verify_signature Script]
        
        D --> E["<operator_dispute_xonly_pubkey> OP_CHECKSIG"]
        
        style A fill:#f3e5f5
        style B fill:#e8f5e8
        style C fill:#e8f5e8
        style D fill:#fff3e0
    ```

##### Output 2: Speedup Output

- **Type**: SegWit (P2WPKH)
- **Amount**: SPEEDUP_VALUE
- **Key**: User's reimbursement public key (`reimbursement_pubkey`)
- **Purpose**: Speedup transaction paid by the user to accelerate confirmation

#### ACCEPT_PEGIN_TX Transaction Flow

```mermaid
graph LR
    A[REQUEST_PEGIN_TX<br/>created by user<br/>Output 0] --> B[ACCEPT_PEGIN_TX<br/>Inputs:<br/>• Input 0: REQUEST_PEGIN_TX Output 0<br/>  Key Path: Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Input 1: REQUEST_PEGIN_TX Output 2<br/>  Key Path: Committee Aggregated Key]
    G[REQUEST_PEGIN_TX<br/>created by user<br/>Output 2] --> B
    B --> C[ACCEPT_PEGIN_TX<br/>Outputs:<br/>• Output 0: Main PegIn Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: CANCEL_TAKE_0 Enabler<br/>  P2TR - Operator dispute keys<br/><br/>--------------------------------<br/><br/>• Output 2: Speedup Output<br/>  P2WPKH - User's reimbursement key]
    
    %% Flow to next transactions
    C --> D[USER_TAKE_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    C --> E[OPERATOR_TAKE_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    C --> F[OPERATOR_WON_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    
    style A fill:#e1f5fe
    style G fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#f3e5f5
    style D fill:#e8f5e8
    style E fill:#fff3e0
    style F fill:#fce4ec
```

### 2. OPERATOR_TAKE_TX (Operator Take Transaction)

**Purpose**: Allows an operator to claim funds from the accept peg-in transaction. This is the fallback mechanism for operators to receive their portion of the peg-in funds when not all committee signatures are available.

#### OPERATOR_TAKE_TX Inputs

##### OPERATOR_TAKE_TX Input 0: From ACCEPT_PEGIN_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: ACCEPT_PEGIN_TX
- **Description**: Spends the main output from the accept peg-in transaction
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Empty (no script leaves) - only key path spending is allowed
  - **Spending Path**: Key path spending with committee aggregated signature

##### OPERATOR_TAKE_TX Input 1: From Dispute Core REIMBURSEMENT_KICKOFF_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (timelock)
- **Sighash Type**: SIGHASH_ALL
- **Timelock**: LONG_TIMELOCK blocks (from StreamSettings)
- **Previous Transaction**: REIMBURSEMENT_KICKOFF_TX (from Dispute Core protocol)
- **Description**: Spends the operator take enabler output (output 0) from REIMBURSEMENT_KICKOFF_TX. This output is created when the operator dispatches REIMBURSEMENT_KICKOFF_TX after advancing funds to the user. The operator must wait for the long timelock to expire before they can spend this output.
- **Dispute Core Context**: The REIMBURSEMENT_KICKOFF_TX is created and dispatched by the operator as part of the peg-out flow after advancing funds to the user. The transaction creates the operator take enabler output that enables OPERATOR_TAKE_TX execution.
- **Taproot Script Details**:
  - **Script Path**: Uses long timelock script leaf for spending
  - **Script Tree**: Contains multiple script leaves (one per committee member)
  - **Script Leaf (Operator Owner)**: `OP_1 <LONG_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP <operator_dispute_key> OP_CHECKSIG`
  - **Spending Conditions**:
    - Must wait for long timelock expiry (LONG_TIMELOCK blocks)
    - Must sign with operator's dispute key
    - The operator can only spend using their own script leaf (long timelock path)

#### OPERATOR_TAKE_TX Outputs

##### OPERATOR_TAKE_TX Output 0: Operator Output

- **Type**: SegWit (P2WPKH)
- **Amount**: `operator_input_amount - P2TR_FEE - SPEEDUP_VALUE`
- **Key**: Operator's dispute key (`dispute_key`)
- **Purpose**: Funds sent to the operator's dispute key address

##### OPERATOR_TAKE_TX Output 1: Speedup Output

- **Type**: SegWit (P2WPKH)
- **Amount**: SPEEDUP_VALUE
- **Key**: Operator's speedup key (`speedup_key`)
- **Purpose**: Speedup transaction paid by the operator

#### OPERATOR_TAKE_TX Transaction Flow

```mermaid
graph LR
    A[ACCEPT_PEGIN_TX<br/>output 0] --> B[OPERATOR_TAKE_TX<br/>Inputs:<br/>• Input 0: ACCEPT_PEGIN_TX output<br/>  Key Path: Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Input 1: REIMBURSEMENT_KICKOFF_TX output<br/>  Script Path: Timelock Script]
    C[Dispute Core<br/>REIMBURSEMENT_KICKOFF_TX<br/>output] --> B
    B --> D[OPERATOR_TAKE_TX<br/>Outputs:<br/>• Output 0: Operator Output<br/>  P2WPKH - Operator's dispute key<br/><br/>--------------------------------<br/><br/>• Output 1: Speedup Output<br/>  P2WPKH - Operator's speedup key]
    
    style A fill:#f3e5f5
    style B fill:#fff3e0
    style C fill:#fce4ec
    style D fill:#fff3e0
```


### 3. OPERATOR_WON_TX (Operator Won Transaction)

**Purpose**: Transaction for operators to claim funds after winning a dispute challenge. This is the disputed fallback used when the operator's transaction is challenged and the operator successfully defends their position in the dispute resolution process.

#### OPERATOR_WON_TX Inputs

##### OPERATOR_WON_TX Input 0: From ACCEPT_PEGIN_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: ACCEPT_PEGIN_TX
- **Description**: Spends the main output from the accept peg-in transaction
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Empty (no script leaves) - only key path spending is allowed
  - **Spending Path**: Key path spending with committee aggregated signature

##### OPERATOR_WON_TX Input 1: From REVEAL_INPUT_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: REVEAL_INPUT_TX (from Dispute Core protocol, indexed by slot)
- **Description**: Spends the OPERATOR_WON_ENABLER output (output 0) from REVEAL_INPUT_TX. This output is created when the operator successfully reveals the input during dispute resolution. The operator can claim funds after winning a challenge dispute.
- **Dispute Core Context**: The REVEAL_INPUT_TX is created as part of the dispute resolution process. When an operator is challenged and successfully reveals the input (proving they advanced funds correctly), this transaction creates the OPERATOR_WON_ENABLER output that enables OPERATOR_WON_TX execution.
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Contains dispute resolution script leaves
  - **Script Leaves**: Multiple script paths for dispute resolution scenarios
  - **Spending Path**: Key path spending with committee aggregated signature
  - **Dispute Context**: This input is only available after successful dispute resolution (operator reveals input and wait challenge timelock)

#### OPERATOR_WON_TX Outputs

##### OPERATOR_WON_TX Output 0: Operator Output

- **Type**: SegWit (P2WPKH)
- **Amount**: `operator_input_amount - P2TR_FEE - SPEEDUP_VALUE`
- **Key**: Operator's dispute key (`dispute_key`)
- **Purpose**: Funds sent to the operator's dispute key address

##### OPERATOR_WON_TX Output 1: Speedup Output

- **Type**: SegWit (P2WPKH)
- **Amount**: SPEEDUP_VALUE
- **Key**: Operator's speedup key (`speedup_key`)
- **Purpose**: Speedup transaction paid by the operator

#### OPERATOR_WON_TX Transaction Flow

```mermaid
graph LR
    A[ACCEPT_PEGIN_TX<br/>output 0] --> B[OPERATOR_WON_TX<br/>Inputs:<br/>• Input 0: ACCEPT_PEGIN_TX output<br/>  Key Path: Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Input 1: REVEAL_INPUT_TX output<br/>  Key Path: Committee Aggregated Key]
    C[REVEAL_INPUT_TX<br/>Dispute Core Protocol<br/>output 0: OPERATOR_WON_ENABLER] --> B
    B --> D[OPERATOR_WON_TX<br/>Outputs:<br/>• Output 0: Operator Output<br/>  P2WPKH - Operator's dispute key<br/><br/>--------------------------------<br/><br/>• Output 1: Speedup Output<br/>  P2WPKH - Operator's speedup key]
    
    style A fill:#f3e5f5
    style B fill:#fce4ec
    style C fill:#fce4ec
    style D fill:#fce4ec
```

### Accept PegIn Protocol Integration with Dispute Core

The Accept PegIn Protocol integrates with the **Dispute Core Protocol** to provide dispute resolution mechanisms:

- **REIMBURSEMENT_KICKOFF_TX**: Part of the Dispute Core protocol that creates outputs enabling operator reimbursement through OPERATOR_TAKE_TX
- **Dispute Resolution**: Provides mechanisms for operators to claim funds after successful dispute resolution
- **Timelock Protection**: Long timelocks prevent premature spending and ensure proper dispute resolution
- **Cross-Protocol Coordination**: Accept PegIn Protocol coordinates with Dispute Core Protocol for complete peg-out functionality

## Dispute Core Protocol - Transaction Details

The **Dispute Core Protocol** is responsible for managing dispute resolution mechanisms and enabling operators to claim funds through the Accept PegIn Protocol. This protocol creates transactions that coordinate with the Accept PegIn Protocol to provide secure fund claiming mechanisms.

### 1. REIMBURSEMENT_KICKOFF_TX (Reimbursement Kickoff Transaction)

**Purpose**: Transaction that enables operators to claim funds through OPERATOR_TAKE_TX. This transaction is created as part of the Dispute Core protocol setup and provides the mechanism for operators to claim funds after advancing funds to users. The transaction creates an output (OPERATOR_TAKE_ENABLER) that serves as input 1 for OPERATOR_TAKE_TX.

#### REIMBURSEMENT_KICKOFF_TX Inputs

##### Input 0: From OP_INITIAL_DEPOSIT_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (Winternitz signature)
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Operator's Winternitz key for PEGOUT_ID_KEY
- **Previous Transaction**: OP_INITIAL_DEPOSIT_TX (from Dispute Core protocol)
- **Description**: Spends the initial deposit output from the operator's initial deposit transaction. The operator must sign with their Winternitz key to prove knowledge of the pegout ID.
- **Taproot Script Details**:
  - **Script Path**: Uses Winternitz signature script leaf for spending
  - **Script Tree**: Contains script leaves for reimbursement kickoff and dispute validation
  - **Script Leaf 0**: `VERIFY_WINTERNITZ_SIGNATURE(<dispute_aggregated_key>, PEGOUT_ID_KEY, <pegout_id_key>)` - Verifies Winternitz signature for pegout ID
  - **Script Leaf 1**: `VERIFY_SIGNATURE(<dispute_aggregated_key>)` - Validates dispute aggregated key signature
  - **Spending Conditions**: Must provide Winternitz signature proving knowledge of the pegout ID (32 bytes)

#### REIMBURSEMENT_KICKOFF_TX Outputs

##### Output 0: OPERATOR_TAKE_ENABLER Output

- **Type**: Taproot (P2TR)
- **Amount**: `AUTO_AMOUNT` (calculated during protocol setup)
- **Key**: Committee aggregated key (`take_aggregated_key`)
- **Leaves**: Multiple script leaves for challenge and operator take scenarios
- **Purpose**: Main output that enables OPERATOR_TAKE_TX and CHALLENGE_TX transactions
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Contains multiple script leaves:
    1. **Operator Take Script (Long Timelock)**: `OP_1 <LONG_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP <operator_dispute_key> OP_CHECKSIG` - Allows operator to claim funds after long timelock expires
    2. **Challenge Script (Short Timelock)**: `OP_1 <SHORT_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP VERIFY_WINTERNITZ_SIGNATURE(<dispute_aggregated_key>, CHALLENGE_KEY, <challenge_key>)` - Allows any committee member to challenge after short timelock expires
  - **Script Leaves**: One script per committee member
    - **For Operator Owner**: Long timelock script allowing operator to claim funds
    - **For Other Members**: Short timelock + Winternitz signature script allowing challenge
  - **Spending Conditions**:
    - Operator can spend via long timelock script path after timelock expiry
    - Any committee member can spend via challenge script path after short timelock expiry
  - **REIMBURSEMENT_KICKOFF_TX Output Script Tree**:

    ```mermaid
    graph TD
        A[REIMBURSEMENT_KICKOFF_TX Output 0] --> B[Committee Aggregated Key]
        A --> C[Script Tree]
        C --> D["Leaf ({operator_index}): Operator Long Timelock Script"]
        C --> F["Leaf (M - 1): Members Challenge Script"]
        
        D --> G["OP_1 <LONG_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP <operator_dispute_key> OP_CHECKSIG"]
        F --> I["OP_1 <SHORT_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP VERIFY_WINTERNITZ_SIGNATURE(<dispute_aggregated_key>, CHALLENGE_KEY, <challenge_key>)"]
        
        style A fill:#fce4ec
        style C fill:#fff3e0
        style D fill:#fff3e0
        style F fill:#fff3e0
    ```

#### REIMBURSEMENT_KICKOFF_TX Transaction Flow

```mermaid
graph LR
    A[OP_INITIAL_DEPOSIT_TX<br/>output 0] --> B[REIMBURSEMENT_KICKOFF_TX<br/>Inputs:<br/>• Input 0: OP_INITIAL_DEPOSIT_TX output<br/>  Script Path: Winternitz Signature]
    B --> C[REIMBURSEMENT_KICKOFF_TX<br/>Outputs:<br/>• Output 0: OPERATOR_TAKE_ENABLER Output<br/>  P2TR - Committee Aggregated Key<br/>  Multiple script leaves]
    
    %% Flow to next transactions
    C --> D[OPERATOR_TAKE_TX<br/>input 1<br/>Script Path: Long Timelock]
    C --> E[CHALLENGE_TX<br/>input 0<br/>Script Path: Short Timelock + Winternitz]
    
    style A fill:#fce4ec
    style B fill:#fce4ec
    style C fill:#fce4ec
    style D fill:#fff3e0
    style E fill:#fce4ec
```

**Key Points**:

- **Operator Responsibility**: Operator creates, signs (with Winternitz signature for pegout ID), and broadcasts REIMBURSEMENT_KICKOFF_TX after advancing funds to the user
- **Pegout ID Verification**: The operator must prove knowledge of the pegout ID using their Winternitz key
- **Multiple Spending Paths**: The output supports both operator take (long timelock) and challenge (short timelock) scenarios
- **Cross-Protocol Integration**: This transaction's output serves as input 1 for OPERATOR_TAKE_TX in the Accept PegIn Protocol

#### Dispute Core Protocol Integration with Accept PegIn

The Dispute Core Protocol integrates with the **Accept PegIn Protocol** to provide secure fund claiming mechanisms:

- **OPERATOR_TAKE_ENABLER**: Output from REIMBURSEMENT_KICKOFF_TX that serves as input 1 for OPERATOR_TAKE_TX
- **Rootstock Registration**: After REIMBURSEMENT_KICKOFF_TX is mined, the operator calls `registerReimbursementKickoff` on the Rootstock contract with SPV proof
- **Status Management**: The contract changes slot status to `KICKOFF` upon successful registration
- **Timelock Protection**: Long timelocks prevent premature spending and ensure proper dispute resolution
- **Challenge Mechanism**: Short timelock + Winternitz signature allows committee members to challenge operator actions
- **Cross-Protocol Coordination**: Dispute Core Protocol coordinates with Accept PegIn Protocol and Rootstock contracts for complete peg-out functionality
- **Operator Workflow**:
  1. Operator dispatches ADVANCE_FUNDS_TX and calls `registerAdvanceFunds`
  2. Operator dispatches REIMBURSEMENT_KICKOFF_TX and calls `registerReimbursementKickoff`
  3. After long timelock expires, operator dispatches OPERATOR_TAKE_TX and calls `registerOperatorTake`

### 2. CHALLENGE_TX (Challenge Transaction)

**Purpose**: Transaction that allows any committee member (watchtower) to challenge an operator's REIMBURSEMENT_KICKOFF_TX if they detect incorrect behavior, such as an invalid ADVANCE_FUNDS_TX (wrong amount, wrong recipient, or forked chain). This transaction initiates the dispute resolution process and requires the operator to reveal the input or face penalties.

#### CHALLENGE_TX Inputs

##### Input 0: From REIMBURSEMENT_KICKOFF_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (short timelock + Winternitz signature)
- **Sighash Type**: SIGHASH_ALL
- **Timelock**: SHORT_TIMELOCK blocks (from StreamSettings)
- **Key Required**: Challenging member's Winternitz key for CHALLENGE_KEY
- **Previous Transaction**: REIMBURSEMENT_KICKOFF_TX (from Dispute Core protocol, output 0)
- **Description**: Spends the OPERATOR_TAKE_ENABLER output from REIMBURSEMENT_KICKOFF_TX. The challenging member must wait for the short timelock to expire and sign with their Winternitz key to prove they are challenging the operator's actions.
- **Taproot Script Details**:
  - **Script Path**: Uses short timelock + Winternitz signature script leaf for spending
  - **Script Tree**: Contains multiple script leaves (one per committee member)
  - **Script Leaf (Challenging Member)**: `OP_1 <SHORT_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP VERIFY_WINTERNITZ_SIGNATURE(<dispute_aggregated_key>, CHALLENGE_KEY, <challenge_key>)` - Allows any committee member to challenge after short timelock expires
  - **Winternitz Signature Data**: The challenging member signs the value `[1u8]` (single byte with value 1) using their CHALLENGE_KEY Winternitz key
  - **Spending Conditions**: 
    - Must wait for short timelock expiry (SHORT_TIMELOCK blocks)
    - Must provide Winternitz signature with CHALLENGE_KEY proving the challenge intent
    - The challenging member uses their own script leaf index (their member index in the committee)

#### CHALLENGE_TX Outputs

##### Output 0: REVEAL_INPUT Output

- **Type**: Taproot (P2TR)
- **Amount**: `AUTO_AMOUNT` (calculated during protocol setup)
- **Key**: Committee aggregated key (`dispute_aggregated_key`)
- **Leaves**: Two script leaves for reveal input and input not revealed scenarios
- **Purpose**: Main output that enables REVEAL_INPUT_TX and INPUT_NOT_REVEALED_TX transactions
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Contains two script leaves:
    1. **Reveal Input Script**: `VERIFY_WINTERNITZ_SIGNATURE(<operator_dispute_key>, SLOT_ID_KEY, <slot_id_key>)` - Allows operator to reveal the input by signing with their SLOT_ID_KEY Winternitz key
    2. **Input Not Revealed Script**: `OP_1 <INPUT_NOT_REVEALED_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP VERIFY_SIGNATURE(<dispute_aggregated_key>)` - Allows committee to claim funds if operator doesn't reveal input within the timelock
  - **Spending Conditions**: 
    - Operator can spend via reveal input script path by providing Winternitz signature with SLOT_ID_KEY
    - Committee can spend via input not revealed script path after timelock expiry if operator fails to reveal

##### Output 1 to N: Speedup Outputs

- **Type**: SegWit (P2WPKH)
- **Amount**: `SPEEDUP_VALUE` (540 satoshis) per output
- **Key**: Each committee member's speedup key (`speedup_key`)
- **Count**: One speedup output per committee member
- **Purpose**: Speedup transactions for each committee member to accelerate future transaction confirmations
- **Indexing**: The speedup output index for each member is `1 + member_index` (where member_index is 0-based)

#### CHALLENGE_TX Transaction Flow

```mermaid
graph LR
    A[REIMBURSEMENT_KICKOFF_TX<br/>output 0: OPERATOR_TAKE_ENABLER] --> B[CHALLENGE_TX<br/>Inputs:<br/>• Input 0: REIMBURSEMENT_KICKOFF_TX output<br/>  Script Path: Short Timelock + Winternitz<br/>  Data: [1u8] signed with CHALLENGE_KEY]
    B --> C[CHALLENGE_TX<br/>Outputs:<br/>• Output 0: REVEAL_INPUT Output<br/>  P2TR - Committee Aggregated Key<br/>  Two script leaves<br/><br/>• Output 1-N: Speedup Outputs<br/>  P2WPKH - One per committee member<br/>  Amount: SPEEDUP_VALUE each]
    
    %% Flow to next transactions
    C --> D[REVEAL_INPUT_TX<br/>input 0<br/>Script Path: Winternitz Signature<br/>Operator reveals input]
    C --> E[INPUT_NOT_REVEALED_TX<br/>input 0<br/>Script Path: Timelock<br/>If operator doesn't reveal]
    
    style A fill:#fce4ec
    style B fill:#fce4ec
    style C fill:#fce4ec
    style D fill:#fff3e0
    style E fill:#fce4ec
```

#### CHALLENGE_TX Registration and Validation

The Rootstock contract validates CHALLENGE_TX through the `registerChallenge` function:

- **Status Validation**: The slot must be in `KICKOFF` status (REIMBURSEMENT_KICKOFF_TX must be previously registered)
- **Input Validation**: 
  - CHALLENGE_TX must have exactly 1 input (CHALLENGE_INPUT_COUNT)
  - Input 0 must reference the registered REIMBURSEMENT_KICKOFF_TX transaction ID
- **Member Validation**: The caller must be a member of the committee for that slot
- **SPV Proof**: The transaction must be verified with sufficient confirmations using SPV proof
- **Status Update**: Upon successful registration, the slot status changes to `CHALLENGE`

#### CHALLENGE_TX Integration with Dispute Resolution

CHALLENGE_TX is a critical component of the dispute resolution mechanism:

- **Challenge Trigger**: Can be dispatched at any time after REIMBURSEMENT_KICKOFF_TX is registered, as long as the short timelock has expired
- **Operator Response**: The operator must respond by dispatching REVEAL_INPUT_TX to prove they advanced funds correctly
- **Timeout Protection**: If the operator fails to reveal within INPUT_NOT_REVEALED_TIMELOCK blocks, INPUT_NOT_REVEALED_TX can be dispatched, leading to operator penalties
- **Dispute Outcome**: 
  - If operator reveals correctly: Operator can proceed with OPERATOR_WON_TX
  - If operator fails to reveal: Watchtower wins the challenge, operator is penalized

### 3. REVEAL_INPUT_TX (Reveal Input Transaction)

**Purpose**: Transaction that allows the operator to reveal the input (slot ID signature) during dispute resolution, proving they correctly advanced funds. This transaction is dispatched by the operator in response to a CHALLENGE_TX and creates the OPERATOR_WON_ENABLER output that enables OPERATOR_WON_TX execution.

#### REVEAL_INPUT_TX Inputs

##### Input 0: From CHALLENGE_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (Winternitz signature)
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Operator's Winternitz key for SLOT_ID_KEY
- **Previous Transaction**: CHALLENGE_TX (from Dispute Core protocol, output 0)
- **Description**: Spends the REVEAL_INPUT output from CHALLENGE_TX. The operator must sign with their SLOT_ID_KEY Winternitz key to prove knowledge of the slot ID, demonstrating they correctly advanced funds for the challenged slot.
- **Winternitz Signature Data**: The operator signs the slot index value `(slot_index as u16).to_le_bytes()` (2 bytes, little-endian) using their SLOT_ID_KEY Winternitz key
- **Taproot Script Details**:
  - **Script Path**: Uses Winternitz signature script leaf (leaf 0) for spending
  - **Script Tree**: Contains two script leaves:
    1. **Reveal Input Script (Leaf 0)**: `VERIFY_WINTERNITZ_SIGNATURE(<operator_dispute_key>, SLOT_ID_KEY, <slot_id_key>)` - Allows operator to reveal the input by signing with their SLOT_ID_KEY Winternitz key
    2. **Input Not Revealed Script (Leaf 1)**: `OP_1 <INPUT_NOT_REVEALED_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP VERIFY_SIGNATURE(<dispute_aggregated_key>)` - Allows committee to claim funds if operator doesn't reveal input within the timelock (used by INPUT_NOT_REVEALED_TX)
  - **Spending Conditions**: 
    - Operator can spend via reveal input script path (leaf 0) by providing Winternitz signature with SLOT_ID_KEY
    - The signature must sign the slot index value (2 bytes, u16, little-endian)
    - Committee can spend via input not revealed script path (leaf 1) after timelock expiry if operator fails to reveal

#### REVEAL_INPUT_TX Outputs

##### Output 0: OPERATOR_WON_ENABLER Output

- **Type**: Taproot (P2TR)
- **Amount**: `AUTO_AMOUNT` (calculated during protocol setup)
- **Key**: Committee aggregated key (`take_aggregated_key`)
- **Leaves**: One script leaf for operator won scenario
- **Purpose**: Main output that enables OPERATOR_WON_TX execution (serves as input 1 for OPERATOR_WON_TX)
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Contains one script leaf:
    1. **Operator Won Script**: `OP_1 <OP_WON_TIMELOCK> OP_CHECKSEQUENCEVERIFY OP_DROP VERIFY_SIGNATURE(<take_aggregated_key>)` - Allows operator to claim funds after winning a challenge dispute, requires waiting for OP_WON_TIMELOCK blocks
  - **Spending Conditions**: 
    - After OP_WON_TIMELOCK blocks expire, the operator can spend via script path using committee aggregated key signature
    - This output serves as input 1 for OPERATOR_WON_TX in the Accept PegIn Protocol
  - **REVEAL_INPUT_TX Output Script Tree**:


##### Output 1: Speedup Output

- **Type**: SegWit (P2WPKH)
- **Amount**: `SPEEDUP_VALUE` (540 satoshis)
- **Key**: Operator's speedup key (`speedup_key`)
- **Purpose**: Speedup transaction for the operator to accelerate future transaction confirmations

#### REVEAL_INPUT_TX Transaction Flow

```mermaid
graph LR
    A[CHALLENGE_TX<br/>output 0: REVEAL_INPUT Output] --> B[REVEAL_INPUT_TX<br/>Inputs:<br/>• Input 0: CHALLENGE_TX output<br/>  Script Path: Winternitz Signature<br/>  Data: slot_index (u16, little-endian)<br/>  Signed with SLOT_ID_KEY]
    B --> C[REVEAL_INPUT_TX<br/>Outputs:<br/>• Output 0: OPERATOR_WON_ENABLER Output<br/>  P2TR - Committee Aggregated Key<br/>  Operator Won Script with Timelock<br/><br/>• Output 1: Speedup Output<br/>  P2WPKH - Operator's speedup key<br/>  Amount: SPEEDUP_VALUE]
    
    %% Flow to next transaction
    C --> D[OPERATOR_WON_TX<br/>input 1<br/>Script Path: Operator Won Script<br/>After OP_WON_TIMELOCK expires]
    
    style A fill:#fce4ec
    style B fill:#fce4ec
    style C fill:#fce4ec
    style D fill:#fce4ec
```

#### REVEAL_INPUT_TX Integration with Dispute Resolution

REVEAL_INPUT_TX is a critical component of the dispute resolution mechanism:

- **Challenge Response**: Dispatched by the operator after CHALLENGE_TX is registered to prove they advanced funds correctly
- **Slot ID Proof**: The Winternitz signature on the slot index proves the operator knows which slot they're defending
- **OPERATOR_WON_TX Enablement**: Creates the OPERATOR_WON_ENABLER output that enables OPERATOR_WON_TX execution
- **Timelock Requirement**: The OPERATOR_WON_ENABLER output requires OP_WON_TIMELOCK blocks to pass before OPERATOR_WON_TX can be executed
- **Dispute Outcome**: 
  - If operator reveals correctly: Operator can proceed with OPERATOR_WON_TX after timelock expiry
  - If operator fails to reveal: INPUT_NOT_REVEALED_TX can be dispatched, leading to operator penalties

## User Take Protocol - Transaction Details

### 1. USER_TAKE_TX (User Take Transaction)

**Purpose**: Transaction that allows users to claim their portion of peg-in funds. This is the common case for peg-out and provides the most efficient path for users to withdraw their funds from the Union Bridge system when all committee signatures are available.

#### USER_TAKE_TX Inputs

##### USER_TAKE_TX Input 0: From ACCEPT_PEGIN_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: ACCEPT_PEGIN_TX
- **Description**: Spends the main output from the accept peg-in transaction using the committee's aggregated key signature
- **Taproot Script Details**:
  - **Key Path**: Uses committee aggregated key for direct spending
  - **Script Tree**: Empty (no script leaves) - only key path spending is allowed
  - **Spending Path**: Key path spending with committee aggregated signature

#### USER_TAKE_TX Outputs

##### USER_TAKE_TX Output 0: User Funds Output

- **Type**: SegWit (P2WPKH)
- **Amount**: `accept_pegin_amount - USER_TAKE_FEE - SPEEDUP_VALUE`
- **Key**: User's public key
- **Purpose**: Main output containing the user's portion of peg-in funds

##### USER_TAKE_TX Output 1: Speedup Output

- **Type**: SegWit (P2WPKH)
- **Amount**: SPEEDUP_VALUE
- **Key**: User's public key
- **Purpose**: Speedup transaction paid by the user

#### USER_TAKE_TX Transaction Flow

```mermaid
graph LR
    A[ACCEPT_PEGIN_TX<br/>output 0] --> B[USER_TAKE_TX<br/>Inputs:<br/>• Input 0: ACCEPT_PEGIN_TX output<br/>  Key Path: Committee Aggregated Key]
    B --> C[USER_TAKE_TX<br/>Outputs:<br/>• Output 0: User Funds Output<br/>  P2WPKH - User's key<br/><br/>--------------------------------<br/><br/>• Output 1: Speedup Output<br/>  P2WPKH - User's key]
    
    style A fill:#f3e5f5
    style B fill:#e8f5e8
    style C fill:#e8f5e8
```

## Advance Funds Protocol - Transaction Details

### 1. ADVANCE_FUNDS_TX (Advance Funds Transaction)

**Purpose**: Transaction that allows operators to advance funds to users before executing their operator take transaction. This transaction serves as proof that the operator has fulfilled their obligation to advance funds to the user. If the operator is later challenged, this transaction proof can be used to validate that they sent the funds, and if the proof is correct, the OPERATOR_WON_TX will be executed.

#### ADVANCE_FUNDS_TX Inputs

##### Input 0: Operator's Advance Funds Input

- **Type**: SegWit (P2WPKH)
- **Spend Mode**: KeyOnly (Segwit)
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Operator's dispute key (`dispute_key`)
- **Previous Transaction**: Operator's input transaction (ADVANCE_FUNDS_INPUT_TX)
- **Description**: Spends the operator's own funds to advance money to the user. This is the primary source of funds for the advance funds transaction. The operator must have sufficient balance in their dispute key address to cover the user amount plus fees.
- **Source**: The operator provides a UTXO from their wallet that will be spent to fund the advance. This UTXO is referenced as ADVANCE_FUNDS_INPUT_TX in the protocol.
- **Amount Requirement**: The input amount must be sufficient to cover:
  - User funds output: `accept_pegin_amount - USER_TAKE_FEE`
  - Transaction fees
  - Optional change output (if change > DUST_VALUE)

##### Input 1: Previous Operator Take UTXO (Optional)

- **Type**: SegWit (P2WPKH)
- **Spend Mode**: KeyOnly (Segwit)
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Operator's dispute key (`dispute_key`)
- **Previous Transaction**: Previous OPERATOR_TAKE_TX output (if available)
- **Description**: Spends any remaining funds from a previous operator take transaction

#### ADVANCE_FUNDS_TX Outputs

##### Output 0: User Funds Output

- **Type**: SegWit (P2WPKH)
- **Amount**: `accept_pegin_amount - USER_TAKE_FEE`
- **Key**: User's public key
- **Purpose**: Main output containing the user's portion of peg-in funds

##### Output 1: OP_RETURN Output

- **Type**: OP_RETURN (unspendable)
- **Amount**: 0 sats
- **Purpose**: Contains pegout metadata for transaction monitoring and validation
- **Data Format**: Contains the pegout ID (`pegout_id`) as raw bytes
- **Data Structure**:
  - **Content**: `pegout_id` (32 bytes) - The unique identifier for this peg-out request
  - **Encoding**: Raw bytes of the pegout ID
- **Validation**: The Rootstock contract validates this OP_RETURN output when `registerAdvanceFunds` is called to ensure:
  - The pegout ID matches the one generated in the `tryPegout` call
  - The transaction is correctly associated with the peg-out request
- **Usage**: This output allows the system to link the ADVANCE_FUNDS_TX to the specific peg-out request and verify that the operator is advancing funds for the correct slot.

##### Output 2: Operator Change Output (Optional)

- **Type**: SegWit (P2WPKH)
- **Amount**: `input_amount - user_amount - transaction_fees` (if > DUST_VALUE)
- **Key**: Operator's dispute key
- **Purpose**: Returns unused funds to the operator after covering user amount and fees
- **Calculation**:
  - Total input amount: Sum of Input 0 amount + Input 1 amount (if present)
  - User amount: `accept_pegin_amount - USER_TAKE_FEE`
  - Operator fee: `fee` (from AdvanceFundsRequest)
  - Transaction fees: Network fees for the transaction
  - Change: `input_amount - (accept_pegin_amount + fee + transaction_fees)`
- **Condition**: Only created if change amount > `DUST_VALUE` (540 sats)
- **Purpose**: Ensures the operator receives any excess funds after advancing the required amount to the user and paying fees. If the change is below the dust threshold, it is included in the transaction fees.

#### ADVANCE_FUNDS_TX Transaction Flow

```mermaid
graph TD
    A[Operator's Advance Funds Input<br/>ADVANCE_FUNDS_INPUT_TX<br/>P2WPKH - Operator's dispute key] --> B[ADVANCE_FUNDS_TX<br/>Inputs:<br/>• Input 0: Operator's Advance Funds Input<br/>  SegWit - Operator's dispute key<br/><br/>-------------------------------<br/><br/>• Input 1: Previous OPERATOR_TAKE_TX output<br/>  SegWit - Operator's dispute key<br/>  Optional]
    C[Previous OPERATOR_TAKE_TX<br/>output<br/>Optional] --> B
    B --> D[ADVANCE_FUNDS_TX<br/>Outputs:<br/>• Output 0: User Funds Output<br/>  P2WPKH - User's key<br/>  Amount: accept_pegin_amount - USER_TAKE_FEE<br/><br/>-------------------------------<br/><br/>• Output 1: OP_RETURN Output<br/>  Contains: pegout_id 32 bytes<br/><br/>-------------------------------<br/><br/>• Output 2: Operator Change Output<br/>  P2WPKH - Operator's dispute key<br/>  Amount: input_amount - user_amount - fees<br/>  Optional if change > DUST_VALUE]
    
    style A fill:#fff3e0
    style B fill:#fff3e0
    style C fill:#fff3e0
    style D fill:#fff3e0
```

**Validation Requirements**:

When `registerAdvanceFunds` is called on the Rootstock contract, the following validations are performed:

- **Output 0 Validation**:
  - Amount must equal `accept_pegin_amount - USER_TAKE_FEE`
  - Script must be P2WPKH for the user's public key
- **Output 1 Validation**:
  - Must be an OP_RETURN output
  - Must contain the correct `pegout_id` matching the one from `tryPegout`
- **Caller Validation**:
  - Caller must be the selected operator for that slot
  - Slot status must be `OP_SELECTED`

### Advance Funds Protocol Integration with Dispute Core

The Advance Funds Protocol integrates with the **Dispute Core Protocol** to provide dispute resolution mechanisms:

- **Proof of Payment**: ADVANCE_FUNDS_TX serves as proof that the operator has advanced funds to the user
- **Rootstock Registration**: After ADVANCE_FUNDS_TX is mined, the operator calls `registerAdvanceFunds` on the Rootstock contract with SPV proof
- **Status Management**: The contract changes slot status to `ADVANCED` upon successful registration
- **Dispute Resolution**: If challenged, this transaction proof validates the operator's actions
- **OPERATOR_WON_TX Execution**: If the proof is correct, OPERATOR_WON_TX will be executed
- **Reimbursement Flow**: After ADVANCE_FUNDS_TX is registered, the operator dispatches REIMBURSEMENT_KICKOFF_TX, then calls `registerReimbursementKickoff` to register it
- **Cross-Protocol Coordination**: Advance Funds Protocol coordinates with Dispute Core Protocol and Rootstock contracts for complete dispute resolution

## Glossary

### Transaction Types

- **REQUEST_PEGIN_TX**: Initial transaction created by user to request peg-in (Bitcoin → Rootstock)
- **ACCEPT_PEGIN_TX**: Main transaction that accepts the peg-in request
- **USER_TAKE_TX**: Common case transaction allowing users to claim their portion of peg-in funds (peg-out flow)
- **OPERATOR_TAKE_TX**: Fallback transaction allowing operators to claim funds (peg-out flow)
- **OPERATOR_WON_TX**: Disputed fallback transaction for operators to claim funds after winning a challenge (peg-out flow)
- **ADVANCE_FUNDS_TX**: Transaction allowing operators to advance funds to users before executing operator take transactions (peg-out flow, proof of payment)
- **REIMBURSEMENT_KICKOFF_TX**: Dispute Core protocol transaction that enables operators to claim funds through OPERATOR_TAKE_TX
- **CHALLENGE_TX**: Dispute Core protocol transaction that allows committee members to challenge operator actions if they detect incorrect behavior
- **OP_INITIAL_DEPOSIT_TX**: Dispute Core protocol transaction containing operator's initial deposit
- **REVEAL_INPUT_TX**: Dispute Core protocol transaction enabling operator to claim funds after dispute resolution (used by OPERATOR_WON_TX)
- **INPUT_NOT_REVEALED_TX**: Dispute Core protocol transaction that allows committee to claim funds if operator fails to reveal input within timelock

### Key Types

- **Committee Aggregated Key**: Multi-signature key representing the committee's collective authority
- **Operator Dispute Key**: Key used by operators for dispute resolution and fund claiming
- **Operator Speedup Key**: Key used by operators for speedup transactions
- **User Reimbursement Key**: Key used by users for fund reimbursement and speedup transactions

### Transaction Output Types

- **Taproot (P2TR)**: Pay-to-Taproot output type with key path and script path spending options
- **SegWit (P2WPKH)**: Pay-to-Witness-Public-Key-Hash output type for speedup transactions

### Spending Modes

- **Key Path**: Direct spending using a single key signature
- **Script Path**: Spending using a script with specific conditions (e.g., timelock scripts)

### Fee Structure

- **P2TR_FEE**: Fee for Taproot transactions
- **USER_TAKE_FEE**: Fee for user take transactions
- **SPEEDUP_VALUE**: Amount for speedup transactions
- **User pays**: Speedup for ACCEPT_PEGIN_TX and USER_TAKE_TX
- **Operator pays**: Speedup for OPERATOR_TAKE_TX and OPERATOR_WON_TX

### Protocol Terms

- **Peg-in Flow**: Bitcoin → Rootstock asset transfer process
- **Peg-out Flow**: Rootstock → Bitcoin asset transfer process
- **Pre-signing**: Committee members pre-sign transactions during setup phase
- **Timelock**: Time-based spending condition requiring specific block height or time
- **Dispute Resolution**: Process for resolving conflicts in operator transactions
- **OPERATOR_TAKE_ENABLER**: UTXO from REIMBURSEMENT_KICKOFF_TX output 0 that enables OPERATOR_TAKE_TX execution
- **OPERATOR_WON_ENABLER**: UTXO from REVEAL_INPUT_TX output 0 that enables OPERATOR_WON_TX execution
- **Pegout ID**: 32-byte identifier used to link peg-out requests with dispute core transactions
- **registerAdvanceFunds**: Rootstock contract function to register ADVANCE_FUNDS_TX SPV proof and update status to ADVANCED
- **registerReimbursementKickoff**: Rootstock contract function to register REIMBURSEMENT_KICKOFF_TX SPV proof and update status to KICKOFF
- **registerOperatorTake**: Rootstock contract function to register OPERATOR_TAKE_TX SPV proof and update status to COMPLETED
