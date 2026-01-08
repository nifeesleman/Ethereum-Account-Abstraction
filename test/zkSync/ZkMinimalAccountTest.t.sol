// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "src/zksync/ZkMinimalAccount.sol";
import {Transaction} from "foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

contract MockTarget {
    uint256 public counter;

    function execute() external {
        counter += 1;
    }
}

contract ZkMinimalAccountTest is Test {
    ZkMinimalAccount private zkMinimalAccount;
    MockTarget private target;
    address private owner;
    uint256 constant ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba46cd47b2cff49341e7a3373594e7397d7483645a9385;

    function setUp() public {
        owner = vm.addr(0xA11CE);
        zkMinimalAccount = new ZkMinimalAccount(owner);
        target = new MockTarget();
    }

    function testOwnerSetOnDeploy() public {
        assertEq(zkMinimalAccount.owner(), owner);
    }

    function testNonOwnerCannotExecuteTransaction() public {
        Transaction memory txn = _baseTransaction();

        vm.expectRevert(ZkMinimalAccount.ZkMinimalAccount__NotFromBootloaderOrOwner.selector);
        zkMinimalAccount.executeTransaction(bytes32(0), bytes32(0), txn);
    }

    function testOwnerCanExecuteTransaction() public {
        Transaction memory txn = _callTargetTransaction();

        vm.prank(owner);
        zkMinimalAccount.executeTransaction(bytes32(0), bytes32(0), txn);

        assertEq(target.counter(), 1);
    }

    function _callTargetTransaction() private view returns (Transaction memory txn) {
        txn = _baseTransaction();
        txn.to = uint256(uint160(address(target)));
        txn.from = uint256(uint160(owner));
        txn.data = abi.encodeWithSelector(MockTarget.execute.selector);
    }

    function _baseTransaction() private pure returns (Transaction memory txn) {
        txn.txType = 0; // Legacy tx type
        txn.from = 0;
        txn.to = 0;
        txn.gasLimit = 0;
        txn.gasPerPubdataByteLimit = 0;
        txn.maxFeePerGas = 0;
        txn.maxPriorityFeePerGas = 0;
        txn.paymaster = 0;
        txn.nonce = 0;
        txn.value = 0;
        txn.reserved = [uint256(0), uint256(0), uint256(0), uint256(0)];
        txn.data = "";
        txn.signature = "";
        txn.factoryDeps = new bytes32[](0);
        txn.paymasterInput = "";
        txn.reservedDynamic = "";
    }
    // (Inside ZkMinimalAccountTest contract)

    // Hardcoded default Anvil private key for testing

    function _signTransaction(Transaction memory transaction) internal view returns (Transaction memory) {
        // 1. Encode the transaction hash for signing
        // MemoryTransactionHelper.encodeHash is specific to zkSync transaction structures
        bytes32 unsignedTransactionHash = MemoryTransactionHelper.encodeHash(transaction);

        // 2. Convert to Ethereum standard signed message hash format
        // This ensures compatibility with vm.sign, which expects an EIP-191 prefixed hash.
        bytes32 digest = unsignedTransactionHash.toEthSignedMessageHash();

        // 3. Sign the digest using vm.sign and the known private key
        uint8 v;
        bytes32 r;
        bytes32 s;
        (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);

        // 4. Create a mutable copy of the transaction to add the signature
        Transaction memory signedTransaction = transaction;

        // 5. Pack the signature components (r, s, v) into the signature field
        // The order r, s, v is a common convention.
        signedTransaction.signature = abi.encodePacked(r, s, v);

        return signedTransaction;
    }
}
