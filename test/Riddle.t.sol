// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {Guess} from "src/Guess.sol";
import {Riddle} from "src/Riddle.sol";
import {Register} from "src/Register.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";

import {UserV2} from "./upgrades/UserV2.sol";
import {RiddleV2} from "./upgrades/RiddleV2.sol";

import {DeployScript} from "../script/Deploy.s.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract RiddleTest is Test {
    IAccessManager private accessManager;
    Register private registerProxy;
    AccessManagedBeaconHolder private riddleBeaconHolder;

    address private constant OWNER = address(1);
    address private constant UPGRADE_ADMIN = address(0xA);
    address private constant USER_ADMIN = address(0xB);
    address private immutable USER = address(this);

    Riddle private riddleV2Impl;

    string private constant TYPICAL_RIDDLE_STATEMENT = "I am President";
    string private constant USER_SECRET_KEY = "User's secret key";

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(USER, "USER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(USER_ADMIN, "USER_ADMIN");

        DeployScript deployScript = new DeployScript();
        (accessManager,,, registerProxy,, riddleBeaconHolder) = deployScript.createContracts(OWNER);
        deployScript.grantAccessToRoles(
            OWNER, accessManager, address(registerProxy), address(0), address(riddleBeaconHolder)
        );

        vm.startPrank(OWNER);
        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, USER_ADMIN, 0);
        vm.stopPrank();

        vm.prank(UPGRADE_ADMIN);
        registerProxy.setGuessAndRevealDuration(3, 3);

        riddleV2Impl = new RiddleV2();
    }

    function test_guess_RevertWhen_AccountNotRegistered() public {
        User user = registerProxy.registerMeAs("user");
        Riddle riddle = user.commit(TYPICAL_RIDDLE_STATEMENT, 101);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Register.AccountNotRegistered.selector, address(OWNER)));
        riddle.guess(true);
    }

    function test_guess_RevertWhen_OwnerCannotGuess() public {
        User user = registerProxy.registerMeAs("user");
        Riddle riddle = user.commit(TYPICAL_RIDDLE_STATEMENT, 101);

        vm.expectRevert(abi.encodeWithSelector(Riddle.OwnerCannotGuess.selector, 1, address(USER)));
        riddle.guess(true);
    }

    function test_guess_RevertWhen_GuessOfSenderAlreadyExists() public {
        User riddling = registerProxy.registerMeAs("riddling");
        Riddle riddle = riddling.commit(TYPICAL_RIDDLE_STATEMENT, 101);

        vm.startPrank(OWNER);
        registerProxy.registerMeAs("guessing");
        riddle.guess(true);

        vm.expectRevert(abi.encodeWithSelector(Riddle.GuessOfSenderAlreadyExists.selector, 1, address(OWNER), true, 0));
        riddle.guess(false);
        vm.stopPrank();
    }

    function test_guess_Successful() public {
        User riddling = registerProxy.registerMeAs("riddling");
        Riddle riddle = riddling.commit(TYPICAL_RIDDLE_STATEMENT, 101);
        assertEq(0, address(riddle).balance);

        vm.startPrank(OWNER);
        vm.deal(OWNER, 2000);
        assertEq(2000, OWNER.balance);
        registerProxy.registerMeAs("guessing");
        vm.expectEmit(true, true, false, true);
        emit Riddle.RiddleGuessRegistered(address(riddle), OWNER, 1, true, 1000);
        Guess memory guess = riddle.guess{value: 1000}(true);
        assertEq(1000, OWNER.balance);
        vm.stopPrank();

        assertEq(OWNER, guess.account);
        assertEq(true, guess.credo);
        assertEq(1000, guess.bet);
        assertEq(1000, address(riddle).balance);

        Guess memory foundGuess = riddle.guessOf(OWNER);
        assertEq(1000, foundGuess.bet);
    }

    function test_Upgrade_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER));
        riddleBeaconHolder.upgradeTo(address(riddleV2Impl));
    }

    function test_Upgrade_Successful() public {
        User user = registerProxy.registerMeAs("user");
        Riddle riddle = user.commit(TYPICAL_RIDDLE_STATEMENT, 777);
        Guess memory notExistingGuess = riddle.guessOf(USER);
        assertEq(address(0), notExistingGuess.account);

        vm.prank(UPGRADE_ADMIN);
        riddleBeaconHolder.upgradeTo(address(riddleV2Impl));
        Guess memory guessByNewRiddleVersion = riddle.guessOf(USER);
        assertEq(USER, guessByNewRiddleVersion.account);
    }
}
