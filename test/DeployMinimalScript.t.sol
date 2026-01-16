// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

contract DeployMinimalScriptTest is Test {
    uint256 constant DEFAULT_ANVIL_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;

    DeployMinimal private deployer;

    function setUp() public {
        deployer = new DeployMinimal();
    }

    function testLocalDeployUsesDefaultKeyAndSetsOwner() public {
        uint256 originalChainId = block.chainid;
        vm.chainId(31337);

        (HelperConfig helperConfig, MinimalAccount minimalAccount) = deployer.deployMinimalAccount();

        assertEq(minimalAccount.owner(), vm.addr(DEFAULT_ANVIL_PK));
        assertEq(minimalAccount.getEntryPoint(), helperConfig.entryPoint());

        vm.chainId(originalChainId);
    }

    function testDeployPrefersEnvPrivateKeyForNonLocal() public {
        uint256 originalChainId = block.chainid;
        uint256 envPk = 0xbabe;
        vm.setEnv("PRIVATE_KEY", vm.toString(envPk));
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);

        (HelperConfig helperConfig, MinimalAccount minimalAccount) = deployer.deployMinimalAccount();

        HelperConfig.NetworkConfig memory cfg = helperConfig.getConfigByChainId(ETH_SEPOLIA_CHAIN_ID);
        assertEq(minimalAccount.owner(), vm.addr(envPk));
        assertEq(minimalAccount.getEntryPoint(), cfg.entryPoint);

        vm.setEnv("PRIVATE_KEY", "");
        vm.chainId(originalChainId);
    }

    function testDeployFallsBackToDefaultBroadcasterWhenEnvMissing() public {
        uint256 originalChainId = block.chainid;
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "");

        (HelperConfig helperConfig, MinimalAccount minimalAccount) = deployer.deployMinimalAccount();

        HelperConfig.NetworkConfig memory cfg = helperConfig.getConfigByChainId(ETH_SEPOLIA_CHAIN_ID);
        assertTrue(minimalAccount.owner() != address(0));
        assertEq(minimalAccount.getEntryPoint(), cfg.entryPoint);

        vm.chainId(originalChainId);
    }
}
