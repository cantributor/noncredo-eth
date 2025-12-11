// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {console} from "forge-std/Script.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";
import {IRiddle} from "../src/interfaces/IRiddle.sol";
import {IUser} from "../src/interfaces/IUser.sol";

import {Guess} from "../src/structs/Guess.sol";

import {Utils} from "../src/Utils.sol";

library ScriptUtils {
    /**
     * @dev Prints all users
     * @param registerProxy Register proxy address
     */
    function printUsers(IRegister registerProxy) public {
        console.log("Total users:", registerProxy.totalUsers());
        string[] memory userNicks = Utils.allNicks(registerProxy);
        for (uint256 i = 0; i < userNicks.length; i++) {
            IUser user = registerProxy.userOf(userNicks[i]);
            describeUser(user);
        }
    }

    /**
     * @dev Describe User
     * @param user User contract
     */
    function describeUser(IUser user) public view {
        address owner = user.owner();
        console.log("User:", user.index(), user.nickString(), owner);
        console.log("    balance:", address(owner).balance);
        console.log("    contract:", address(user));
        console.log("    rating:", user.rating());
    }

    /**
     * @dev Prints all riddles
     * @param registerProxy Register proxy address
     */
    function printRiddles(IRegister registerProxy) public view {
        console.log("Total riddles:", registerProxy.totalRiddles());
        for (uint256 i = 0; i < registerProxy.totalRiddles(); i++) {
            IRiddle riddle = registerProxy.riddles(i);
            describeRiddle(riddle);
        }
    }

    /**
     * @dev Describe Riddle
     * @param riddle Riddle contract
     */
    function describeRiddle(IRiddle riddle) public view {
        console.log("Riddle (id/index): ", riddle.id(), riddle.index());
        console.log("    statement: ", riddle.statement());
        console.log("    owner nick: ", riddle.user().nickString());
        console.log("    owner account: ", riddle.owner());
        console.log("    balance: ", address(riddle).balance);
        console.log("    deadlines: ", riddle.guessDeadline(), riddle.revealDeadline());
        console.log("    status (revelation/finished): ", riddle.revelation(), riddle.finished());
        console.log("    rating: ", riddle.rating());
        console.log("    total guesses: ", riddle.totalGuesses());
        for (uint256 i = 0; i < riddle.totalGuesses(); i++) {
            Guess memory guess = riddle.guessByIndex(i);
            console.log("    guess (index/revealed/bet)", i, guess.revealed, guess.bet);
            console.log("        account: ", guess.account);
            if (guess.revealed) {
                console.log("        credo: ", guess.credo);
            } else {
                console.log("        encrypted credo: ", guess.encryptedCredo);
            }
        }
    }

    /**
     * @dev Prints Register settings and state
     * @param registerProxy Register proxy address
     */
    function printRegisterSettingsAndState(IRegister registerProxy) public view {
        console.log("Paused:", registerProxy.paused());
        console.log(
            "Guess and reveal durations (blocks):",
            registerProxy.guessDurationBlocks(),
            registerProxy.revealDurationBlocks()
        );
        console.log("Register reward (%):", registerProxy.registerRewardPercent());
        console.log("Riddle ban threshold:", registerProxy.riddleBanThreshold());
        console.log("Total users:", registerProxy.totalUsers());
        console.log("Total riddles:", registerProxy.totalRiddles());
    }

    /**
     * @dev Prints full Register report
     * @param registerProxy Register proxy address
     */
    function printFullReport(IRegister registerProxy) public {
        console.log("======================================= FULL REPORT =======================================");
        printRegisterSettingsAndState(registerProxy);
        console.log("------------------------------------------ USERS ------------------------------------------");
        printUsers(registerProxy);
        console.log("----------------------------------------- RIDDLES -----------------------------------------");
        printRiddles(registerProxy);
        console.log("===========================================================================================");
    }
}
