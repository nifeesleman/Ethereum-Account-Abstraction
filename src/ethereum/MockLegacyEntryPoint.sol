// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ILegacyEntryPoint} from "src/ethereum/ILegacyEntryPoint.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";

/// @notice Minimal mock of the legacy (v0.6) EntryPoint used for local testing.
contract MockLegacyEntryPoint is ILegacyEntryPoint {
    mapping(address sender => uint256 nonce) public nonces;

    function getNonce(
        address sender,
        uint192 /*key*/
    )
        external
        view
        override
        returns (uint256)
    {
        return nonces[sender];
    }

    function getUserOpHash(UserOperation calldata userOp) public pure override returns (bytes32 hash) {
        // Hash excluding the signature so signing/verifying aligns.
        UserOperation memory tmp = UserOperation({
            sender: userOp.sender,
            nonce: userOp.nonce,
            initCode: userOp.initCode,
            callData: userOp.callData,
            callGasLimit: userOp.callGasLimit,
            verificationGasLimit: userOp.verificationGasLimit,
            preVerificationGas: userOp.preVerificationGas,
            maxFeePerGas: userOp.maxFeePerGas,
            maxPriorityFeePerGas: userOp.maxPriorityFeePerGas,
            paymasterAndData: userOp.paymasterAndData,
            signature: bytes("")
        });
        bytes memory enc = abi.encode(tmp);
        assembly {
            hash := keccak256(add(enc, 0x20), mload(enc))
        }
    }

    function handleOps(
        UserOperation[] calldata ops,
        address payable /*beneficiary*/
    )
        external
        override
    {
        for (uint256 i = 0; i < ops.length; i++) {
            UserOperation calldata op = ops[i];
            nonces[op.sender]++;
            MinimalAccount(payable(op.sender)).validateUserOp(op, getUserOpHash(op), 0);
            (bool success,) = op.sender.call{gas: op.callGasLimit}(op.callData);
            require(success, "exec failed");
        }
    }
}
