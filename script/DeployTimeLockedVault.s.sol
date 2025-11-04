//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimeLockedVault} from "../src/TimeLockedVault.sol";
import {Script} from "forge-std/Script.sol";

contract DeployTimeLockedVault is Script {
    function run() external returns (TimeLockedVault) {
        vm.startBroadcast();
        TimeLockedVault timeLockedVault = new TimeLockedVault();
        vm.stopBroadcast();
        return timeLockedVault;
    }
}
