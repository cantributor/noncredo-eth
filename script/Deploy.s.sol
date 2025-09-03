// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {UserRegister} from "../src/UserRegister.sol";
import {Roles} from "../src/Roles.sol";
import {User} from "../src/User.sol";
import {ERC2771Forwarder} from "../src/ERC2771Forwarder.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    AccessManagerUpgradeable private accessManagerUpgradeable;
    ERC2771Forwarder private erc2771Forwarder;
    UserRegister private userRegister;
    ERC1967Proxy private erc1967Proxy;
    UserRegister private userRegisterProxy;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(msg.sender);
        console.log("AccessManagerUpgradeable address:", address(accessManagerUpgradeable));

        erc2771Forwarder = new ERC2771Forwarder();
        erc2771Forwarder.initialize("erc2771Forwarder");
        console.log("ERC2771Forwarder address:", address(erc2771Forwarder));

        userRegister = new UserRegister(address(erc2771Forwarder));
        erc1967Proxy = new ERC1967Proxy(
            address(userRegister), abi.encodeCall(UserRegister.initialize, address(accessManagerUpgradeable))
        );
        userRegisterProxy = UserRegister(address(erc1967Proxy));
        console.log("UserRegister proxy address:", address(userRegisterProxy));

        buildRoleSystem();

        accessManagerUpgradeable.grantRole(Roles.UPGRADE_ADMIN_ROLE, msg.sender, 0);
        accessManagerUpgradeable.grantRole(Roles.USER_ADMIN_ROLE, msg.sender, 0);
        console.log("UPGRADE_ADMIN_ROLE & USER_ADMIN_ROLE granted to:", msg.sender);

        vm.stopBroadcast();
    }

    function buildRoleSystem() private {
        bytes4[] memory userOfStringSelector = new bytes4[](1);
        userOfStringSelector[0] = bytes4(keccak256("userOf(string)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), userOfStringSelector, Roles.USER_ADMIN_ROLE
        );

        bytes4[] memory userOfAddressSelector = new bytes4[](1);
        userOfAddressSelector[0] = bytes4(keccak256("userOf(address)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), userOfAddressSelector, Roles.USER_ADMIN_ROLE
        );

        bytes4[] memory removeSelector = new bytes4[](1);
        removeSelector[0] = bytes4(keccak256("remove(address)"));
        accessManagerUpgradeable.setTargetFunctionRole(address(erc1967Proxy), removeSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory upgradeToAndCallSelector = new bytes4[](1);
        upgradeToAndCallSelector[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), upgradeToAndCallSelector, Roles.UPGRADE_ADMIN_ROLE
        );

        bytes4[] memory upgradeUserImplementationSelector = new bytes4[](1);
        upgradeUserImplementationSelector[0] = bytes4(keccak256("upgradeUserImplementation(address)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), upgradeUserImplementationSelector, Roles.UPGRADE_ADMIN_ROLE
        );
    }
}
