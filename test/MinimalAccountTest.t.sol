// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18; // Standard amount for minting (1 token with 18 decimals)
    address randomUser = makeAddr("randomUser"); // A deterministic address for non-owner tests
    SendPackedUserOp sendPackedUserOp;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        // Deploy MinimalAccount using our deployment script
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        // Deploy a mock USDC token for interaction
        usdc = new ERC20Mock();
        // Helper for crafting signed user operations
        sendPackedUserOp = new SendPackedUserOp();
        sendPackedUserOp.setUp();
    }

    function testOwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0, "Initial USDC balance should be 0");
        address dest = address(usdc); // Target contract is the mock USDC
        uint256 value = 0; // No ETH value sent in the internal call from account to USDC

        // Prepare calldata for: usdc.mint(address(minimalAccount), AMOUNT)
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, // Function selector for mint(address,uint256)
            address(minimalAccount), // Argument 1: recipient of minted tokens
            AMOUNT // Argument 2: amount to mint
        );

        // Act
        // Impersonate the owner of the MinimalAccount for the next call
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData); // Owner calls execute

        // Assert
        // Check if MinimalAccount now has the minted USDC
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT, "MinimalAccount should have minted USDC");
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act & Assert (Combined using expectRevert)
        vm.prank(randomUser); // Impersonate a random, non-owner address

        // Expect the call to revert with the specific error from the modifier
        // MinimalAccount__NotFromEntryPointOrOwner is the custom error
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData); // Attempt to call execute
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0, "Initial USDC balance should be 0");
        address dest = address(usdc); // Target contract is the mock USDC
        uint256 value = 0; // No ETH value sent in the internal call from account to USDC
        // Prepare calldata for: usdc.mint(address(minimalAccount), AMOUNT)
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, // Function selector for mint(address,uint256)
            address(minimalAccount), // Argument 1: recipient of minted tokens
            AMOUNT // Argument 2: amount to mint
        );

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);
        // Assert
        assertEq(actualSigner, minimalAccount.owner(), "Recovered signer should match the MinimalAccount owner");
    }

    function testValidateOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0, "Initial USDC balance should be 0");
        address dest = address(usdc); // Target contract is the mock USDC
        uint256 value = 0; // No ETH value sent in the internal call from account to USDC
        // Prepare calldata for: usdc.mint(address(minimalAccount), AMOUNT)
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, // Function selector for mint(address,uint256)
            address(minimalAccount), // Argument 1: recipient of minted tokens
            AMOUNT // Argument 2: amount to mint
        );

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        // Assert
        assertEq(validationData, 0, "Validation data should be 0 for valid signature");
    }

    function testEntryPointCanExcuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0, "Initial USDC balance should be 0");
        address dest = address(usdc); // Target contract is the mock USDC
        uint256 value = 0; // No ETH value sent in the internal call from account to USDC

        // Prepare calldata for: usdc.mint(address(minimalAccount), AMOUNT)
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, // Function selector for mint(address,uint256)
            address(minimalAccount), // Argument 1: recipient of minted tokens
            AMOUNT // Argument 2: amount to mint
        );

        // Act
        // Impersonate the EntryPoint of the MinimalAccount for the next call
        vm.prank(helperConfig.getConfig().entryPoint);
        minimalAccount.execute(dest, value, functionData); // EntryPoint calls execute

        // Assert
        // Check if MinimalAccount now has the minted USDC
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT, "MinimalAccount should have minted USDC");
    }

    function testNonEntryPointCannotExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0, "Initial USDC balance should be 0");
        address dest = address(usdc); // Target contract is the mock USDC
        uint256 value = 0; // No ETH value sent in the internal call from account to USDC
        // Prepare calldata for: usdc.mint(address(minimalAccount), AMOUNT)
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, // Function selector for mint(address,uint256)
            address(minimalAccount), // Argument 1: recipient of minted tokens
            AMOUNT // Argument 2: amount to mint
        );

        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp = sendPackedUserOp.generateSignedUserOperation(
            executeCallData, helperConfig.getConfig(), address(minimalAccount)
        );
        // bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(minimalAccount), 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act & Assert (Combined using expectRevert)

        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));
        // Expect the call to revert with the specific error from the modifier
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT, "MinimalAccount should have minted USDC");
    }
}
