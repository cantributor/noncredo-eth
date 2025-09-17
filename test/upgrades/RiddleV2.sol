// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Guess} from "src/Guess.sol";
import {Riddle} from "src/Riddle.sol";

contract RiddleV2 is Riddle {
    function guessOf(address sender) external pure override returns (Guess memory _guess) {
        return Guess(sender, true, 777);
    }
}
