// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {Guess} from "../src/structs/Guess.sol";
import {Payment} from "../src/structs/Payment.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {Riddle} from "src/Riddle.sol";
import {Register} from "src/Register.sol";
import {Roles} from "src/Roles.sol";
import {User} from "src/User.sol";

import {Utils} from "src/Utils.sol";

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
    address private constant FINANCE_ADMIN = address(0xC);

    address private constant RIDDLING = address(100);
    address private constant GUESSING_1 = address(101);
    address private constant GUESSING_2 = address(102);
    address private constant GUESSING_3 = address(103);
    address private constant GUESSING_NOT_REGISTERED = address(104);

    Riddle private riddleV2Impl;

    string private constant TYPICAL_RIDDLE_STATEMENT = "I am President";
    string private constant USER_SECRET_KEY = "User's secret key";

    User private riddling;
    User private guessing1;
    User private guessing2;
    User private guessing3;

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(FINANCE_ADMIN, "FINANCE_ADMIN");
        vm.label(RIDDLING, "RIDDLING");

        vm.label(GUESSING_1, "GUESSING_1");
        vm.label(GUESSING_2, "GUESSING_2");
        vm.label(GUESSING_3, "GUESSING_3");

        DeployScript deployScript = new DeployScript();
        (accessManager,,, registerProxy,, riddleBeaconHolder) = deployScript.createContracts(OWNER);
        deployScript.grantAccessToRoles(
            OWNER, accessManager, address(registerProxy), address(0), address(riddleBeaconHolder)
        );

        vm.startPrank(OWNER);
        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManager.grantRole(Roles.FINANCE_ADMIN_ROLE, FINANCE_ADMIN, 0);
        vm.stopPrank();

        vm.startPrank(FINANCE_ADMIN);
        registerProxy.setGuessAndRevealDuration(Utils.MIN_DURATION, Utils.MIN_DURATION);
        registerProxy.setRegisterAndRiddlingRewards(1, 9);
        vm.stopPrank();

        riddleV2Impl = new RiddleV2();

        vm.prank(RIDDLING);
        riddling = registerProxy.registerMeAs("riddling");
        vm.prank(GUESSING_1);
        guessing1 = registerProxy.registerMeAs("guessing1");
        vm.prank(GUESSING_2);
        guessing2 = registerProxy.registerMeAs("guessing2");
        vm.prank(GUESSING_3);
        guessing3 = registerProxy.registerMeAs("guessing3");

        vm.prank(FINANCE_ADMIN);
        registerProxy.setGuessAndRevealDuration(Utils.MIN_DURATION, Utils.MIN_DURATION);

        vm.deal(payable(registerProxy), 0);
        vm.deal(RIDDLING, 0);
        vm.deal(GUESSING_1, 1000);
        vm.deal(GUESSING_2, 2000);
        vm.deal(GUESSING_3, 1000);
    }

    function test_guess_RevertWhen_AccountNotRegistered() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_NOT_REGISTERED);
        vm.expectRevert(
            abi.encodeWithSelector(Register.AccountNotRegistered.selector, address(GUESSING_NOT_REGISTERED))
        );
        riddle.guess(true);
    }

    function test_guess_RevertWhen_OwnerCannotGuess() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(RIDDLING);
        vm.expectRevert(abi.encodeWithSelector(Riddle.OwnerCannotGuess.selector, 1, address(RIDDLING)));
        riddle.guess(true);
    }

    function test_guess_RevertWhen_GuessOfSenderAlreadyExists() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle.guess(true);

        vm.expectRevert(
            abi.encodeWithSelector(Riddle.GuessOfSenderAlreadyExists.selector, 1, address(GUESSING_1), true, 0)
        );
        vm.prank(GUESSING_1);
        riddle.guess(false);
    }

    function test_guess_Successful() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        assertEq(1000, GUESSING_1.balance);
        vm.expectEmit(true, true, false, true);
        emit Riddle.GuessRegistered(address(riddle), GUESSING_1, 1, true, 1000);
        vm.prank(GUESSING_1);
        Guess memory guess = riddle.guess{value: 1000}(true);
        assertEq(0, GUESSING_1.balance);

        assertEq(GUESSING_1, guess.account);
        assertEq(true, guess.credo);
        assertEq(1000, guess.bet);
        assertEq(1000, address(riddle).balance);

        Guess memory foundGuess = riddle.guessOf(GUESSING_1);
        assertEq(1000, foundGuess.bet);
    }

    function test_reveal_RevertWhen_GuessPeriodNotFinished() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.expectRevert(
            abi.encodeWithSelector(Riddle.GuessPeriodNotFinished.selector, 1, block.number, riddle.guessDeadline())
        );
        vm.prank(RIDDLING);
        riddle.reveal("no matter");
    }

    function test_reveal_RevertWhen_IncorrectUserSecretKey() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.roll(riddle.guessDeadline() + 1);
        vm.expectRevert(abi.encodeWithSelector(Utils.IncorrectUserSecretKey.selector, 1, "incorrect secret key"));
        vm.prank(RIDDLING);
        riddle.reveal("incorrect secret key");
    }

    function test_reveal_RevertWhen_RiddleAlreadyRevealed() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.roll(riddle.guessDeadline() + 1);

        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);

        vm.prank(RIDDLING);
        vm.expectRevert(abi.encodeWithSelector(Riddle.RiddleAlreadyRevealed.selector, 1, address(riddle), RIDDLING));
        riddle.reveal(USER_SECRET_KEY);
    }

    function test_reveal_Successful_NoGuesses() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.roll(riddle.guessDeadline() + 1);
        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(0, RIDDLING.balance);
        assertEq(0, payable(registerProxy).balance);
    }

    function test_reveal_Successful_IncorrectGuess() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle.guess{value: 1000}(false);

        vm.roll(riddle.guessDeadline() + 1);

        vm.expectEmit(true, true, false, true);
        emit Riddle.RewardPayed(address(riddle), RIDDLING, 90);
        vm.expectEmit(true, true, false, true);
        emit Riddle.RewardPayed(address(riddle), payable(registerProxy), 910);

        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(910, payable(registerProxy).balance);
        assertEq(90, RIDDLING.balance);
        assertEq(0, GUESSING_1.balance);

        Payment[] memory payments = registerProxy.paymentsArray();
        assertEq(1, payments.length);
        assertEq(910, payments[0].amount);
        assertEq(address(riddle), payments[0].payer);
    }

    function test_reveal_Successful_CorrectGuess() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle.guess{value: 1000}(true);

        vm.roll(riddle.guessDeadline() + 1);
        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(0, payable(registerProxy).balance);
        assertEq(0, RIDDLING.balance);
        assertEq(1000, GUESSING_1.balance);
    }

    function test_reveal_Successful_CorrectAndIncorrectGuesses() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle.guess{value: 1000}(true);
        vm.prank(GUESSING_2);
        riddle.guess{value: 2000}(true);
        vm.prank(GUESSING_3);
        riddle.guess{value: 1000}(false);

        vm.roll(riddle.guessDeadline() + 1);
        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        console.log("Register.balance", payable(registerProxy).balance);
        console.log("RIDDLING.balance", RIDDLING.balance);
        console.log("GUESSING_1.balance", GUESSING_1.balance);
        console.log("GUESSING_2.balance", GUESSING_2.balance);
        console.log("GUESSING_3.balance", GUESSING_3.balance);
        assertEq(0, payable(riddle).balance);
        assertEq(10, payable(registerProxy).balance);
        assertEq(90, RIDDLING.balance);
        assertEq(1300, GUESSING_1.balance);
        assertEq(2600, GUESSING_2.balance);
        assertEq(0, GUESSING_3.balance);
    }

    function test_Upgrade_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        riddleBeaconHolder.upgradeTo(address(riddleV2Impl));
    }

    function test_Upgrade_Successful() public {
        Riddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        Guess memory notExistingGuess = riddle.guessOf(RIDDLING);
        assertEq(address(0), notExistingGuess.account);

        vm.prank(UPGRADE_ADMIN);
        riddleBeaconHolder.upgradeTo(address(riddleV2Impl));

        Guess memory guessByNewRiddleVersion = riddle.guessOf(RIDDLING);
        assertEq(RIDDLING, guessByNewRiddleVersion.account);
    }

    function util_CreateRiddle(string memory statement, bool solution, string memory userSecretKey)
        private
        returns (Riddle riddle)
    {
        uint256 encryptedSolution = Utils.encryptSolution(statement, solution, userSecretKey);
        vm.prank(RIDDLING);
        riddle = riddling.commit(statement, encryptedSolution);
        return riddle;
    }
}
