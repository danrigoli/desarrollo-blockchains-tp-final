// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {BUSD} from "../src/BUSD.sol";

contract DeployBUSD is Script {
    function run() external returns (BUSD token) {
        vm.startBroadcast();
        token = new BUSD();
        vm.stopBroadcast();
    }
}
