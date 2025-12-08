// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IUser} from "../src/interfaces/IUser.sol";
import {IRegister} from "../src/interfaces/IRegister.sol";

import {Utils} from "../src/Utils.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ActionRegister is Script {
    IRegister private registerProxy;

    function setUp() public {}

    function run(address payable registerProxyAddress, uint256 privateKey, string memory nick) public {
        registerProxy = IRegister(registerProxyAddress);

        vm.broadcast(privateKey);
        registerProxy.registerMeAs(nick);

        console.log("Total users:", registerProxy.totalUsers());
        string[] memory userNicks = Utils.allNicks(registerProxy);
        for (uint256 i = 0; i < userNicks.length; i++) {
            IUser user = registerProxy.userOf(userNicks[i]);
            string memory owner = Strings.toHexString(uint256(uint160(user.owner())), 20);
            console.log("User", user.index(), user.nickString(), owner);
        }
    }
}
