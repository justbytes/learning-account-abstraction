pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";

contract DeployMinimalAccount is Script {
    function run() external returns (HelperConfig, MinimalAccount) {
        return deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (HelperConfig, MinimalAccount) {
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();

        vm.startBroadcast();
        MinimalAccount minimalAccount = new MinimalAccount(networkConfig.entryPoint);
        minimalAccount.transferOwnership(networkConfig.account);
        vm.stopBroadcast();
        return (config, minimalAccount);
    }
}
