// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {console} from "forge-std/Script.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";
import {IUser} from "../src/interfaces/IUser.sol";

import {Utils} from "../src/Utils.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

library ScriptUtils {
    /**
     * @dev Prints all users
     */
    function printUsers(IRegister registerProxy) public {
        console.log("Total users:", registerProxy.totalUsers());
        string[] memory userNicks = Utils.allNicks(registerProxy);
        for (uint256 i = 0; i < userNicks.length; i++) {
            IUser user = registerProxy.userOf(userNicks[i]);
            string memory owner = Strings.toHexString(uint256(uint160(user.owner())), 20);
            console.log("User", user.index(), user.nickString(), owner);
        }
    }
}
