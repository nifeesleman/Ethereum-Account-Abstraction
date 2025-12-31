// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18; // Standard amount for minting (1 token with 18 decimals)
    address randomUser = makeAddr("randomUser"); // A deterministic address for non-owner tests

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        // Deploy MinimalAccount using our deployment script
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        // Deploy a mock USDC token for interaction
        usdc = new ERC20Mock();
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
}
