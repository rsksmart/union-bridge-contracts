# Copilot Instructions for Union Bridge Contracts

## Project context

This repository contains the Solidity contracts, specifications, tests, scripts, and generated artifacts for the Union Bridge protocol on Rootstock. Treat this as security-critical bridge software. Prefer correctness, explicitness, auditability, and testability over cleverness or brevity.

The core architecture includes:
- RbtcBridge as the single intermediary contract authorized by the Rootstock PowPeg Bridge for RBTC minting and burning.
- PeginManager for Bitcoin to Rootstock peg-in acceptance.
- PegoutManager for Rootstock to Bitcoin peg-out requests.
- Access control through OpenZeppelin AccessManager.
- UUPS upgradeable contracts and proxy deployments.
- Interaction with the Rootstock precompiled bridge at 0x0000000000000000000000000000000001000006.
- Local testing through BridgeMock.

## Tech stack and tooling

- Solidity: follow the repository foundry.toml; currently solc_version = "0.8.33" and evm_version = "london".
- Use Foundry conventions for contracts, tests, scripts, fixtures, and deployment code.
- Do not introduce Hardhat, Truffle, or unrelated frameworks.
- Use existing remappings, OpenZeppelin upgrade libraries, and repository scripts.
- Before suggesting changes, consider whether generated docs, Rust bindings, or deployment artifacts must also be updated.

Common commands:
- Unit tests: bash test.sh
- Integration/local suite: bash run.sh
- Coverage: bash coverage.sh
- Contract size: bash shell/size-report.sh
- Gas report: bash shell/gas-report.sh
- Committee-size gas checks: bash shell/gas-consumption.sh
- Release artifacts: bash release.sh

## Solidity style

- Match the existing repository style before introducing new patterns.
- Use explicit visibility, explicit mutability, custom errors, and named events.
- Prefer small functions with clear authorization and validation boundaries.
- Avoid hidden side effects and avoid unnecessary inheritance.
- Preserve storage layout compatibility for upgradeable contracts.
- Never reorder, remove, or change the type of existing storage variables in upgradeable contracts unless the change is explicitly part of a migration plan.
- Add storage gaps only when consistent with the surrounding contract pattern.
- Avoid tx.origin.
- Avoid unbounded loops over user-controlled or configuration-controlled arrays unless there is a clear gas-bound rationale.
- Avoid low-level calls unless necessary; when used, validate return values and document the reason.
- Keep external calls after state changes where appropriate and protect reentrant paths.
- Use nonReentrant on value-moving or bridge-interacting flows where the pattern requires it.
- Preserve the explicit gas-limit behavior for RBTC transfers unless there is a reviewed security reason to change it.

## NatSpec and documentation

Use Solidity NatSpec for all:
- Interfaces
- Libraries
- Structs
- Events
- Errors
- External and public functions
- External and public variables

NatSpec should explain protocol intent, authorization requirements, state transitions, expected reverts, and security assumptions. For bridge-critical paths, document which actor is expected to call the function and which invariant is protected.

## Security review priorities

When reviewing or generating code, pay special attention to:
- Unauthorized minting or burning of RBTC.
- Incorrect AccessManager role checks or target/function permissions.
- UUPS upgrade authorization and initializer/reinitializer safety.
- Reentrancy around RBTC transfers, external calls, callbacks, and bridge interactions.
- Incorrect peg-in or peg-out state transitions.
- Replay, duplicate packet, duplicate signature, or duplicate request handling.
- Incorrect committee threshold or signature validation logic.
- Missing checks for zero addresses, zero amounts, malformed Bitcoin addresses, invalid packets, expired requests, or wrong stream IDs.
- Gas griefing and denial-of-service risks.
- Integer unit mistakes between satoshis, wei, BTC, and RBTC.
- Unsafe assumptions about block timestamps, confirmations, challenge windows, and timeout logic.
- Incorrect handling of Rootstock network differences: local, regtest, alphanet, testnet, and mainnet.
- Any change to the precompiled bridge interface or address.

## Testing expectations

For every behavioral change, add or update Foundry tests.

Prefer tests that cover:
- Success path.
- Authorization failure.
- Invalid input failure.
- Boundary values.
- Repeated calls and duplicate requests.
- State transition ordering.
- Event emission.
- Upgrade/initializer behavior when relevant.
- Gas-sensitive paths when committee size or packet count can grow.
- Integration with BridgeMock for PowPeg interactions.

Use existing test helpers and fixtures instead of duplicating setup logic. Keep tests deterministic and avoid depending on external RPC endpoints unless the script is explicitly an integration or deployment script.

## Deployment and scripts

- Follow existing script/ and shell/script/deploy/ conventions.
- Never hardcode private keys, secrets, RPC URLs, or production-only values.
- Keep deployment scripts network-aware.
- For testnet/alphanet/mainnet deployments, remember that the PowPeg Bridge must authorize the deployed RbtcBridge.
- For local Anvil/regtest flows, use BridgeMock and existing local configuration patterns.

## Code review output

When asked to review code, structure feedback as:

### Critical issues
Must fix before merge. Include security, correctness, upgrade-safety, or fund-loss risks.

### Suggestions
Improvements for maintainability, clarity, gas, tests, or documentation.

### Good practices
Call out what is done well.

For each issue, include:
- Specific file and line references when available.
- Clear explanation of the risk.
- A concrete suggested fix.
- A short rationale.

Be constructive, concise, and security-minded.
