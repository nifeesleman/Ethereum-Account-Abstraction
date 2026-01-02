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
MITimport {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig, NetworkConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// In SendPackedUserOp.s.sol
// Make sure MessageHashUtils is available for bytes32
using MessageHashUtils for bytes32;
​
contract SendPackedUserOp is Script { // Or your preferred base contract
​
    HelperConfig public helperConfig;
​
    function setUp() public {
        helperConfig = new HelperConfig();
    }
​
    function generateSignedUserOperation(
        bytes memory callData,        // The target call data for the smart account's execution
        HelperConfig.NetworkConfig memory config // Network config containing EntryPoint address and signer
    ) internal returns (PackedUserOperation memory) {
        // Step 1: Generate the Unsigned UserOperation
        // Fetch the nonce for the sender (smart account address) from the EntryPoint
        // For simplicity, we'll assume the 'config.account' is the smart account for now,
        // though in reality, this would be the smart account address, and config.account the EOA owner.
        // Nonce would be: IEntryPoint(config.entryPoint).getNonce(config.account, nonceKey);
        // For this example, let's use a placeholder nonce or assume it's passed in.
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(config.account, 0); // Simplified nonce retrieval
​
        PackedUserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            config.account, // This should be the smart account address
            nonce
        );
​
        // Step 2: Get the userOpHash from the EntryPoint
        // We need to cast the config.entryPoint address to the IEntryPoint interface
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
​
        // Prepare the hash for EIP-191 signing (standard Ethereum signed message)
        // This prepends "\x19Ethereum Signed Message:\n32" and re-hashes.
        bytes32 digest = userOpHash.toEthSignedMessageHash();
​
        // Step 3: Sign the digest
        // 'config.account' here is the EOA that owns/controls the smart account.
        // This EOA must be unlocked for vm.sign to work without a private key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest);
​
        // Construct the final signature.
        // IMPORTANT: The order is R, S, V (abi.encodePacked(r, s, v)).
        // This differs from vm.sign's return order (v, r, s).
        userOp.signature = abi.encodePacked(r, s, v);
​
        return userOp;
    }
​
    // Helper function to populate the UserOperation fields (excluding signature)
    function _generateUnsignedUserOperation(
        bytes memory callData,
        address sender, // Smart account address
        uint256 nonce
    ) internal pure returns (PackedUserOperation memory) {
        // Placeholder gas values; these should be estimated or configured properly
        uint256 verificationGasLimit = 200000;
        uint256 callGasLimit = 300000;
        uint256 maxFeePerGas = 100 gwei;
        uint256 maxPriorityFeePerGas = 2 gwei;
​
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"", // Assuming account is already deployed. Provide if deploying.
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit + 50000, // Needs proper estimation
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"", // No paymaster for this example
            signature: hex"" // Left empty, to be filled after hashing and signing
        });
    }
}