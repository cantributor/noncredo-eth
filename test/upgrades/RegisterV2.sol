// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {Register} from "src/Register.sol";

contract RegisterV2 is Register {
    constructor(address trustedForwarder) Register(trustedForwarder) {}

    function getTotalUsers() external pure override returns (uint256) {
        return 777;
    }
}
