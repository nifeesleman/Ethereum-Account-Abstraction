// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/tokimen/ERC20Mock.sol";

import {
    Transaction
} from "foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

contract ZkMinimalAccountTest is Test {
    ZkMinimalAccount zkMinimalAccount;
   ERC20Mock usdc; // A deterministic address for non-owner tests


    uint256 constant AMOUNT = 1e18; // Standard amount for minting (1 token with 18 decimals)
    bytes32 constant EMPTY_BYTES32 = bytes32(0);
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
        Transsaction memory transaction = _createUnsignedTransaction(
            minimalAccount.owner(),
            113,
            dest,
            value,
            functionData,
        );
        // Act
        vm.prank(minimalAccount.owner());
        zkMinimalAccount.executeTransaction(dest, value, functionData); // Owner calls execute
   }

   function _createUnsignedTransaction(
        
        address to,
        address from,
        uint256 value,
        bytes memory data,
        uint256 nonce
    ) internal pure returns (Transaction memory) {
        uint256 nonce =vm.getNonce(address(minimalAccount));
        bytes[] mwmory factoryDeps = new bytes[](0);
        return Transaction({
            to: to,
            from:
            value: value,
            data: data,
            nonce: nonce,
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 1677721,
            paymaster: address(0),
            nonce = nonce,
            Value: value,
            reserved: [uint256 (0), uint256(0), uint256(0),uint256(0)]
            data: data,
            signature: hex""
            factoryDeps: factoryDeps
            paymasterInput: hex"",
            reservedDynamic: hex""
        }).encode();
    }
}