pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {DeployMinimalAccount} from "../../script/DeployMinimalAccount.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "../../script/SendPackedUserOp.s.sol";
import {PackedUserOperation} from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    DeployMinimalAccount public deployer;
    MinimalAccount public minimalAccount;
    HelperConfig public helperConfig;
    ERC20Mock public usdc;
    SendPackedUserOp public sendPackedUserOp;

    uint256 public constant USDC_MINT_AMOUNT = 100;
    address public randomUser = makeAddr("randomUser");

    function setUp() public {
        deployer = new DeployMinimalAccount();
        (helperConfig, minimalAccount) = deployer.run();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Mint
    function test_OwnerCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), USDC_MINT_AMOUNT);
        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, funcData);
        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), USDC_MINT_AMOUNT);
    }

    function test_NonOwnerCannotExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), USDC_MINT_AMOUNT);
        address nonOwner = address(0x123);
        // Act
        vm.prank(nonOwner);

        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntrypointOrOwner.selector);
        minimalAccount.execute(dest, value, funcData);
    }

    function test_RecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), USDC_MINT_AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, funcData);

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        // Act
        address actualAddress = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);
        // Assert
        assertEq(actualAddress, minimalAccount.owner());
    }

    function test_ValidationOfUserOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), USDC_MINT_AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, funcData);
        uint256 missingAccountFunds = 1e18;

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOp);
        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOpHash, missingAccountFunds);
        // Assert
        assertEq(validationData, 0);
    }

    function test_EntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimalAccount), USDC_MINT_AMOUNT);
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, funcData);

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOp(executeCallData, helperConfig.getConfig(), address(minimalAccount));

        // Ensure the account has enough funds
        vm.deal(address(minimalAccount), 1e18);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = packedUserOp;

        // Act
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(userOps, payable(randomUser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), USDC_MINT_AMOUNT);
    }
}
