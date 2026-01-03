// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HelperConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {ILegacyEntryPoint} from "src/ethereum/ILegacyEntryPoint.sol";

// In SendPackedUserOp.s.sol
// Make sure MessageHashUtils is available for bytes32
using MessageHashUtils for bytes32;

contract SendPackedUserOp is
    Script // Or your preferred base contract
{
    HelperConfig public helperConfig;

    function setUp() public {
        helperConfig = new HelperConfig();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address smartAccount
    ) public view returns (ILegacyEntryPoint.UserOperation memory) {
        uint256 nonce = ILegacyEntryPoint(config.entryPoint).getNonce(smartAccount, 0);

        ILegacyEntryPoint.UserOperation memory userOp = _generateUnsignedUserOperation(
            callData,
            smartAccount,
            nonce
        );

        bytes32 userOpHash = ILegacyEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint256 signerPk = block.chainid == 31337 ? ANVIL_PRIVATE_KEY : vm.envUint("PRIVATE_KEY");
        (v, r, s) = vm.sign(signerPk, digest);

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
}
