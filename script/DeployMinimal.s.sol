//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    uint256 constant DEFAULT_ANVIL_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public {
        deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        
        // Handle private key: works with both --private-key flag and PRIVATE_KEY env var
        // For local Anvil, use default key
        if (block.chainid == 31337) {
            // Local Anvil network - use default key
            uint256 deployerKey = DEFAULT_ANVIL_PK;
            address deployer = vm.addr(deployerKey);
            vm.startBroadcast(deployerKey);
            MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
            // Account owner is set to msg.sender in constructor, but we want it to be deployer
            minimalAccount.transferOwnership(deployer);
            vm.stopBroadcast();
            return (helperConfig, minimalAccount);
        } else {
            // For mainnet/testnet: try environment variable first, then --private-key flag
            try vm.envUint("PRIVATE_KEY") returns (uint256 deployerKey) {
                // PRIVATE_KEY env var is set
                address deployer = vm.addr(deployerKey);
                vm.startBroadcast(deployerKey);
                MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
                minimalAccount.transferOwnership(deployer);
                vm.stopBroadcast();
                return (helperConfig, minimalAccount);
            } catch {
                // PRIVATE_KEY env var not set, use --private-key flag
                // vm.startBroadcast() without args uses the --private-key flag value
                vm.startBroadcast();
                MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
                // Account owner is already set to msg.sender (the deployer from --private-key)
                // No need to transfer ownership as it's already correct
                vm.stopBroadcast();
                return (helperConfig, minimalAccount);
            }
        }
    }
}
