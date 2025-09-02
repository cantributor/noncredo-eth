// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {UserRegister} from "../src/UserRegister.sol";
import {Roles} from "../src/Roles.sol";
import {User} from "../src/User.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

contract DeployScript is Script {
    AccessManagerUpgradeable private accessManagerUpgradeable;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(msg.sender);

        console.log("AccessManagerUpgradeable address:", address(accessManagerUpgradeable));

        vm.stopBroadcast();
    }
}
