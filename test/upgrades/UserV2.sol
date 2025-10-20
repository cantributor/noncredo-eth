// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {User} from "src/User.sol";

import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";

contract UserV2 is User {
    string private suffix;

    constructor(address trustedForwarder) User(trustedForwarder) {}

    function nickString() external view override returns (string memory) {
        return string.concat(ShortStrings.toString(nick), "_", suffix);
    }

    function setSuffix(string calldata _suffix) external {
        suffix = _suffix;
    }
}
