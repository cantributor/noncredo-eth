// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";

contract ERC2771Forwarder is ERC2771ForwarderUpgradeable {
    constructor() ERC2771ForwarderUpgradeable() {}

    function forwardRequestStructHash(ERC2771ForwarderUpgradeable.ForwardRequestData calldata request, uint256 nonce)
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _FORWARD_REQUEST_TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    nonce,
                    request.deadline,
                    keccak256(request.data)
                )
            )
        );
    }
}
