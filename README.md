Minimal Account (ERC-4337) ⚡️
================================

This repository contains a minimal smart account implementation for ERC-4337 (Account Abstraction) plus deployment and testing utilities built with Foundry. The goal is to demonstrate the core account behaviors: validating user operations, routing calls through an EntryPoint, and allowing the owner to execute arbitrary transactions.

What’s inside
-------------
- Minimal smart account: `MinimalAccount` implements `IAccount`, owner-based control, and call execution.
- EntryPoint integration: signature validation via `validateUserOp` and prefund handling hook.
- Scripts: deployment (`DeployMinimal.s.sol`), helper configuration, and a sample packed user op flow.
- Tests: Foundry tests covering owner vs non-owner execution.

Repository layout
-----------------
- `src/ethereum/MinimalAccount.sol` – account contract.
- `script/DeployMinimal.s.sol` – deploys `MinimalAccount` using the configured EntryPoint.
- `script/HelperConfig.s.sol` – network configuration helper (EntryPoint address, signer/account).
- `script/SendPackedUserOp.s.sol` – sample flow to craft and sign a `PackedUserOperation`.
- `test/MinimalAccountTest.t.sol` – unit tests for owner/non-owner execution paths.

Prerequisites
-------------
- Foundry (forge/cast). Install via `curl -L https://foundry.paradigm.xyz | bash && foundryup`.
- Node/npm (optional) if you need hardhat tooling from the `lib/account-abstraction` package.
- An RPC endpoint and funded deployer key for live deployments.

Install dependencies
--------------------
```bash
git submodule update --init --recursive   # if cloned with submodules
forge install                             # pulls remapped dependencies (optional if vendor libs are present)
forge build
```

Run tests
---------
```bash
forge test -vv
```

Deploy the minimal account
--------------------------
Set environment variables for your target network:
```bash
export RPC_URL=https://your-rpc
export PRIVATE_KEY=0x... # deployer key
```
Then broadcast the deployment script:
```bash
forge script script/DeployMinimal.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```
`DeployMinimal` returns the deployed `MinimalAccount` instance along with the helper configuration.

How the account works
---------------------
- `execute(address dest, uint256 value, bytes calldata data)`: callable by the EntryPoint or the owner. Forwards the call and reverts on failure with `MinimalAccount__CallFailed`.
- `validateUserOp(PackedUserOperation userOp, bytes32 userOpHash, uint256 missingFunds)`: EntryPoint hook that verifies the owner’s signature and optionally pre-funds the EntryPoint.
- Signature validation: wraps `userOpHash` with EIP-191 via `MessageHashUtils.toEthSignedMessageHash` and recovers with `ECDSA`.

Sending a packed UserOperation (example)
----------------------------------------
`script/SendPackedUserOp.s.sol` illustrates how to:
1) Build an unsigned `PackedUserOperation` (sender, nonce, gas limits).
2) Fetch the `userOpHash` from the EntryPoint.
3) Sign the digest with the configured EOA (owner of the account).
4) Attach the `abi.encodePacked(r, s, v)` signature and submit.

Notes and assumptions
---------------------
- `_payPrefund` is minimal; extend it to transfer missing funds to the EntryPoint in production.
- Gas limits and fee values in sample scripts are placeholders—tune per network conditions.
- The account currently uses a single-owner ECDSA model; add multisig or session keys as needed.

License
-------
MIT
