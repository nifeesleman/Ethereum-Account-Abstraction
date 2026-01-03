// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HelperConfig} from "script/HelperConfig.s.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal interface for the legacy (v0.6) EntryPoint deployed at 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789.
interface ILegacyEntryPoint {
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    function getNonce(address sender, uint192 key) external view returns (uint256);
    function getUserOpHash(UserOperation calldata userOp) external view returns (bytes32);
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;
}

// In SendPackedUserOp.s.sol
// Make sure MessageHashUtils is available for bytes32
using MessageHashUtils for bytes32;

contract SendPackedUserOp is
    Script // Or your preferred base contract
{
    HelperConfig public helperConfig;

    function run() public {
        helperConfig = new HelperConfig();
        address dest = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum Mainnet USDC
        uint256 value = 0; // No ETH value sent in the internal call from account to USDC
        bytes memory functionData = abi.encodeWithSelector(
            IERC20.approve.selector,
            0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC, // Spender address (another EOA)
            1e18 // Amount to approve (Note: USDC has 6 decimals, so 1e18 is a very large USDC amount)
        );
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        // The MinimalAccount address deployed earlier
        address minimalAccountAddress = address(0x03Ad95a54f02A40180D45D76789C448024145aaF);
        ILegacyEntryPoint.UserOperation memory userOp = generateSignedUserOperation(
            executeCallData,
            helperConfig.getConfig(), // Contains network config like EntryPoint address
            minimalAccountAddress
        );
        ILegacyEntryPoint.UserOperation[] memory ops = new ILegacyEntryPoint.UserOperation[](1);
        ops[0] = userOp;
        vm.startBroadcast();
        // The beneficiary address receives gas refunds
        address payable beneficiary = payable(helperConfig.getConfig().account); // Typically the burner account
        ILegacyEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, beneficiary);
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData, // The target call data for the smart account's execution
        HelperConfig.NetworkConfig memory config, // Network config containing EntryPoint address and signer
        address minimalAccount // The smart account address
    ) public view returns (ILegacyEntryPoint.UserOperation memory) {
        // Step 1: Generate the Unsigned UserOperation
        // Fetch the nonce for the sender (smart account address) from the EntryPoint
        // For simplicity, we'll assume the 'config.account' is the smart account for now,
        // though in reality, this would be the smart account address, and config.account the EOA owner.
        // Nonce would be: IEntryPoint(config.entryPoint).getNonce(config.account, nonceKey);
        // For this example, let's use a placeholder nonce or assume it's passed in.
        uint256 nonce = ILegacyEntryPoint(config.entryPoint).getNonce(minimalAccount, 0); // Simplified nonce retrieval

        ILegacyEntryPoint.UserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            minimalAccount, // This should be the smart account address
            nonce
        );

        // Step 2: Get the userOpHash from the EntryPoint
        // We need to cast the config.entryPoint address to the IEntryPoint interface
        bytes32 userOpHash = ILegacyEntryPoint(config.entryPoint).getUserOpHash(userOp);

        // Prepare the hash for EIP-191 signing (standard Ethereum signed message)
        // This prepends "\x19Ethereum Signed Message:\n32" and re-hashes.
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        // Step 3: Sign the digest
        // 'config.account' here is the EOA that owns/controls the smart account.
        // This EOA must be unlocked for vm.sign to work without a private key.
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 signerPk;
        uint256 ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            signerPk = ANVIL_PRIVATE_KEY;
        } else {
            // Accept PRIVATE_KEY with or without 0x prefix from the environment.
            signerPk = _readPrivateKey();
        }
        (v, r, s) = vm.sign(signerPk, digest);
        // (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest);

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
    )
        internal
        pure
        returns (ILegacyEntryPoint.UserOperation memory)
    {
        // Placeholder gas values; these should be estimated or configured properly
        uint256 verificationGasLimit = 200000;
        uint256 callGasLimit = 300000;
        uint256 maxFeePerGas = 100 gwei;
        uint256 maxPriorityFeePerGas = 2 gwei;

        return ILegacyEntryPoint.UserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"", // Assuming account is already deployed. Provide if deploying.
            callData: callData,
            callGasLimit: callGasLimit,
            verificationGasLimit: verificationGasLimit,
            preVerificationGas: verificationGasLimit + 50000, // Needs proper estimation
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            paymasterAndData: hex"", // No paymaster for this example
            signature: hex"" // Left empty, to be filled after hashing and signing
        });
    }

    function _readPrivateKey() internal view returns (uint256) {
        string memory raw = vm.envString("PRIVATE_KEY");
        bytes memory strBytes = bytes(raw);
        uint256 start = 0;
        if (strBytes.length >= 2 && strBytes[0] == "0" && (strBytes[1] == "x" || strBytes[1] == "X")) {
            start = 2; // skip 0x
        }
        uint256 len = strBytes.length - start;
        require(len > 0 && len <= 64, "bad pk length");
        uint256 acc = 0;
        for (uint256 i = start; i < strBytes.length; i++) {
            uint8 c = uint8(strBytes[i]);
            uint8 val;
            if (c >= 48 && c <= 57) {
                val = c - 48; // '0'-'9'
            } else if (c >= 97 && c <= 102) {
                val = 10 + (c - 97); // 'a'-'f'
            } else if (c >= 65 && c <= 70) {
                val = 10 + (c - 65); // 'A'-'F'
            } else {
                revert("bad pk char");
            }
            acc = (acc << 4) | uint256(val);
        }
        return acc;
    }
}
