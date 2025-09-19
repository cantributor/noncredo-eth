// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {Register} from "src/Register.sol";
import {Riddle} from "src/Riddle.sol";
import {User} from "src/User.sol";

import {Utils} from "src/Utils.sol";

contract ScenarioUserCommit is Script {
    Register private registerProxy;

    function setUp() public {}

    function run(address payable registerProxyAddress, uint256 ownerPrivateKey) public {
        registerProxy = Register(registerProxyAddress);

        User owner = registerProxy.userOf("owner");

        string memory statement = "I am killer!";
        uint256 encryptedSolution = Utils.encryptSolution(statement, false, "secret");
        console.log("Encrypted solution: ", encryptedSolution);

        vm.broadcast(ownerPrivateKey);
        Riddle riddle = owner.commit(statement, encryptedSolution);
        console.log("Riddle contract address: ", address(riddle));
    }
}
