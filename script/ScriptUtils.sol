// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {console} from "forge-std/Script.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";
import {IRiddle} from "../src/interfaces/IRiddle.sol";
import {IUser} from "../src/interfaces/IUser.sol";

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
            address owner = user.owner();
            console.log("User", user.index(), user.nickString(), owner);
            console.log("    balance:", address(owner).balance);
        }
    }

    /**
     * @dev Describe Riddle
     * @param riddle Riddle contract
     */
    function describeRiddle(IRiddle riddle) public view {
        console.log("Riddle (id/index): ", riddle.id(), riddle.index());
        console.log("    statement: ", riddle.statement());
        console.log("    owner: ", riddle.owner());
        console.log("    balance: ", address(riddle).balance);
        console.log("    deadlines: ", riddle.guessDeadline(), riddle.revealDeadline());
        console.log("    status (revelation/finished): ", riddle.revelation(), riddle.finished());
        console.log("    rating: ", riddle.rating());
    }
}
