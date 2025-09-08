// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {AccessManaged} from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title AccessManagedBeaconHolder
 * @dev Access managed UpgradeableBeacon holder
 */
contract AccessManagedBeaconHolder is AccessManaged, Initializable {
    UpgradeableBeacon public beacon;

    /**
     * @dev Constructor
     * @param _initialAuthority Initial authority
     */
    constructor(address _initialAuthority) AccessManaged(_initialAuthority) {}

    /**
     * @dev Initializable implementation
     * @param _beacon Upgradeable beacon
     */
    function initialize(UpgradeableBeacon _beacon) public initializer {
        beacon = _beacon;
    }

    /**
     * @dev Upgrades the beacon to a new implementation
     *
     * Emits an {Upgraded} event.
     *
     * @param newImplementation new implementation (must be a contract)
     */
    function upgradeTo(address newImplementation) public virtual restricted {
        beacon.upgradeTo(newImplementation);
    }
}
