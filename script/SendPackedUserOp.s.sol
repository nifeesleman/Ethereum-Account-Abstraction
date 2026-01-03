// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {HelperConfig} from "script/HelperConfig.s.sol"; // Assuming NetworkConfig is defined or imported here
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Script, console2} from "forge-std/Script.sol";
import {ILegacyEntryPoint} from "src/ethereum/ILegacyEntryPoint.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// In SendPackedUserOp.s.sol
// Make sure MessageHashUtils is available for bytes32
using MessageHashUtils for bytes32;

// Minimal interface for depositTo on EntryPoint v0.6
interface IEntryPointPayable {
    function depositTo(address account) external payable;
    function balanceOf(address account) external view returns (uint256);
}

contract SendPackedUserOp is
    Script // Or your preferred base contract
{
    HelperConfig public helperConfig;
    uint256 private constant DEFAULT_ANVIL_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public {
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Set MINIMAL_ACCOUNT environment variable before running:
        // export MINIMAL_ACCOUNT=0x988B4cCfD9846CEcAA5450Ad2668839247E77d98
        address smartAccount = vm.envOr("MINIMAL_ACCOUNT", address(0));
        require(smartAccount != address(0), "MINIMAL_ACCOUNT not set");
        require(smartAccount.code.length > 0, "MINIMAL_ACCOUNT has no contract code");

        uint256 signerPk = _getSignerPrivateKey();
        address signer = vm.addr(signerPk);
        
        // Verify that the signer matches the account owner
        address accountOwner = MinimalAccount(payable(smartAccount)).owner();
        require(signer == accountOwner, "Signer must be the account owner");
        
        console2.log("Smart Account:", smartAccount);
        console2.log("Signer/Owner:", signer);
        console2.log("EntryPoint:", config.entryPoint);

        // Generate user operation
        bytes memory executeCallData = _buildExecuteCallData();
        ILegacyEntryPoint.UserOperation memory userOp = generateSignedUserOperation(
            executeCallData,
            config,
            smartAccount,
            signerPk
        );

        uint256 requiredPrefund = _estimatePrefund(userOp);
        vm.startBroadcast(signerPk);
        
        _ensurePrefund(smartAccount, config.entryPoint, requiredPrefund, signerPk);
        _ensureAccountBalance(smartAccount, requiredPrefund, signer);

        ILegacyEntryPoint.UserOperation[] memory ops = new ILegacyEntryPoint.UserOperation[](1);
        ops[0] = userOp;

        console2.log("Sending user operation...");
        console2.log("UserOp nonce:", userOp.nonce);
        console2.log("Required prefund:", requiredPrefund);
        console2.log("Account ETH balance:", smartAccount.balance);
        console2.log("EntryPoint deposit:", IEntryPointPayable(config.entryPoint).balanceOf(smartAccount));
        
        // Note: If this fails with AA23 error, the deployed MinimalAccount contract
        // may be an old version without the EntryPoint check and proper error handling.
        // Redeploy MinimalAccount with the latest code using DeployMinimal.s.sol
        ILegacyEntryPoint(config.entryPoint).handleOps(ops, payable(config.account));
        
        console2.log("User operation executed successfully!");
        vm.stopBroadcast();
    }

    function _getSignerPrivateKey() internal view returns (uint256) {
        if (block.chainid == 31337) {
            return DEFAULT_ANVIL_PK;
        }
        return vm.envUint("PRIVATE_KEY");
    }

    function _buildExecuteCallData() internal pure returns (bytes memory) {
        address dest = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // USDC
        bytes memory functionData = abi.encodeWithSelector(
            IERC20.approve.selector,
            0x9EA9b0cc1919def1A3CfAEF4F7A66eE3c36F86fC, // spender
            1e18 // amount
        );
        return abi.encodeWithSelector(MinimalAccount.execute.selector, dest, uint256(0), functionData);
    }

    function _ensureAccountBalance(address smartAccount, uint256 requiredPrefund, address signer) internal {
        // Account needs ETH balance to pay prefund in validateUserOp
        // Add generous buffer to account for gas price fluctuations and ensure payment succeeds
        uint256 requiredBalance = requiredPrefund + (requiredPrefund / 2); // 50% buffer
        uint256 accountBalance = smartAccount.balance;
        
        if (accountBalance >= requiredBalance) {
            return;
        }
        
        uint256 needed = requiredBalance - accountBalance;
        uint256 signerBal = signer.balance;
        // Reserve more ETH for transaction fees on Arbitrum
        uint256 reserveForFees = 0.0002 ether;
        
        if (signerBal <= reserveForFees) {
            console2.log("Warning: Signer has insufficient balance for fees");
            return;
        }
        
        uint256 available = signerBal - reserveForFees;
        if (needed > available) {
            needed = available;
            console2.log("Warning: Transferring partial amount due to signer balance limits");
        }
        
        if (needed > 0) {
            payable(smartAccount).transfer(needed);
            console2.log("Transferred ETH to account:", needed);
        }
    }

    function setUp() public {
        helperConfig = new HelperConfig();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address smartAccount,
        uint256 signerPk
    ) public view returns (ILegacyEntryPoint.UserOperation memory) {
        uint256 nonce = ILegacyEntryPoint(config.entryPoint).getNonce(smartAccount, 0);

        ILegacyEntryPoint.UserOperation memory userOp = _generateUnsignedUserOperation(callData, smartAccount, nonce);

        bytes32 userOpHash = ILegacyEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
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
        // Increased gas limits for Arbitrum mainnet to avoid OOG errors
        // Higher limits to handle validation, signature recovery, and prefund payment
        uint256 verificationGasLimit = 300_000; // Increased to handle validation with old contract
        uint256 callGasLimit = 200_000; // Sufficient for the actual call
        uint256 preVerificationGas = 100_000; // For calldata and overhead
        uint256 maxFeePerGas = 0.05 gwei;
        uint256 maxPriorityFeePerGas = 0.01 gwei;

        return ILegacyEntryPoint.UserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"", // Assuming account is already deployed. Provide if deploying.
            callData: callData,
            callGasLimit: callGasLimit,
            verificationGasLimit: verificationGasLimit,
            preVerificationGas: preVerificationGas, // Needs proper estimation
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            paymasterAndData: hex"", // No paymaster for this example
            signature: hex"" // Left empty, to be filled after hashing and signing
        });
    }

    // Rough prefund estimation: maxFeePerGas * (callGas + verificationGas + preVerificationGas)
    function _estimatePrefund(ILegacyEntryPoint.UserOperation memory userOp) internal pure returns (uint256) {
        uint256 gasSum = userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas;
        uint256 base = gasSum * userOp.maxFeePerGas;
        // Add 50% buffer to reduce AA23 risk, and enforce a small floor suitable for Arbitrum.
        uint256 buffered = base + (base / 2);
        uint256 floorAmount = 0.00001 ether;
        return buffered > floorAmount ? buffered : floorAmount;
    }

    function _ensurePrefund(address smartAccount, address entryPoint, uint256 requiredPrefund, uint256 signerPk)
        internal
    {
        address signer = vm.addr(signerPk);
        uint256 signerBal = signer.balance;

        uint256 currentDeposit = IEntryPointPayable(entryPoint).balanceOf(smartAccount);
        if (currentDeposit >= requiredPrefund) {
            return;
        }

        uint256 needed = requiredPrefund - currentDeposit;

        // Cap to broadcaster balance to avoid OutOfFunds; best-effort.
        if (needed > signerBal) {
            needed = signerBal;
        }

        if (needed == 0) {
            revert("Broadcaster has no ETH for prefund");
        }

        IEntryPointPayable(entryPoint).depositTo{value: needed}(smartAccount);
    }
}
