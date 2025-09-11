// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";
import {Register} from "src/Register.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";

import {UserV2} from "./upgrades/UserV2.sol";

import {DeployScript} from "../script/Deploy.s.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UserTest is Test {
    IAccessManager private accessManager;
    Register private registerProxy;
    AccessManagedBeaconHolder private userBeaconHolder;

    address private constant OWNER = address(1);
    address private constant UPGRADE_ADMIN = address(0xA);
    address private constant USER_ADMIN = address(0xB);
    address private immutable USER = address(this);

    User private userV2Impl;

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(USER, "USER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(USER_ADMIN, "USER_ADMIN");

        DeployScript deployScript = new DeployScript();
        (accessManager,,, registerProxy, userBeaconHolder) = deployScript.createContracts(OWNER);
        deployScript.grantAccessToRoles(OWNER, accessManager, address(registerProxy), address(userBeaconHolder));

        vm.startPrank(OWNER);
        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, USER_ADMIN, 0);
        vm.stopPrank();

        userV2Impl = new UserV2();
    }

    function test_BasicUsage() public {
        User user = registerProxy.registerMeAs("user");

        assertEq("user", user.nickString());
        assertEq(0, user.index());

        vm.prank(address(registerProxy));
        user.setIndex(777);

        assertEq(777, user.index());
    }

    function test_remove_Successful() public {
        User user = registerProxy.registerMeAs("user"); // owner: USER

        assertEq(1, registerProxy.getTotalUsers());
        vm.prank(USER, USER);
        user.remove();

        assertEq(0, registerProxy.getTotalUsers());
    }

    function test_RevertWhen_NotOwnerCalls() public {
        User user = registerProxy.registerMeAs("user"); // owner: USER

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, OWNER));
        user.remove();
    }

    function test_RevertWhen_NotRegisterCalls() public {
        User user = registerProxy.registerMeAs("user");

        vm.expectRevert(abi.encodeWithSelector(User.OnlyRegisterMayCallThis.selector, this));
        user.setIndex(666);

        vm.expectRevert(abi.encodeWithSelector(User.OnlyRegisterMayCallThis.selector, this));
        user.goodbye();
    }

    function test_Upgrade_User_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER));
        userBeaconHolder.upgradeTo(address(userV2Impl));
    }

    function test_Upgrade_User_Successful() public {
        console.log(string.concat("abc", "123"));

        registerProxy.registerMeAs("user");
        vm.prank(USER_ADMIN);
        User user = registerProxy.userOf("user");
        assertEq("user", user.nickString());

        vm.prank(UPGRADE_ADMIN);
        userBeaconHolder.upgradeTo(address(userV2Impl));

        vm.prank(OWNER);
        registerProxy.registerMeAs("owner");

        vm.startPrank(USER_ADMIN);

        assertEq("user_", user.nickString());
        assertEq("owner_", registerProxy.userOf("owner").nickString());

        UserV2 userV2 = UserV2(address(registerProxy.userOf("user")));
        userV2.setSuffix("V2");
        assertEq("user_V2", user.nickString());

        vm.stopPrank();
    }
}
