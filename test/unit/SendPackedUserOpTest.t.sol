// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SendPackedUserOp} from "../../script/SendPackedUserOp.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract SendPackedUserOpTest is Test {
    SendPackedUserOp public sender;
    HelperConfig public config;
    address public minimalAccount;
    bytes public callData;

    function setUp() public {
        sender = new SendPackedUserOp();
        config = new HelperConfig();
        minimalAccount = makeAddr("minimalAccount");
        callData = abi.encodeWithSignature("someFunction()");
    }

    function test_Run() public {
        // Test empty run function
        sender.run();
    }

    function test_GenerateUnsignedUserOp() public {
        PackedUserOperation memory userOp = sender._generateUnsignedUserOp(minimalAccount, 0, callData);

        // Verify all fields are set correctly
        assertEq(userOp.sender, minimalAccount);
        assertEq(userOp.nonce, 0);
        assertEq(userOp.callData, callData);
        assertEq(userOp.initCode, hex"");
        assertEq(userOp.paymasterAndData, hex"");
        assertEq(userOp.signature, hex"");

        // Verify gas limits and fees
        (uint128 verificationGasLimit, uint128 callGasLimit) = _decodeAccountGasLimits(userOp.accountGasLimits);
        assertEq(verificationGasLimit, 16777216);
        assertEq(callGasLimit, 16777216);

        (uint128 maxPriorityFeePerGas, uint128 maxFeePerGas) = _decodeGasFees(userOp.gasFees);
        assertEq(maxPriorityFeePerGas, 256);
        assertEq(maxFeePerGas, 256);
    }

    function test_GenerateSignedUserOp_OnAnvil() public {
        // Set chainId to Anvil
        vm.chainId(31337);

        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        PackedUserOperation memory signedOp = sender.generateSignedUserOp(callData, networkConfig, minimalAccount);

        // Verify signature is not empty
        assertTrue(signedOp.signature.length > 0);
        // Verify other fields are set
        assertEq(signedOp.sender, minimalAccount);
        assertEq(signedOp.callData, callData);
    }

    // Helper functions to decode packed values
    function _decodeAccountGasLimits(bytes32 packed) internal pure returns (uint128, uint128) {
        return (uint128(uint256(packed) >> 128), uint128(uint256(packed)));
    }

    function _decodeGasFees(bytes32 packed) internal pure returns (uint128, uint128) {
        return (uint128(uint256(packed) >> 128), uint128(uint256(packed)));
    }
}
