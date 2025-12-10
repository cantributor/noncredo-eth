// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IRegister} from "../src/interfaces/IRegister.sol";
import {IRiddle} from "../src/interfaces/IRiddle.sol";
import {IUser} from "../src/interfaces/IUser.sol";

import {Utils} from "../src/Utils.sol";

import {ScriptUtils} from "./ScriptUtils.sol";

contract Actions is Script {
    IRegister private registerProxy;

    function setUp() public {}

    /**
     * @dev Register User
     * @param registerProxyAddress Register proxy address
     * @param privateKey User private key
     * @param nick User nick
     */
    function register(address payable registerProxyAddress, uint256 privateKey, string memory nick) public {
        registerProxy = IRegister(registerProxyAddress);

        vm.broadcast(privateKey);
        registerProxy.registerMeAs(nick);

        console.log("User", nick, "registered at block", vm.getBlockNumber());
        ScriptUtils.printUsers(registerProxy);
    }

    /**
     * @dev Commit a Riddle
     * @param registerProxyAddress Register proxy address
     * @param privateKey User private key
     * @param statement Riddle statement
     * @param bet Placed bet value
     * @param credo Riddle solution (Credo/NonCredo)
     * @param userSecretKey User secret key
     */
    function commit(
        address payable registerProxyAddress,
        uint256 privateKey,
        string memory statement,
        uint256 bet,
        bool credo,
        string memory userSecretKey
    ) public {
        registerProxy = IRegister(registerProxyAddress);

        address userOwnerAddress = vm.addr(privateKey);
        console.log("User owner address", userOwnerAddress);
        IUser user = registerProxy.userOf(userOwnerAddress);
        console.log("User contract address", address(user));

        uint256 encryptedSolution = Utils.encryptCredo(statement, credo, userSecretKey);
        console.log("Encrypted solution: ", encryptedSolution);

        vm.broadcast(privateKey);
        IRiddle riddle = user.commit{value: bet}(statement, encryptedSolution);

        ScriptUtils.describeRiddle(riddle);
    }
}
