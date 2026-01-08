// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ZkMinimalAccountTest is Test {
    ZkMinimalAccount zkMinimalAccount;
   ERC20Mock usdc; // A deterministic address for non-owner tests

    function setUp() public {
        // Deploy ZkMinimalAccount with the test contract as the owner
        zkMinimalAccount = new ZkMinimalAccount(address(this));
        usdc = new ERC20Mock();
    }

   function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address dest = address(usdc); // The target contract is the mock USDC
        uint256 value = 0;           // No ETH sent with the call itself
        bytes memory functionData = abi.encodeWithSelector(
            ERC20Mock.mint.selector, // Function selector for mint(address,uint256)
            address(zkMinimalAccount), // Argument 1: recipient of minted tokens
            1e18 // Argument 2: amount to mint
        );
   }
}