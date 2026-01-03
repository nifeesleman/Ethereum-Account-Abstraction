// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Minimal legacy (v0.6) EntryPoint interface and UserOperation struct used by 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789.
interface ILegacyEntryPoint {
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        uint256 callGasLimit;
        uint256 verificationGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes paymasterAndData;
        bytes signature;
    }

    function getNonce(address sender, uint192 key) external view returns (uint256);
    function getUserOpHash(UserOperation calldata userOp) external view returns (bytes32);
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;
}
