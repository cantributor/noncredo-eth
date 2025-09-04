// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.28;

import {AccessManagedUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title AccessManagedBeaconHolder
 * @dev Access managed UpgradeableBeacon holder
 */
contract AccessManagedBeaconHolder is AccessManagedUpgradeable {
    UpgradeableBeacon public beacon;

    /**
     * @dev Initializable implementation
     * @param _beacon Upgradeable beacon
     */
    function initialize(address initialAuthority, UpgradeableBeacon _beacon) public initializer {
        __AccessManaged_init(initialAuthority);
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
