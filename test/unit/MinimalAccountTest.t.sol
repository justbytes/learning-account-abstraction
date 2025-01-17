// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@account-abstraction/contracts/core/Helpers.sol";

contract MinimalAccountTest is Test {
    MinimalAccount public account;
    EntryPoint public entryPoint;
    address public owner;
    uint256 public ownerKey;
    address public recipient;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        // Create owner wallet
        (owner, ownerKey) = makeAddrAndKey("owner");
        recipient = makeAddr("recipient");

        // Deploy contracts
        entryPoint = new EntryPoint();
        account = new MinimalAccount(address(entryPoint));

        // Transfer ownership to our test owner
        vm.prank(account.owner());
        account.transferOwnership(owner);

        // Fund the account
        vm.deal(address(account), 1 ether);
    }

    function test_Constructor() public {
        assertEq(account.getEntryPoint(), address(entryPoint));
        assertEq(account.owner(), owner);
    }

    function test_Execute_AsOwner() public {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, 100);
        vm.prank(owner);
        account.execute(recipient, 0.1 ether, data);
        assertEq(recipient.balance, 0.1 ether);
    }

    function test_Execute_AsEntryPoint() public {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, 100);
        vm.prank(address(entryPoint));
        account.execute(recipient, 0.1 ether, data);
        assertEq(recipient.balance, 0.1 ether);
    }

    function test_Execute_RevertIfNotOwnerOrEntryPoint() public {
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", recipient, 100);
        vm.prank(makeAddr("attacker"));
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntrypointOrOwner.selector);
        account.execute(recipient, 0.1 ether, data);
    }

    // function test_Execute_RevertOnFailedCall() public {
    //     // Deploy a contract that will revert
    //     RevertingContract reverting = new RevertingContract();
    //     bytes memory data = abi.encodeWithSignature("alwaysReverts()");

    //     vm.prank(owner);
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             MinimalAccount.MinimalAccount__ExecuteCallToDestFailed.selector, "RevertingContract: always reverts"
    //         )
    //     );
    //     account.execute(address(reverting), 0, data);
    // }

    function test_ValidateUserOp_Success() public {
        PackedUserOperation memory userOp = _createUserOp();
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, messageHash);
        userOp.signature = abi.encodePacked(r, s, v);

        vm.prank(address(entryPoint));
        uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    // function test_ValidateUserOp_FailsWithWrongSigner() public {
    //     PackedUserOperation memory userOp = _createUserOp();
    //     bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

    //     // Sign with wrong key
    //     (address wrongKey,) = makeAddrAndKey("wrong");
    //     bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, messageHash);
    //     userOp.signature = abi.encodePacked(r, s, v);

    //     vm.prank(address(entryPoint));
    //     uint256 validationData = account.validateUserOp(userOp, userOpHash, 0);
    //     assertEq(validationData, SIG_VALIDATION_FAILED);
    // }

    function test_ValidateUserOp_PaysPrefund() public {
        PackedUserOperation memory userOp = _createUserOp();
        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);

        bytes32 messageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, messageHash);
        userOp.signature = abi.encodePacked(r, s, v);

        uint256 prefundAmount = 0.1 ether;
        uint256 entryPointBalanceBefore = address(entryPoint).balance;

        vm.prank(address(entryPoint));
        account.validateUserOp(userOp, userOpHash, prefundAmount);

        assertEq(address(entryPoint).balance - entryPointBalanceBefore, prefundAmount);
    }

    function test_ReceiveFunction() public {
        uint256 amount = 1 ether;
        uint256 balanceBefore = address(account).balance;

        (bool success,) = address(account).call{value: amount}("");
        assertTrue(success);
        assertEq(address(account).balance, balanceBefore + amount);
    }

    function _createUserOp() internal view returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: address(account),
            nonce: 0,
            initCode: hex"",
            callData: hex"",
            accountGasLimits: bytes32(uint256(100000) << 128 | uint256(100000)),
            preVerificationGas: 100000,
            gasFees: bytes32(uint256(100) << 128 | uint256(100)),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}

// Helper contract for testing failed executions
contract RevertingContract {
    error RevertingContract__AlwaysReverts();

    function alwaysReverts() external pure {
        revert("RevertingContract: always reverts");
    }
}
