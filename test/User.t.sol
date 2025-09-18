// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {Riddle} from "src/Riddle.sol";
import {Register} from "src/Register.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";

import {Utils} from "src/Utils.sol";

import {UserV2} from "./upgrades/UserV2.sol";

import {DeployScript} from "../script/Deploy.s.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UserTest is Test {
    IAccessManager private accessManager;
    Register private registerProxy;
    AccessManagedBeaconHolder private userBeaconHolder;

    address private constant OWNER = address(1);
    address private constant UPGRADE_ADMIN = address(0xA);
    address private constant USER_ADMIN = address(0xB);
    address private constant FINANCE_ADMIN = address(0xC);
    address private immutable USER = address(this);

    User private userV2Impl;

    string private constant TYPICAL_RIDDLE_STATEMENT = "I am President";
    string private constant USER_SECRET_KEY = "User's secret key";

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(USER, "USER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(USER_ADMIN, "USER_ADMIN");
        vm.label(FINANCE_ADMIN, "FINANCE_ADMIN");

        DeployScript deployScript = new DeployScript();
        (accessManager,,, registerProxy, userBeaconHolder,) = deployScript.createContracts(OWNER);
        deployScript.grantAccessToRoles(
            OWNER, accessManager, address(registerProxy), address(userBeaconHolder), address(0)
        );

        vm.startPrank(OWNER);
        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, USER_ADMIN, 0);
        accessManager.grantRole(Roles.FINANCE_ADMIN_ROLE, FINANCE_ADMIN, 0);
        vm.stopPrank();

        vm.prank(FINANCE_ADMIN);
        registerProxy.setGuessAndRevealDuration(Utils.MIN_DURATION, Utils.MIN_DURATION);

        userV2Impl = new UserV2();
    }

    function test_setIndex() public {
        User user = registerProxy.registerMeAs("user");

        assertEq("user", user.nickString());
        assertEq(0, user.index());

        vm.prank(address(registerProxy));
        user.setIndex(777);

        assertEq(777, user.index());
    }

    function test_remove_Successful() public {
        User user = registerProxy.registerMeAs("user"); // owner: USER

        assertEq(1, registerProxy.totalUsers());
        vm.prank(USER, USER);
        vm.expectEmit(true, true, true, false);
        emit User.UserRemoved(USER, "user", USER);
        user.remove();

        assertEq(0, registerProxy.totalUsers());
    }

    function test_RevertWhen_NotOwnerCalls() public {
        User user = registerProxy.registerMeAs("user"); // owner: USER

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, OWNER));
        user.remove();

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, OWNER));
        user.commit(TYPICAL_RIDDLE_STATEMENT, 777);
    }

    function test_RevertWhen_NotRegisterCalls() public {
        User user = registerProxy.registerMeAs("user");

        vm.expectRevert(abi.encodeWithSelector(User.OnlyRegisterMayCallThis.selector, this));
        user.setIndex(666);

        vm.expectRevert(abi.encodeWithSelector(User.OnlyRegisterMayCallThis.selector, this));
        user.goodbye();
    }

    function test_commit_RevertWhen_StatementTooShortOrTooLong() public {
        User user = registerProxy.registerMeAs("user");

        vm.expectRevert(abi.encodeWithSelector(Utils.RiddleTooShort.selector, "I'm man", 7, 10));
        user.commit("I'm man", 777);

        string memory longString = string.concat(
            "12345678901234567890123456789012345678901234567890",
            "12345678901234567890123456789012345678901234567890",
            "12345678901234567890123456789012345678901234567890"
        );
        vm.expectRevert(abi.encodeWithSelector(Utils.RiddleTooLong.selector, longString, 150, 128));
        user.commit(longString, 777);
    }

    function test_commit_Successful() public {
        User user1 = registerProxy.registerMeAs("user1");
        assertEq(0, registerProxy.totalRiddles());

        vm.expectEmit(true, false, false, true);
        emit Riddle.RiddleRegistered(address(user1), address(0), 1, keccak256(abi.encode(TYPICAL_RIDDLE_STATEMENT)));

        uint256 currentBlockNumber = block.number;
        console.log("Current block number", currentBlockNumber);
        Riddle riddle1 = user1.commit(TYPICAL_RIDDLE_STATEMENT, 777);
        assertEq(1, registerProxy.totalRiddles());
        assertEq(USER, riddle1.owner());
        assertEq(TYPICAL_RIDDLE_STATEMENT, riddle1.statement());
        assertEq(1, riddle1.id());
        assertEq(0, riddle1.userIndex());
        assertEq(0, riddle1.registerIndex());
        assertEq(currentBlockNumber + Utils.MIN_DURATION, riddle1.guessDeadline());
        assertEq(currentBlockNumber + Utils.MIN_DURATION * 2, riddle1.revealDeadline());

        vm.startPrank(OWNER);
        User user2 = registerProxy.registerMeAs("user2");
        Riddle riddle2 = user2.commit("I am Superman", 777);
        vm.stopPrank();

        assertEq(2, registerProxy.totalRiddles());
        assertEq(OWNER, riddle2.owner());
        assertEq(2, riddle2.id());
        assertEq(0, riddle2.userIndex());
        assertEq(1, riddle2.registerIndex());

        assertEq(address(riddle1), address(user1.riddles(0)));
        assertEq(address(riddle2), address(user2.riddles(0)));
        assertEq(address(riddle1), address(registerProxy.riddles(0)));
        assertEq(address(riddle2), address(registerProxy.riddles(1)));
    }

    function test_commit_RevertWhen_RiddleAlreadyRegistered() public {
        User user1 = registerProxy.registerMeAs("user1");
        vm.prank(OWNER);
        User user2 = registerProxy.registerMeAs("user2");
        assertEq(0, registerProxy.totalRiddles());

        user1.commit(TYPICAL_RIDDLE_STATEMENT, 777);

        vm.expectRevert(abi.encodeWithSelector(Riddle.RiddleAlreadyRegistered.selector, 1, "user1", 0));
        vm.prank(OWNER);
        user2.commit(TYPICAL_RIDDLE_STATEMENT, 777);

        assertEq(1, registerProxy.totalRiddles());
    }

    function test_Upgrade_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER));
        userBeaconHolder.upgradeTo(address(userV2Impl));
    }

    function test_Upgrade_Successful() public {
        registerProxy.registerMeAs("user");
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
