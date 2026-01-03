// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HelperConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Script} from "forge-std/Script.sol";
import {ILegacyEntryPoint} from "src/ethereum/ILegacyEntryPoint.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// In SendPackedUserOp.s.sol
// Make sure MessageHashUtils is available for bytes32
using MessageHashUtils for bytes32;

contract SendPackedUserOp is
    Script // Or your preferred base contract
{
    HelperConfig public helperConfig;

    function run() public {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        address smartAccount = vm.envOr("MINIMAL_ACCOUNT", address(0));
        require(smartAccount != address(0), "MINIMAL_ACCOUNT not set");
        require(smartAccount.code.length > 0, "MINIMAL_ACCOUNT has no contract code");

        // Arbitrum mainnet USDC approve example
        address dest = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(
            IERC20.approve.selector,
            0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC, // spender
            1e18 // amount
        );

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);

        ILegacyEntryPoint.UserOperation memory userOp = generateSignedUserOperation(
            executeCallData,
            config,
            smartAccount
        );

        ILegacyEntryPoint.UserOperation[] memory ops = new ILegacyEntryPoint.UserOperation[](1);
        ops[0] = userOp;

        uint256 anvilPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint256 signerPk = block.chainid == 31337 ? anvilPrivateKey : vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(signerPk);
        ILegacyEntryPoint(config.entryPoint).handleOps(ops, payable(config.account));
        vm.stopBroadcast();
    }

    function setUp() public {
        helperConfig = new HelperConfig();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address smartAccount
    ) public view returns (ILegacyEntryPoint.UserOperation memory) {
        uint256 nonce = ILegacyEntryPoint(config.entryPoint).getNonce(smartAccount, 0);

        ILegacyEntryPoint.UserOperation memory userOp = _generateUnsignedUserOperation(callData, smartAccount, nonce);

        bytes32 userOpHash = ILegacyEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 anvilPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        uint256 signerPk = vm.envOr("PRIVATE_KEY", anvilPrivateKey);
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
