# Smart Contracts Quality Gate Specification

## Introduction

The purpose of this document is to introduce a checklist that helps to define quality standards for the smart contract development within the organization. The scope of the document is general, nevertheless it has a section dedicated to the Union Bridge Contracts project specifically as it is the first project that will be evaluated using these guidelines.

## Code Standards

> **Warning**
>
> All of the listed points should be covered. The ones that are more "flexible" are specified in the same point (e.g., accepting low/info Slither warnings).

## Documentation

- **Release notes**: every release should document specifically which features it implements and point to the RSKIP or document with the feature design it is implementing.
 - **Implementation decisions:** all implementation decisions not present in the feature design documents or RSKIPs must be explicitly documented, including their rationale.
- This is not all the content required for the documentation. Some of the points below also define content that must be included in the documentation too.

## Static analysis

- **Linting**: no errors or warnings are allowed. If a linter rule is disabled either in the configuration or directly in the source code the reason should be documented explicitly. The recommended linter for this repository is `forge lint` (see `Makefile`). A formatter is also recommended, specifically `forge fmt`; if a project previously used Truffle/Hardhat and therefore uses `prettier` as formatter, that is also acceptable. Future inclusion of `solhint` is recommended as well.
- **Static analysis tools:** `slither` is the recommended tool. The code must pass `slither`’s analysis. High and medium level findings are not allowed. Low and info level are allowed as long as they’re closed with the proper justification.
- **Compiler warnings**: compiler warnings should be treated as errors. No compiler warnings should be present in the smart contracts source code or the deployer scripts. Compiler warnings are acceptable for the test contracts depending on the case, but they need to be documented in the comments of the test. Any specific compiler warning ignored at project level must be documented.

> **Note**
>
> This repository uses `forge lint` (see `Makefile`). If a project prefers additional/alternative Solidity linting (e.g., `solhint`), it can be run in parallel as long as results are documented and enforced consistently.

## Compilation

