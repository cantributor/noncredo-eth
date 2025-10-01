// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {User} from "src/User.sol";
import {Register} from "src/Register.sol";

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";
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
