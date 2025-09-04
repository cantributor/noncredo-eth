// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {UserRegister} from "src/UserRegister.sol";
import {User} from "src/User.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ScenarioBasic is Script {
    UserRegister private userRegisterProxy;

    function setUp() public {}

    function run(address userRegisterProxyAddress) public {
        userRegisterProxy = UserRegister(userRegisterProxyAddress);
        console.log("Message sender:", msg.sender);

        vm.broadcast(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
        userRegisterProxy.registerMeAs("user1");
        vm.broadcast(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a);
        userRegisterProxy.registerMeAs("user2");
        vm.broadcast(0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6);
        userRegisterProxy.registerMeAs("user3");

        vm.startPrank(msg.sender);
        console.log("Total users: ", userRegisterProxy.getTotalUsers());
        string[] memory userNicks = userRegisterProxy.getAllNicks();
        for (uint256 i = 0; i < userNicks.length; i++) {
            User user = userRegisterProxy.userOf(userNicks[i]);
            string memory owner = Strings.toHexString(uint256(uint160(user.owner())), 20);
            console.log("User", user.getIndex(), user.getNick(), owner);
        }
        vm.stopPrank();
    }
}
