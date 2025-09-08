// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {Register} from "src/Register.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";
import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {UnsafeUpgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployScript is Script {
    IAccessManager private accessManager;
    ERC2771Forwarder private erc2771Forwarder;
    Register private registerImpl;
    Register private registerProxy;
    AccessManagedBeaconHolder private userBeaconHolder;

    function setUp() public {}

    function run() public {
        console.log("Message sender:", msg.sender);

        vm.startBroadcast();

        (accessManager, erc2771Forwarder, registerImpl, registerProxy, userBeaconHolder) = createContracts(msg.sender);

        grantAccessToRoles(address(0), accessManager, address(registerProxy), address(userBeaconHolder));

        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, msg.sender, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, msg.sender, 0);
        console.log("UPGRADE_ADMIN_ROLE & USER_ADMIN_ROLE granted to:", msg.sender);

        vm.stopBroadcast();
    }

    function createContracts(address owner)
        public
        returns (
            IAccessManager,
            ERC2771Forwarder resultErc2771Forwarder,
            Register resultRegisterImpl,
            Register resultRegisterProxy,
            AccessManagedBeaconHolder resultAccessManagedUserBeaconHolder
        )
    {
        AccessManagerUpgradeable accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(owner);
        console.log("AccessManager address:", address(accessManagerUpgradeable));

        resultErc2771Forwarder = new ERC2771Forwarder();
        resultErc2771Forwarder.initialize("erc2771Forwarder");
        console.log("ERC2771Forwarder address:", address(resultErc2771Forwarder));

        resultAccessManagedUserBeaconHolder = new AccessManagedBeaconHolder(address(accessManagerUpgradeable));
        address userUpgradeableBeaconAddress =
            UnsafeUpgrades.deployBeacon(address(new User()), address(resultAccessManagedUserBeaconHolder));
        UpgradeableBeacon userUpgradeableBeacon = UpgradeableBeacon(userUpgradeableBeaconAddress);
        resultAccessManagedUserBeaconHolder.initialize(userUpgradeableBeacon);

        resultRegisterImpl = new Register(address(resultErc2771Forwarder));

        address registerProxyAddress = UnsafeUpgrades.deployUUPSProxy(
            address(resultRegisterImpl),
            abi.encodeCall(
                Register.initialize, (address(accessManagerUpgradeable), resultAccessManagedUserBeaconHolder)
            )
        );
        resultRegisterProxy = Register(address(registerProxyAddress));
        console.log("User beacon holder address: ", address(resultAccessManagedUserBeaconHolder));
        console.log("Register implementation address: ", address(registerImpl));
        console.log("Register proxy address: ", address(registerProxy));

        return (
            accessManagerUpgradeable,
            resultErc2771Forwarder,
            resultRegisterImpl,
            resultRegisterProxy,
            resultAccessManagedUserBeaconHolder
        );
    }

    function grantAccessToRoles(
        address userForPrank,
        IAccessManager accessMgr,
        address registerProxyAddr,
        address userBeaconHolderAddr
    ) public {
        if (userForPrank != address(0)) {
            vm.startPrank(userForPrank);
        }

        bytes4[] memory userOfStringSelector = new bytes4[](1);
        userOfStringSelector[0] = bytes4(keccak256("userOf(string)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, userOfStringSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory userOfAddressSelector = new bytes4[](1);
        userOfAddressSelector[0] = bytes4(keccak256("userOf(address)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, userOfAddressSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory removeSelector = new bytes4[](1);
        removeSelector[0] = bytes4(keccak256("remove(address)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, removeSelector, Roles.USER_ADMIN_ROLE);

        bytes4[] memory upgradeToAndCallSelector = new bytes4[](1);
        upgradeToAndCallSelector[0] = bytes4(keccak256("upgradeToAndCall(address,bytes)"));
        accessMgr.setTargetFunctionRole(registerProxyAddr, upgradeToAndCallSelector, Roles.UPGRADE_ADMIN_ROLE);

        bytes4[] memory userBeaconUpgradeToSelector = new bytes4[](1);
        userBeaconUpgradeToSelector[0] = bytes4(keccak256("upgradeTo(address)"));
        accessMgr.setTargetFunctionRole(userBeaconHolderAddr, userBeaconUpgradeToSelector, Roles.UPGRADE_ADMIN_ROLE);

        if (userForPrank != address(0)) {
            vm.stopPrank();
        }
    }
}
