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
     * @dev Change Register settings
     * @param guessDuration New guess duration value
     * @param revealDuration New reveal duration value
     */
    function settings(
        address payable registerProxyAddress,
        uint256 privateKey,
        uint32 guessDuration,
        uint32 revealDuration
    ) public {
        registerProxy = IRegister(registerProxyAddress);

        console.log(
            "Register durations before change: guess",
            registerProxy.guessDurationBlocks(),
            "reveal",
            registerProxy.revealDurationBlocks()
        );

        vm.broadcast(privateKey);
        registerProxy.setGuessAndRevealDuration(guessDuration, revealDuration);

        console.log(
            "Register durations now: guess",
            registerProxy.guessDurationBlocks(),
            "reveal",
            registerProxy.revealDurationBlocks()
        );
    }

    /**
     * @dev Prints full Register report
     */
    function printFullReport(address payable registerProxyAddress) public {
        registerProxy = IRegister(registerProxyAddress);
        ScriptUtils.printFullReport(registerProxy);
    }

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
        console.log("Current block", vm.getBlockNumber());

        registerProxy = IRegister(registerProxyAddress);

        address userOwnerAddress = vm.addr(privateKey);
        IUser user = registerProxy.userOf(userOwnerAddress);
        ScriptUtils.describeUser(user);

        uint256 encryptedSolution = Utils.encryptCredo(statement, credo, userSecretKey);

        vm.broadcast(privateKey);
        IRiddle riddle = user.commit{value: bet}(statement, encryptedSolution);

        ScriptUtils.describeRiddle(riddle);
    }

    /**
     * @dev Guess a Riddle
     * @param registerProxyAddress Register proxy address
     * @param privateKey User private key
     * @param riddleId Riddle id
     * @param bet Placed bet value
     * @param credo Riddle solution (Credo/NonCredo)
     * @param userSecretKey User secret key
     */
    function guess(
        address payable registerProxyAddress,
        uint256 privateKey,
        uint32 riddleId,
        uint256 bet,
        bool credo,
        string memory userSecretKey
    ) public {
        console.log("Current block", vm.getBlockNumber());

        registerProxy = IRegister(registerProxyAddress);

        address userOwnerAddress = vm.addr(privateKey);
        IUser user = registerProxy.userOf(userOwnerAddress);
        ScriptUtils.describeUser(user);

        IRiddle riddle = Utils.riddleById(registerProxy, riddleId);

        uint256 encryptedCredo = Utils.encryptCredo(riddle.statement(), credo, userSecretKey);

        vm.broadcast(privateKey);
        riddle.guess{value: bet}(encryptedCredo);

        ScriptUtils.describeRiddle(riddle);
    }

    /**
     * @dev Reveal a Riddle Guess
     * @param registerProxyAddress Register proxy address
     * @param privateKey User private key
     * @param riddleId Riddle id
     * @param userSecretKey User secret key
     */
    function reveal(
        address payable registerProxyAddress,
        uint256 privateKey,
        uint32 riddleId,
        string memory userSecretKey
    ) public {
        console.log("Current block", vm.getBlockNumber());

        registerProxy = IRegister(registerProxyAddress);

        address userOwnerAddress = vm.addr(privateKey);
        IUser user = registerProxy.userOf(userOwnerAddress);
        ScriptUtils.describeUser(user);

        IRiddle riddle = Utils.riddleById(registerProxy, riddleId);

        vm.broadcast(privateKey);
        riddle.reveal(userSecretKey);

        ScriptUtils.describeRiddle(riddle);
    }
}
