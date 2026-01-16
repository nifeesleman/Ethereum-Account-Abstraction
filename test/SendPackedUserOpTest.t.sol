// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {MockLegacyEntryPoint} from "src/ethereum/MockLegacyEntryPoint.sol";
import {ILegacyEntryPoint} from "src/ethereum/ILegacyEntryPoint.sol";

contract MockEntryPointWithDeposit is MockLegacyEntryPoint {
    mapping(address => uint256) internal deposits;

    function depositTo(address account) external payable {
        deposits[account] += msg.value;
    }

    function balanceOf(address account) external view returns (uint256) {
        return deposits[account];
    }
}

contract SendPackedUserOpHarness is SendPackedUserOp {
    function exposed_buildExecuteCallData() external pure returns (bytes memory) {
        return _buildExecuteCallData();
    }

    function exposed_getSignerPrivateKey() external view returns (uint256) {
        return _getSignerPrivateKey();
    }

    function exposed_generateUnsignedUserOperation(bytes memory callData, address sender, uint256 nonce)
        external
        pure
        returns (ILegacyEntryPoint.UserOperation memory)
    {
        return _generateUnsignedUserOperation(callData, sender, nonce);
    }

    function exposed_estimatePrefund(ILegacyEntryPoint.UserOperation memory userOp) external pure returns (uint256) {
        return _estimatePrefund(userOp);
    }

    function exposed_ensurePrefund(address smartAccount, address entryPoint, uint256 requiredPrefund, uint256 signerPk)
        external
    {
        _ensurePrefund(smartAccount, entryPoint, requiredPrefund, signerPk);
    }

    function exposed_ensureAccountBalance(address smartAccount, uint256 requiredPrefund, address signer) external {
        _ensureAccountBalance(smartAccount, requiredPrefund, signer);
    }
}

