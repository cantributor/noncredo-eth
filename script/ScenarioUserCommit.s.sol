// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {IUser} from "../src/interfaces/IUser.sol";

import {Register} from "src/Register.sol";
import {Riddle} from "src/Riddle.sol";

import {Utils} from "src/Utils.sol";

contract ScenarioUserCommit is Script {
    Register private registerProxy;

    function setUp() public {}

    function run(address payable registerProxyAddress, uint256 ownerPrivateKey) public {
        registerProxy = Register(registerProxyAddress);

        vm.broadcast(ownerPrivateKey);
        registerProxy.setGuessAndRevealDuration(1, 1);
        vm.broadcast(ownerPrivateKey);
        registerProxy.setRegisterAndRiddlingRewards(1, 9);

        console.log("Guess minimum duration (blocks):", registerProxy.guessDurationBlocks());
        console.log("Reveal minimum duration (blocks):", registerProxy.revealDurationBlocks());
        console.log("Register reward (%):", registerProxy.registerRewardPercent());
        console.log("Riddling reward (%):", registerProxy.riddlingRewardPercent());

        string memory statement = "I am killer!";
        uint256 encryptedSolution = Utils.encryptCredo(statement, false, "secret");
        console.log("Encrypted solution: ", encryptedSolution);

        IUser owner = registerProxy.userOf("owner");
        vm.broadcast(ownerPrivateKey);
        owner.commit(statement, encryptedSolution);
    }
}