- **Compiler version pinning**: both the compiler and EVM versions should be pinned in the `foundry.toml` file in order to reduce ambiguity.
- **Compiler compatibility:** if the project eventually updates the compiler version, further updates must ensure all the compiler versions that have been supported are still valid. Otherwise, this needs to be documented explicitly when updating the compiler version.
- **Contract size:** to reduce future frictions, upgradeable contracts sizes should remain well below the [EIP-170](https://eips.ethereum.org/EIPS/eip-170) size limit. E.g. 20k so we have a 4k buffer in case urgent changes are needed.
- **Bytecode determinism**: bytecode should remain deterministic. Independent builds that use the same configurations documented in the release notes should produce the exact same bytecode hash. Ideally, this should be enforced in the pipeline by building and comparing the resulting hash.

## Interfaces

- **Contract interface**: the external functionality of the contract must be entirely declared in a separate file with the interface which is implemented by the respective contract. This interface file must have a comprehensive `NatSpec` and all the declarations needed to generate a binding for any off-chain system.
- **ABI compatibility**: changes in the ABI (generated from the files of the point above) must follow [semantic versioning](https://semver.org/). Any breaking changes must be properly documented along with their rationale in the release notes.

## Testing

- **Unit tests**: unit test pass rate must be 100% without exceptions.
- **Coverage**: both the line and branch coverage should be 100%. To enforce this using `codecov` is recommended.
- **Fuzz tests**: ideally all the functions that are part of the contract interface should be fuzzed. Ideally with at least 10000 `runs`. The usage of `include_storage` and `include_push_bytes` is also recommended.
- **Invariant tests**: every feature must document and explain separately which invariants it preserves and/or adds in the code being added. It also should be tested via invariant tests. The recommended configuration is 1000 `runs` x 600 `depth`. In this case the usage of `include_storage` and `include_push_bytes` is recommended as well.
- **Fork tests**: fork testing is mandatory when interacting with any already deployed contracts. When fork testing, a block must be chosen to make the tests deterministic. Updates in the test may include changing the block and adjusting the tests accordingly. When choosing a new block, a recent one should be used. For example, after deploying a new version, tests must be changed to use the newly deployed contracts.

## Deployment / Scripts

- **Storage layout:** It needs to be ensured that there are not breaking changes for the storage of already deployed proxies. This can be done via OpenZeppelin upgrades plugin.
- **Deployment tests**: continuing with the previous point, if an existing proxy is being extended, a test simulating the upgrade and the post-upgrade expected behavior should be provided as well. Fork tests can be useful for this.
- **Upgradeability tests**: if a new proxy is being added then a test upgrading such proxy should be provided.
- **Deployment scripts testing**: any deployment scripts provided must also have their own test suite. How does this differ from the previous points? This suite should validate the set up itself. E.g. assigned roles, initialization, etc.
- **Scripts testing**: testing the scripts that are non-deployment scripts is not mandatory, but if they have any usage beyond being a development utility, then the tests become mandatory.

## Gas / Fees analysis

- **Changes in gas**: in every case a gas snapshot diff must be provided. The maximum allowed increase depends on the features being added.
- **Changes in fee model**: if the change affects the fee model or the economics of the project, the how and the why need to be explicitly documented.

## Dependencies / Security

- **Dependency pinning**: dependencies must be pinned to a specific version.
- **Lock file integrity**: lock file must match manifest. Use `npm ci` in the case of node dependencies or git submodules pointing to a specific commit in the case of forge to enforce this.
- **New dependencies**: dependencies with existing known vulnerabilities can’t be added to the project. If a new dependency is being introduced the rationale must be documented in the release notes. Approval of new dependencies is not guaranteed.
- **Organization policy compliance**: all contributions must be compliant with the organization general GH policies (no secrets, signed commits, scorecard, pinned actions, etc.)

## Monitoring

- **Events**: every state mutating function must emit an event so it can be easily monitored. If the same function performs multiple critical operations they all should emit a different event. The state of the contract should be deducible from the emitted events.
- **Guidelines**: monitoring guidelines should be documented in the feature design so it is clear later how to modify the monitoring set up to start tracking the new functionality.

## Union Bridge Contracts project specifics

The purpose for this section is to list requirements that only apply to the Union Bridge Contracts project:

- **Bridge mocking**: the mocks created for the native bridge must emulate the real behavior as much as possible. The purpose of this is to reduce the possibility of introducing bugs related to the interactions with this component. If the behavior expected from the bridge is too complex at some point, then the mock must be tested separately to ensure it implements it correctly.
- **Integration tests**: all shell integration tests in CI must pass for changes touching peg flows, scripts, or deployment.
- **BitVMX compatibility**: changes to Bitcoin tx validation must update and pass `BitVMXCompatibility.t.sol` with fresh BitVMX-generated data.
- **Bitcoin spec sync**: update `bitcoin-transactions.md` and related specs when tx structure or script encoding changes.
- **RSKIP traceability**: link changes to RSKIP-502, RSKIP-529, or other relevant RSKIPs in release notes.
- **Block gas budget**: critical-path txs must remain under 80% of RSK block gas limit, include gas consumption check results in PRs when gas-sensitive code changes.
- **Release artifacts**: on release, regenerate and commit docs (`docs/`) and Rust bindings (`crate/src/bindings/`); update `BREAKING_CHANGES.md` for any ABI change.
- **Access control via AccessManager**: any new privileged interaction must add or reuse an explicit check in `IAccessManager` / `AccessManager`, wire the caller address in deployment/upgrade scripts, and include tests for both authorized and unauthorized callers.
- **Pausability**: contracts that mutate bridge-critical state or handle value must remain pausable via `whenNotPaused` and delegate the pauser role to `AccessManager` through `PauseManager`. Adding a new pausable contract requires updating `PauseManager` wiring and the deployment script setters.
- **Testnet-only entry points**: functions intended for test environments must be guarded with `accessManager.revertIfNotTestnet()`. Their presence and removal must be tracked in release notes.

> **Note**
>
> The fork-based deployment simulation (`shell/script/deploy/simulate-deploy.sh`) is pinned at block `6438663` for determinism.
> If the pinned block is updated, adjust any dependent fork-based tests/scripts accordingly.