contract SendPackedUserOpTest is Test {
    uint256 constant DEFAULT_ANVIL_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;

    SendPackedUserOpHarness harness;

    function setUp() public {
        harness = new SendPackedUserOpHarness();
    }

    function testGetSignerPrivateKeyReturnsDefaultForLocal() public {
        uint256 originalChainId = block.chainid;
        vm.chainId(31337);
        assertEq(harness.exposed_getSignerPrivateKey(), DEFAULT_ANVIL_PK);
        vm.chainId(originalChainId);
    }

    function testGetSignerPrivateKeyUsesEnvOnNonLocal() public {
        uint256 originalChainId = block.chainid;
        vm.chainId(ETH_SEPOLIA_CHAIN_ID);
        vm.setEnv("PRIVATE_KEY", "0x1234");
        uint256 expectedPk = vm.envUint("PRIVATE_KEY");
        assertEq(harness.exposed_getSignerPrivateKey(), expectedPk);
        vm.chainId(originalChainId);
    }

    function testEstimatePrefundAppliesFloorWhenZeroGas() public {
        ILegacyEntryPoint.UserOperation memory userOp;
        uint256 prefund = harness.exposed_estimatePrefund(userOp);
        assertEq(prefund, 0.00001 ether);
    }

    function testEstimatePrefundUsesBufferedGasSum() public {
        ILegacyEntryPoint.UserOperation memory userOp = harness.exposed_generateUnsignedUserOperation("", address(1), 0);
        uint256 gasSum = userOp.callGasLimit + userOp.verificationGasLimit + userOp.preVerificationGas;
        uint256 expected = gasSum * userOp.maxFeePerGas;
        expected = expected + (expected / 2);
        assertEq(harness.exposed_estimatePrefund(userOp), expected);
    }

    function testBuildExecuteCallDataEncodesApprove() public {
        bytes memory data = harness.exposed_buildExecuteCallData();
        bytes memory args = new bytes(data.length - 4);
        for (uint256 i = 0; i < args.length; i++) {
            args[i] = data[i + 4];
        }
        (address dest, uint256 value, bytes memory inner) = abi.decode(args, (address, uint256, bytes));

        assertEq(bytes4(data), MinimalAccount.execute.selector);
        assertEq(dest, 0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        assertEq(value, 0);
        assertEq(bytes4(inner), bytes4(0x095ea7b3));
    }

    function testEnsurePrefundNoActionWhenDepositSufficient() public {
        MockEntryPointWithDeposit entryPoint = new MockEntryPointWithDeposit();
        MinimalAccount account = new MinimalAccount(address(entryPoint));

        entryPoint.depositTo{value: 1 ether}(address(account));
        uint256 beforeDep = entryPoint.balanceOf(address(account));

        harness.exposed_ensurePrefund(address(account), address(entryPoint), 0.5 ether, DEFAULT_ANVIL_PK);

        assertEq(entryPoint.balanceOf(address(account)), beforeDep);
    }

    function testEnsurePrefundRevertsWhenBroadcasterHasNoFunds() public {
        MockEntryPointWithDeposit entryPoint = new MockEntryPointWithDeposit();
        MinimalAccount account = new MinimalAccount(address(entryPoint));
        address signer = vm.addr(DEFAULT_ANVIL_PK);
        vm.deal(signer, 0);
        vm.deal(address(harness), 0);

        vm.expectRevert(bytes("Broadcaster has no ETH for prefund"));
        harness.exposed_ensurePrefund(address(account), address(entryPoint), 0.1 ether, DEFAULT_ANVIL_PK);
    }

    function testEnsurePrefundCapsToSignerBalance() public {
        MockEntryPointWithDeposit entryPoint = new MockEntryPointWithDeposit();
        MinimalAccount account = new MinimalAccount(address(entryPoint));
        address signer = vm.addr(DEFAULT_ANVIL_PK);
        vm.deal(signer, 0.5 ether);
        vm.deal(address(harness), 0.5 ether);

        harness.exposed_ensurePrefund(address(account), address(entryPoint), 1 ether, DEFAULT_ANVIL_PK);

        assertEq(entryPoint.balanceOf(address(account)), 0.5 ether);
    }

    function testEnsureAccountBalanceNoTransferWhenSufficient() public {
        MinimalAccount account = new MinimalAccount(address(0x1));
        vm.deal(address(account), 2 ether);
        harness.exposed_ensureAccountBalance(address(account), 1 ether, vm.addr(DEFAULT_ANVIL_PK));
        assertEq(address(account).balance, 2 ether);
    }

    function testEnsureAccountBalanceSkipsWhenSignerHasNoFees() public {
        MinimalAccount account = new MinimalAccount(address(0x1));
        vm.deal(address(account), 0);
        address signer = vm.addr(DEFAULT_ANVIL_PK);
        vm.deal(signer, 0.0001 ether);
        vm.deal(address(harness), 1 ether);

        harness.exposed_ensureAccountBalance(address(account), 1 ether, signer);

        assertEq(address(account).balance, 0);
    }

    function testEnsureAccountBalanceCapsToAvailableBalance() public {
        MinimalAccount account = new MinimalAccount(address(0x1));
        address signer = vm.addr(DEFAULT_ANVIL_PK);
        vm.deal(signer, 0.01 ether);
        vm.deal(address(harness), 0.01 ether);

        harness.exposed_ensureAccountBalance(address(account), 1 ether, signer);

        // available = 0.01 - 0.0002 (reserve) = 0.0098 ether
        assertEq(address(account).balance, 0.0098 ether);
    }

    function testEnsureAccountBalanceTransfersNeededAmount() public {
        MinimalAccount account = new MinimalAccount(address(0x1));
        address signer = vm.addr(DEFAULT_ANVIL_PK);
        vm.deal(signer, 2 ether);
        vm.deal(address(harness), 2 ether);

        harness.exposed_ensureAccountBalance(address(account), 1 ether, signer);

        // requiredBalance = 1.5 ether, so transfer 1.5 ether
        assertEq(address(account).balance, 1.5 ether);
    }
}
