// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";

import {ScriptUtils} from "./ScriptUtils.sol";

contract ActionRegister is Script {
    IRegister private registerProxy;

    function setUp() public {}

    function run(address payable registerProxyAddress, uint256 privateKey, string memory nick) public {
        registerProxy = IRegister(registerProxyAddress);

        vm.broadcast(privateKey);
        registerProxy.registerMeAs(nick);

        console.log("User", nick, "registered at block", vm.getBlockNumber());
        ScriptUtils.printUsers(registerProxy);
    }
}
