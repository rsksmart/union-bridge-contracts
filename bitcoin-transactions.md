# Union Bridge Bitcoin Transactions Documentation

This document describes the Bitcoin transactions created by the Union Bridge protocols in the BitVMX system. The Accept PegIn Protocol creates several interconnected transactions that handle the acceptance of peg-in requests and provide mechanisms for operators to claim funds.

## Table of Contents

- [Union Bridge Context](#union-bridge-context)
- [Overview](#overview)
  - [User Transaction](#user-transaction)
  - [Optional - Reject Pegin](#optional---reject-pegin)
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

The Union Bridge system includes multiple protocols. This document covers the following protocols and their transaction types:

### User Transaction

1. **REQUEST_PEGIN_TX** - Initial transaction created by user to request peg-in (peg-in flow)

### Optional - Reject Pegin

1. **USER_REIMBURSEMENT_TX** - User sends this transaction after a time window to recover the funds

2. **REJECT_PEGIN_TX** - Committee members can reject a pegin transaction to avoid accepting a pegin.

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

### Transaction Relationships

The following diagram shows how all transactions across the different protocols relate to each other:

```mermaid
graph TD
    A[REQUEST_PEGIN_TX<br/>User Transaction<br/>created by user] -->|spends with committee aggregated key| B[ACCEPT_PEGIN_TX<br/>Accept PegIn Protocol]
    B -->|Output 0| C[USER_TAKE_TX<br/>User Take Protocol<br/>Common Case]
    B -->|Output 0| D[OPERATOR_TAKE_TX<br/>Accept PegIn Protocol<br/>Fallback]
    B -->|Output 0| E[OPERATOR_WON_TX<br/>Accept PegIn Protocol<br/>Disputed Fallback]
    B -->|Output 1| F[User speedup P2WPKH<br/>Accept PegIn Protocol]
    
    %% Advance Funds Protocol
    G[ADVANCE_FUNDS_TX<br/>Advance Funds Protocol<br/>Operator advances funds to user] -->|Proof of payment| H[Dispute Resolution<br/>If challenged, validates operator actions]
    H -->|If proof correct| E
    
    %% Dispute Core Protocol
    I[Dispute Core<br/>OP_INITIAL_DEPOSIT_TX] -->|spends with Winternitz signature| M[REIMBURSEMENT_KICKOFF_TX<br/>Dispute Core Protocol]
    M -->|Output 0: OPERATOR_TAKE_ENABLER| J[OPERATOR_TAKE_TX input 1<br/>Accept PegIn Protocol]
    M -->|Output 0| N[CHALLENGE_TX<br/>Dispute Core Protocol]
    K[REVEAL_INPUT_TX<br/>Dispute Core Protocol] -->|spends with committee aggregated key| L[OPERATOR_WON_TX input 1<br/>Accept PegIn Protocol]
    
    style A fill:#e1f5fe
    style B fill:#f3e5f5
    style C fill:#e8f5e8
    style D fill:#fff3e0
    style E fill:#fce4ec
    style F fill:#fff3e0
    style G fill:#fff3e0
    style H fill:#fce4ec
    style I fill:#fce4ec
    style J fill:#fce4ec
    style K fill:#fce4ec
    style L fill:#fce4ec
    style M fill:#fce4ec
    style N fill:#fce4ec
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

##### Output 2: Change Output (Optional)

- **Type**: SegWit (P2WPKH)
- **Amount**: `input_value - pegin_amount - fees` (if > 546 sats)
- **Key**: User's public key
- **Purpose**: Returns unused funds to the user
- **Condition**: Only created if change amount > 546 sats (dust threshold)

#### REQUEST_PEGIN_TX Transaction Flow

```mermaid
graph LR
    A[User's Bitcoin UTXO] --> B[REQUEST_PEGIN_TX<br/>Inputs:<br/>• Input 0: User's Bitcoin UTXO<br/>  User's private key]
    B --> C[REQUEST_PEGIN_TX<br/>Outputs:<br/>• Output 0: PegIn Request Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: OP_RETURN Output<br/>  RSK pegin metadata<br/><br/>--------------------------------<br/><br/>• Output 2: Change Output<br/>  P2WPKH - User's key]
    
    %% Flow to next transaction
    C --> D[ACCEPT_PEGIN_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#e1f5fe
    style D fill:#f3e5f5
```

### 1. USER_REIMBURSMENT_TX (User Reimbursement Transaction)

**Purpose**: This transactions can be send by the user to recover it's funds after the timelock to accept the pegin expires.

#### USER_REIMBURSMENT_TX Inputs

##### Input X (we don't know were the user is using it): From REQUEST_PEGIN_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: Script path (timelock)
- **Sighash Type**: SIGHASH_ALL
- **Timelock**: LONG_TIMELOCK blocks (from StreamSettings)
- **Key Required**: User reimbursement key `reimbursement_pubkey`
- **Previous Transaction**: REQUEST_PEGIN_TX
- **Description**: Spends the output from the request peg-in transaction using the user reimbursment key after timelock expires.
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

#### USER_REIMBURSMENT_TX Outputs

As this is a user transaction he can decide any output.

#### USER_REIMBURSMENT_TX Transaction Flow

```mermaid
graph LR
    A[User's Bitcoin UTXO] --> B[REQUEST_PEGIN_TX<br/>Inputs:<br/>• Input 0: User's Bitcoin UTXO<br/>  User's private key]
    B --> C[REQUEST_PEGIN_TX<br/>Outputs:<br/>• Output 0: PegIn Request Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: OP_RETURN Output<br/>  RSK pegin metadata<br/><br/>--------------------------------<br/><br/>• Output 2: Change Output<br/>  P2WPKH - User's key]
    
    %% Flow to next transaction
    C --> D[USER_REIMBURSMENT_TX<br/>input X<br/>Script path: Timelock Script]
    
    style A fill:#e1f5fe
    style B fill:#e1f5fe
    style C fill:#e1f5fe
    style D fill:#f3e5f5
```

### 1. ACCEPT_PEGIN_TX (Accept PegIn Transaction)

**Purpose**: This is the main transaction that accepts a peg-in request from a user and creates outputs that can be claimed by operators.

#### ACCEPT_PEGIN_TX Inputs

##### Input 0: From REQUEST_PEGIN_TX

- **Type**: Taproot (P2TR)
- **Spend Mode**: KeyOnly with Aggregate signature
- **Sighash Type**: SIGHASH_ALL
- **Key Required**: Committee aggregated key (`take_aggregated_key`)
- **Previous Transaction**: REQUEST_PEGIN_TX (must be created by user and mined before this transaction)
- **Description**: Spends the output from the request peg-in transaction (created by user) using the committee's aggregated key signature. The REQUEST_PEGIN_TX must be confirmed on the blockchain before this transaction can be executed.
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

#### ACCEPT_PEGIN_TX Outputs

##### Output 0: Main PegIn Output

- **Type**: Taproot (P2TR)
- **Amount**: `pegin_request.amount - P2TR_FEE - SPEEDUP_VALUE`
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

##### Output 1: Speedup Output

- **Type**: SegWit (P2WPKH)
- **Amount**: SPEEDUP_VALUE
- **Key**: User's reimbursement public key (`reimbursement_pubkey`)
- **Purpose**: Speedup transaction paid by the user to accelerate confirmation

#### ACCEPT_PEGIN_TX Transaction Flow

```mermaid
graph LR
    A[REQUEST_PEGIN_TX<br/>created by user<br/>output] --> B[ACCEPT_PEGIN_TX<br/>Inputs:<br/>• Input 0: REQUEST_PEGIN_TX output<br/>  Key Path: Committee Aggregated Key]
    B --> C[ACCEPT_PEGIN_TX<br/>Outputs:<br/>• Output 0: Main PegIn Output<br/>  P2TR - Committee Aggregated Key<br/><br/>--------------------------------<br/><br/>• Output 1: Speedup Output<br/>  P2WPKH - User's reimbursement key]
    
    %% Flow to next transactions
    C --> D[USER_TAKE_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    C --> E[OPERATOR_TAKE_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    C --> F[OPERATOR_WON_TX<br/>input 0<br/>Key Path: Committee Aggregated Key]
    
    style A fill:#e1f5fe
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
- **OP_INITIAL_DEPOSIT_TX**: Dispute Core protocol transaction containing operator's initial deposit
- **REVEAL_INPUT_TX**: Dispute Core protocol transaction enabling operator to claim funds after dispute resolution (used by OPERATOR_WON_TX)

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
