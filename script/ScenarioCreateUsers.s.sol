// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IUser} from "../src/interfaces/IUser.sol";
import {IRegister} from "../src/interfaces/IRegister.sol";

import {Utils} from "../src/Utils.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ScenarioCreateUsers is Script {
    IRegister private registerProxy;

    function setUp() public {}

    function run(
        address payable registerProxyAddress,
        uint256 ownerPrivateKey,
        uint256 user1PrivateKey,
        uint256 user2PrivateKey
    ) public {
        registerProxy = IRegister(registerProxyAddress);

        vm.broadcast(ownerPrivateKey);
        registerProxy.registerMeAs("owner");
        vm.broadcast(user1PrivateKey);
        registerProxy.registerMeAs("user1");
        vm.broadcast(user2PrivateKey);
        registerProxy.registerMeAs("user2");

        vm.startBroadcast(ownerPrivateKey);
        console.log("Total users:", registerProxy.totalUsers());
        string[] memory userNicks = Utils.allNicks(registerProxy);
        for (uint256 i = 0; i < userNicks.length; i++) {
            IUser user = registerProxy.userOf(userNicks[i]);
            string memory owner = Strings.toHexString(uint256(uint160(user.owner())), 20);
            console.log("User", user.index(), user.nickString(), owner);
        }
        vm.stopBroadcast();
    }
}
