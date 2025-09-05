// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {Register} from "src/Register.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";
import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployScript is Script {
    AccessManagerUpgradeable private accessManagerUpgradeable;
    ERC2771Forwarder private erc2771Forwarder;

    Register private registerImpl;
    address private registerProxyAddress;
    Register private registerProxy;

    UpgradeableBeacon private userUpgradeableBeacon;
    address private userUpgradeableBeaconAddress;
    AccessManagedBeaconHolder private userBeaconHolder;

    function setUp() public {}

    function run() public {
        console.log("Message sender:", msg.sender);

        vm.startBroadcast();

        accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(msg.sender);
        console.log("AccessManagerUpgradeable address:", address(accessManagerUpgradeable));

        erc2771Forwarder = new ERC2771Forwarder();
        erc2771Forwarder.initialize("erc2771Forwarder");
        console.log("ERC2771Forwarder address:", address(erc2771Forwarder));

        userBeaconHolder = new AccessManagedBeaconHolder();
        userUpgradeableBeaconAddress = UnsafeUpgrades.deployBeacon(address(new User()), address(userBeaconHolder));
        userUpgradeableBeacon = UpgradeableBeacon(userUpgradeableBeaconAddress);
        userBeaconHolder.initialize(address(accessManagerUpgradeable), userUpgradeableBeacon);

        registerImpl = new Register(address(erc2771Forwarder));

        registerProxyAddress = UnsafeUpgrades.deployUUPSProxy(
            address(registerImpl),
            abi.encodeCall(Register.initialize, (address(accessManagerUpgradeable), userBeaconHolder))
        );
        registerProxy = Register(address(registerProxyAddress));
        console.log("Register proxy address:", registerProxyAddress);

        grantAccessToRoles(address(0), accessManagerUpgradeable, registerProxyAddress, address(userBeaconHolder));

        accessManagerUpgradeable.grantRole(Roles.UPGRADE_ADMIN_ROLE, msg.sender, 0);
        accessManagerUpgradeable.grantRole(Roles.USER_ADMIN_ROLE, msg.sender, 0);
        console.log("UPGRADE_ADMIN_ROLE & USER_ADMIN_ROLE granted to:", msg.sender);

        vm.stopBroadcast();
    }

    function grantAccessToRoles(
        address userForPrank,
        AccessManagerUpgradeable accessManager,
        address registerProxyAddr,
        address userBeaconHolderAddr
    ) public {
        if (userForPrank != address(0)) {
            vm.startPrank(userForPrank);
        }

        bytes4[] memory userOfStringSelector = new bytes4[](1);
        userOfStringSelector[0] = bytes4(keccak256("userOf(string)"));
        accessManager.setTargetFunctionRole(registerProxyAddr, userOfStringSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory userOfAddressSelector = new bytes4[](1);
        userOfAddressSelector[0] = bytes4(keccak256("userOf(address)"));
        accessManager.setTargetFunctionRole(registerProxyAddr, userOfAddressSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory removeSelector = new bytes4[](1);
        removeSelector[0] = bytes4(keccak256("remove(address)"));
        accessManager.setTargetFunctionRole(registerProxyAddr, removeSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory upgradeToAndCallSelector = new bytes4[](1);
        upgradeToAndCallSelector[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));
        accessManager.setTargetFunctionRole(registerProxyAddr, upgradeToAndCallSelector, Roles.UPGRADE_ADMIN_ROLE);

        bytes4[] memory userBeaconUpgradeToSelector = new bytes4[](1);
        userBeaconUpgradeToSelector[0] = bytes4(keccak256("upgradeTo(address)"));
        accessManager.setTargetFunctionRole(userBeaconHolderAddr, userBeaconUpgradeToSelector, Roles.UPGRADE_ADMIN_ROLE);

        if (userForPrank != address(0)) {
            vm.stopPrank();
        }
    }
}
