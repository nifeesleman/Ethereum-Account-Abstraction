// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockLegacyEntryPoint} from "src/ethereum/MockLegacyEntryPoint.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();
    address public entryPoint; // Latest deployed EntryPoint for local configs

    // Configuration struct
    struct NetworkConfig {
        address entryPoint;
        address account; // Deployer/burner wallet address
    }

    // Chain ID Constants
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant ZKSYNC_SEPOLIA_CHAIN_ID = 300;
    uint256 constant LOCAL_CHAIN_ID = 31337; // Anvil default
    uint256 constant ARBITRUM_MAINNET_CHAIN_ID = 42161;

    // Official Sepolia EntryPoint address: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
    // address constant FOUNDRY_DEFAULT_WALLET = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    address constant ANVIL_DEFAULT_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Anvil default
    address constant BURNER_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Replace with your actual address

    // State Variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CHAIN_ID] = getZkSyncSepoliaConfig();
        networkConfigs[ARBITRUM_MAINNET_CHAIN_ID] = getArbitrumMainnetConfig();
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET});
    }

    function getArbitrumMainnetConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, // Example EntryPoint on Arbitrum
            account: BURNER_WALLET
        });
    }

    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        // ZKSync Era has native account abstraction; an external EntryPoint might not be used in the same way.
        // address(0) is used as a placeholder or to indicate reliance on native mechanisms.
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        }
        if (networkConfigs[chainId].account != address(0)) {
            // Check if config exists
            return networkConfigs[chainId];
        }
        revert HelperConfig__InvalidChainId();
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }
        // NetworkConfig memory sepoliaConfig = getEthSepoliaConfig(); // Or a specific local mock entry point
        // localNetworkConfig = NetworkConfig({
        //     entryPoint: sepoliaConfig.entryPoint, // Replace with actual mock entry point if deployed
        //     account: BURNER_WALLET
        // });
        // return localNetworkConfig;
        vm.startBroadcast(ANVIL_DEFAULT_WALLET);
        console2.log("Creating new Anvil network config (legacy EntryPoint mock)...");
        MockLegacyEntryPoint deployedEntryPoint = new MockLegacyEntryPoint();
        vm.stopBroadcast();
        entryPoint = address(deployedEntryPoint);
        localNetworkConfig = NetworkConfig({entryPoint: address(deployedEntryPoint), account: ANVIL_DEFAULT_WALLET});
        return localNetworkConfig;
    }
}
