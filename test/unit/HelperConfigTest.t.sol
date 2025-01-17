// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";

contract HelperConfigTest is Test {
    HelperConfig public config;

    function setUp() public {
        config = new HelperConfig();
    }

    function test_GetConfig_OnAnvil() public {
        // Set chainId to Anvil
        vm.chainId(31337);

        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        // First call deploys new EntryPoint
        assertTrue(networkConfig.entryPoint != address(0));
        assertEq(networkConfig.account, config.ANVIL_ACCOUNT());

        // Second call should return same config
        HelperConfig.NetworkConfig memory secondConfig = config.getConfig();
        assertEq(secondConfig.entryPoint, networkConfig.entryPoint);
    }

    function test_GetConfig_OnEthSepolia() public {
        // Set chainId to Eth Sepolia
        vm.chainId(11155111);

        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        assertEq(networkConfig.entryPoint, 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
        assertEq(networkConfig.account, config.TEST_ACCOUNT());
    }

    function test_GetConfig_OnZkSyncSepolia() public {
        // Set chainId to ZkSync Sepolia
        vm.chainId(300);

        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        assertEq(networkConfig.entryPoint, address(0));
        assertEq(networkConfig.account, config.TEST_ACCOUNT());
    }

    function test_GetConfig_RevertOnInvalidChainId() public {
        // Set chainId to invalid value
        vm.chainId(999);

        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        config.getConfig();
    }

    function test_GetConfigByChainId_DirectCalls() public {
        // Test direct calls to getConfigByChainId
        HelperConfig.NetworkConfig memory ethConfig = config.getConfigByChainId(config.ETH_SEPOLIA_CHAIN_ID());
        HelperConfig.NetworkConfig memory zkConfig = config.getConfigByChainId(config.ZKSYNC_SEPOLIA_CHAIN_ID());

        assertEq(ethConfig.entryPoint, 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
        assertEq(zkConfig.entryPoint, address(0));
    }

    function test_NetworkConfigConstants() public {
        // Verify constants
        assertEq(config.ETH_SEPOLIA_CHAIN_ID(), 11155111);
        assertEq(config.ZKSYNC_SEPOLIA_CHAIN_ID(), 300);
        assertEq(config.ANVIL_CHAIN_ID(), 31337);
        assertEq(config.ANVIL_ACCOUNT(), 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        assertEq(config.TEST_ACCOUNT(), 0x984D18688F5eA45257AA6A48BC7F2F01b2c96E42);
    }
}
