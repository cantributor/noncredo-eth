// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";
import {IRiddle} from "../src/interfaces/IRiddle.sol";
import {IUser} from "../src/interfaces/IUser.sol";

import {Guess} from "../src/structs/Guess.sol";
import {Payment} from "../src/structs/Payment.sol";

import {AccessManagedBeaconHolder} from "src/AccessManagedBeaconHolder.sol";
import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";
import {Roles} from "src/Roles.sol";
import {Utils} from "src/Utils.sol";

import {MetaTxUtils} from "./utils/MetaTxUtils.sol";

import {UserV2} from "./upgrades/UserV2.sol";
import {RiddleV2} from "./upgrades/RiddleV2.sol";

import {DeployScript} from "../script/Deploy.s.sol";

import {IAccessManager} from "@openzeppelin/contracts/access/manager/IAccessManager.sol";
import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract RiddleTest is Test {
    IAccessManager private accessManager;
    ERC2771Forwarder private erc2771Forwarder;
    IRegister private registerProxy;
    AccessManagedBeaconHolder private riddleBeaconHolder;

    address private constant OWNER = address(1);
    address private constant UPGRADE_ADMIN = address(0xA);
    address private constant USER_ADMIN = address(0xB);
    address private constant FINANCE_ADMIN = address(0xC);

    uint256 private constant SIGNER_PRIVATE_KEY = 0xACE101;

    address private constant RIDDLING = address(100);
    address private constant GUESSING_1 = address(101);
    address private constant GUESSING_2 = address(102);
    address private constant GUESSING_3 = address(103);
    address private constant GUESSING_NOT_REGISTERED = address(104);
    address private immutable SIGNER = vm.addr(SIGNER_PRIVATE_KEY);

    IRiddle private riddleV2Impl;

    string private constant TYPICAL_RIDDLE_STATEMENT = "I am President";
    string private constant USER_SECRET_KEY = "User's secret key";

    IUser private riddling;
    IUser private guessing1;
    IUser private guessing2;
    IUser private guessing3;

    function setUp() public {
        vm.label(OWNER, "OWNER");
        vm.label(UPGRADE_ADMIN, "UPGRADE_ADMIN");
        vm.label(USER_ADMIN, "UPGRADE_ADMIN");
        vm.label(FINANCE_ADMIN, "FINANCE_ADMIN");

        vm.label(RIDDLING, "RIDDLING");

        vm.label(GUESSING_1, "GUESSING_1");
        vm.label(GUESSING_2, "GUESSING_2");
        vm.label(GUESSING_3, "GUESSING_3");

        vm.label(SIGNER, "SIGNER");

        DeployScript deployScript = new DeployScript();
        (accessManager, erc2771Forwarder,, registerProxy,, riddleBeaconHolder) = deployScript.createContracts(OWNER);
        deployScript.grantAccessToRoles(
            OWNER, accessManager, address(registerProxy), address(0), address(riddleBeaconHolder)
        );

        vm.startPrank(OWNER);
        accessManager.grantRole(Roles.UPGRADE_ADMIN_ROLE, UPGRADE_ADMIN, 0);
        accessManager.grantRole(Roles.USER_ADMIN_ROLE, USER_ADMIN, 0);
        accessManager.grantRole(Roles.FINANCE_ADMIN_ROLE, FINANCE_ADMIN, 0);
        vm.stopPrank();

        vm.startPrank(FINANCE_ADMIN);
        registerProxy.setGuessAndRevealDuration(Utils.MIN_DURATION, Utils.MIN_DURATION);
        registerProxy.setRegisterAndRiddlingRewards(1, 9);
        vm.stopPrank();

        riddleV2Impl = new RiddleV2(address(erc2771Forwarder));

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
        vm.deal(GUESSING_NOT_REGISTERED, 1000);
    }

    function test_RevertWhen_NotRegisterCalls() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.expectRevert(abi.encodeWithSelector(IRegister.OnlyRegisterMayCallThis.selector, this));
        riddle.setIndex(666);

        vm.expectRevert(abi.encodeWithSelector(IRegister.OnlyRegisterMayCallThis.selector, this));
        riddle.finalize();
    }

    function test_RevertWhen_NotOwnerCalls() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        bytes memory encodedOwnableUnauthorizedAccount =
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(this));

        vm.expectRevert(encodedOwnableUnauthorizedAccount);
        riddle.reveal("no matter");

        vm.expectRevert(encodedOwnableUnauthorizedAccount);
        riddle.remove();
    }

    function test_setIndex() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        assertEq(0, riddle.index());

        vm.prank(address(registerProxy));
        riddle.setIndex(777);

        assertEq(777, riddle.index());
    }

    function test_guess_RevertWhen_AccountNotRegistered() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_NOT_REGISTERED);
        vm.expectRevert(
            abi.encodeWithSelector(IRegister.AccountNotRegistered.selector, address(GUESSING_NOT_REGISTERED))
        );
        riddle.guess(true);
    }

    function test_guess_RevertWhen_OwnerCannotGuess() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(RIDDLING);
        vm.expectRevert(abi.encodeWithSelector(IRiddle.OwnerCannotGuess.selector, 1, address(RIDDLING)));
        riddle.guess(true);
    }

    function test_guess_RevertWhen_GuessOfSenderAlreadyExists() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle.guess(true);

        vm.expectRevert(
            abi.encodeWithSelector(IRiddle.GuessOfSenderAlreadyExists.selector, 1, address(GUESSING_1), true, 0)
        );
        vm.prank(GUESSING_1);
        riddle.guess(false);
    }

    function test_RevertWhen_OnPause() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(USER_ADMIN);
        registerProxy.pause();

        bytes memory encodedEnforcedPause = abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector);

        vm.prank(GUESSING_1);
        vm.expectRevert(encodedEnforcedPause);
        riddle.guess{value: 1000}(true);

        vm.prank(RIDDLING);
        vm.expectRevert(encodedEnforcedPause);
        riddle.reveal(USER_SECRET_KEY);

        vm.prank(RIDDLING);
        vm.expectRevert(encodedEnforcedPause);
        riddle.remove();
    }

    function test_guess_Successful() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
        assertEq(0, riddle.totalGuesses());

        assertEq(1000, GUESSING_1.balance);
        vm.expectEmit(true, true, false, true);
        emit IRiddle.GuessRegistered(address(riddle), GUESSING_1, 1, true, 1000);
        vm.prank(GUESSING_1);
        Guess memory guess = riddle.guess{value: 1000}(true);
        assertEq(0, GUESSING_1.balance);

        assertEq(GUESSING_1, guess.account);
        assertEq(true, guess.credo);
        assertEq(1000, guess.bet);
        assertEq(1000, address(riddle).balance);

        Guess memory foundGuess = riddle.guessOf(GUESSING_1);
        assertEq(GUESSING_1, foundGuess.account);
        assertEq(1000, foundGuess.bet);
        assertTrue(foundGuess.credo);

        assertEq(1, riddle.totalGuesses());
        Guess memory guessByIndex = riddle.guessByIndex(0);
        assertEq(GUESSING_1, guessByIndex.account);
        assertEq(1000, guessByIndex.bet);
        assertTrue(guessByIndex.credo);
    }

    function test_reveal_RevertWhen_GuessPeriodNotFinished() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.expectRevert(
            abi.encodeWithSelector(IRiddle.GuessPeriodNotFinished.selector, 1, block.number, riddle.guessDeadline())
        );
        vm.prank(RIDDLING);
        riddle.reveal("no matter");
    }

    function test_reveal_RevertWhen_IncorrectUserSecretKey() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.roll(riddle.guessDeadline() + 1);
        vm.expectRevert(abi.encodeWithSelector(Utils.IncorrectUserSecretKey.selector, 1, "incorrect secret key"));
        vm.prank(RIDDLING);
        riddle.reveal("incorrect secret key");
    }

    function test_reveal_RevertWhen_RiddleAlreadyRevealed() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.roll(riddle.guessDeadline() + 1);

        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);

        vm.prank(RIDDLING);
        vm.expectRevert(abi.encodeWithSelector(IRiddle.RiddleAlreadyRevealed.selector, 1, address(riddle), RIDDLING));
        riddle.reveal(USER_SECRET_KEY);
    }

    function test_reveal_Successful_NoGuesses() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.roll(riddle.guessDeadline() + 1);
        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(0, RIDDLING.balance);
        assertEq(0, payable(registerProxy).balance);
    }

    function test_reveal_Successful_NoGuessesWithSponsorPayment() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
        (bool success,) = address(riddle).call{value: 1000}("");
        assertTrue(success);

        vm.roll(riddle.guessDeadline() + 1);
        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(90, RIDDLING.balance);
        assertEq(910, payable(registerProxy).balance);
    }

    function test_reveal_Successful_IncorrectGuess() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle.guess{value: 1000}(false);

        vm.roll(riddle.guessDeadline() + 1);

        vm.expectEmit(true, true, false, true);
        emit IRiddle.RewardPayed(address(riddle), RIDDLING, 90);
        vm.expectEmit(true, true, false, true);
        emit IRegister.PaymentReceived(address(riddle), 1, 910);
        vm.expectEmit(true, true, false, true);
        emit IRiddle.RewardPayed(address(riddle), payable(registerProxy), 910);

        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(910, payable(registerProxy).balance);
        assertEq(90, RIDDLING.balance);
        assertEq(0, GUESSING_1.balance);

        Payment[] memory payments = registerProxy.paymentsArray();
        assertEq(1, payments.length);
        assertEq(910, payments[0].amount);
        assertEq(1, payments[0].riddleId);
        assertEq(address(riddle), payments[0].payer);
    }

    function test_reveal_Successful_CorrectGuess() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

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

    function test_reveal_Successful_CorrectGuessWithSponsorPayment() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
        (bool success,) = address(riddle).call{value: 1000}("");
        assertTrue(success);

        vm.prank(GUESSING_1);
        riddle.guess{value: 1000}(true);

        vm.roll(riddle.guessDeadline() + 1);
        vm.prank(RIDDLING);
        riddle.reveal(USER_SECRET_KEY);
        assertEq(0, payable(riddle).balance);
        assertEq(10, payable(registerProxy).balance);
        assertEq(90, RIDDLING.balance);
        assertEq(1900, GUESSING_1.balance);
    }

    function test_reveal_Successful_CorrectAndIncorrectGuesses() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

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

    function test_remove_Successful() public {
        IRiddle riddle1 = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
        IRiddle riddle2 = util_CreateRiddle("I am superman!", true, USER_SECRET_KEY);

        vm.prank(GUESSING_1);
        riddle1.guess{value: 1000}(true);
        vm.prank(GUESSING_2);
        riddle1.guess{value: 2000}(true);
        vm.prank(GUESSING_3);
        riddle1.guess{value: 1000}(false);

        assertEq(2, registerProxy.totalRiddles());
        assertEq(2, riddling.totalRiddles());
        assertEq(1, riddle2.index());

        vm.expectEmit(true, true, false, true);
        emit IRiddle.RiddleRemoved(address(riddling), address(riddle1), 1);
        vm.prank(RIDDLING);
        riddle1.remove();

        assertEq(1, registerProxy.totalRiddles());
        assertEq(1, riddling.totalRiddles());
        assertEq(0, riddle1.index());
        assertEq(0, riddle2.index());

        // all bets rolled back
        assertEq(0, payable(riddle1).balance);
        assertEq(0, payable(registerProxy).balance);
        assertEq(0, RIDDLING.balance);
        assertEq(1000, GUESSING_1.balance);
        assertEq(2000, GUESSING_2.balance);
        assertEq(1000, GUESSING_3.balance);

        // below commit is possible because Register.riddleByStatement cleaned from riddle1.statement
        util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
    }

    function test_MetaTransaction() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
        assertEq(1, registerProxy.totalRiddles());
        assertEq(0, riddle.totalGuesses());

        vm.startPrank(SIGNER);
        registerProxy.registerMeAs("signer");

        ERC2771ForwarderUpgradeable.ForwardRequestData memory request = ERC2771ForwarderUpgradeable.ForwardRequestData({
            from: SIGNER,
            to: address(riddle),
            data: abi.encodeCall(IRiddle.guess, (true)),
            value: 0,
            gas: 1_000_000,
            deadline: uint48(block.timestamp + 1),
            signature: "" // should be overriden with signRequestData
        });

        request = MetaTxUtils.signRequestData(
            erc2771Forwarder, request, vm, SIGNER_PRIVATE_KEY, erc2771Forwarder.nonces(SIGNER)
        );

        erc2771Forwarder.execute(request);

        assertEq(1, riddle.totalGuesses());
        Guess memory guessByIndex = riddle.guessByIndex(0);
        assertEq(0, guessByIndex.bet);
        assertEq(SIGNER, guessByIndex.account);
        assertTrue(guessByIndex.credo);
    }

    function test_Upgrade_RevertWhen_CallerIsNotAuthorized() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        riddleBeaconHolder.upgradeTo(address(riddleV2Impl));
    }

    function test_Upgrade_Successful() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);

        Guess memory notExistingGuess = riddle.guessOf(RIDDLING);
        assertEq(address(0), notExistingGuess.account);

        vm.prank(UPGRADE_ADMIN);
        riddleBeaconHolder.upgradeTo(address(riddleV2Impl));

        Guess memory guessByNewRiddleVersion = riddle.guessOf(RIDDLING);
        assertEq(RIDDLING, guessByNewRiddleVersion.account);
    }

    function test_receive_Successful() public {
        IRiddle riddle = util_CreateRiddle(TYPICAL_RIDDLE_STATEMENT, true, USER_SECRET_KEY);
        assertEq(0, address(riddle).balance);

        vm.expectEmit(true, true, false, true);
        emit IRiddle.SponsorPaymentReceived(address(riddle), address(this), 1, 1000);
        (bool success,) = address(riddle).call{value: 1000}("");

        assertTrue(success);
        assertEq(1000, address(riddle).balance);
    }

    function util_CreateRiddle(string memory statement, bool solution, string memory userSecretKey)
        private
        returns (IRiddle riddle)
    {
        uint256 encryptedSolution = Utils.encryptSolution(statement, solution, userSecretKey);
        vm.prank(RIDDLING);
        riddle = riddling.commit(statement, encryptedSolution);
        return riddle;
    }
}
