// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {Register} from "src/Register.sol";
import {User} from "src/User.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ScenarioCreateUsers is Script {
    Register private registerProxy;

    function setUp() public {}

    function run(
        address registerProxyAddress,
        uint256 ownerPrivateKey,
        uint256 user1PrivateKey,
        uint256 user2PrivateKey
    ) public {
        registerProxy = Register(registerProxyAddress);
        console.log("Message sender:", msg.sender);

        vm.broadcast(ownerPrivateKey);
        registerProxy.registerMeAs("owner");
        vm.broadcast(user1PrivateKey);
        registerProxy.registerMeAs("user1");
        vm.broadcast(user2PrivateKey);
        registerProxy.registerMeAs("user2");

        vm.startBroadcast(ownerPrivateKey);
        console.log("Total users: ", registerProxy.getTotalUsers());
        string[] memory userNicks = registerProxy.getAllNicks();
        for (uint256 i = 0; i < userNicks.length; i++) {
            User user = registerProxy.userOf(userNicks[i]);
            string memory owner = Strings.toHexString(uint256(uint160(user.owner())), 20);
            console.log("User", user.getIndex(), user.getNick(), owner);
        }
        vm.stopBroadcast();
    }
}
