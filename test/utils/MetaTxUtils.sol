// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";

import {Vm} from "forge-std/Vm.sol";

import {ERC2771Forwarder} from "src/ERC2771Forwarder.sol";

import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";

library MetaTxUtils {
    function signRequestData(
        ERC2771Forwarder erc2771Forwarder,
        ERC2771ForwarderUpgradeable.ForwardRequestData memory request,
        Vm vm,
        uint256 signerPrivateKey,
        uint256 nonce
    ) external view returns (ERC2771ForwarderUpgradeable.ForwardRequestData memory) {
        bytes32 digest = erc2771Forwarder.forwardRequestStructHash(request, nonce);
        console.log("digest:", uint256(digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digest);
        console.log("v:", v);
        console.log("r:", uint256(r));
        console.log("s:", uint256(s));
        request.signature = abi.encodePacked(r, s, v);
        return request;
    }
}
