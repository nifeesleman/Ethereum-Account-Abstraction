// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig, NetworkConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";


// In SendPackedUserOp.s.sol
// Make sure MessageHashUtils is available for bytes32
using MessageHashUtils for bytes32;

contract SendPackedUserOp is Script { // Or your preferred base contract

    HelperConfig public helperConfig;

    function setUp() public {
        helperConfig = new HelperConfig();
    }

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

        PackedUserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            config.account, // This should be the smart account address
            nonce
        );

        // Step 2: Get the userOpHash from the EntryPoint
        // We need to cast the config.entryPoint address to the IEntryPoint interface
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);

        // Prepare the hash for EIP-191 signing (standard Ethereum signed message)
        // This prepends "\x19Ethereum Signed Message:\n32" and re-hashes.
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // Step 3: Sign the digest
        // 'config.account' here is the EOA that owns/controls the smart account.
        // This EOA must be unlocked for vm.sign to work without a private key.
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest);

        // Construct the final signature.
        // IMPORTANT: The order is R, S, V (abi.encodePacked(r, s, v)).
        // This differs from vm.sign's return order (v, r, s).
        userOp.signature = abi.encodePacked(r, s, v);

        return userOp;
    }

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