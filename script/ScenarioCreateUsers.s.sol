// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {UserRegister} from "src/UserRegister.sol";
import {User} from "src/User.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ScenarioCreateUsers is Script {
    UserRegister private userRegisterProxy;

    function setUp() public {}

    function run(address userRegisterProxyAddress, uint256 ownerPrivateKey, uint256 userPrivateKey) public {
        userRegisterProxy = UserRegister(userRegisterProxyAddress);
        console.log("Message sender:", msg.sender);

        vm.broadcast(ownerPrivateKey);
        userRegisterProxy.registerMeAs("owner");
        vm.broadcast(userPrivateKey);
        userRegisterProxy.registerMeAs("user");

        vm.startBroadcast(ownerPrivateKey);
        console.log("Total users: ", userRegisterProxy.getTotalUsers());
        string[] memory userNicks = userRegisterProxy.getAllNicks();
        for (uint256 i = 0; i < userNicks.length; i++) {
            User user = userRegisterProxy.userOf(userNicks[i]);
            string memory owner = Strings.toHexString(uint256(uint160(user.owner())), 20);
            console.log("User", user.getIndex(), user.getNick(), owner);
        }
        vm.stopBroadcast();
    }
}
