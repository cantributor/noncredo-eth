// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {UserRegister} from "../src/UserRegister.sol";
import {User} from "../src/User.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {ShortStrings} from "@openzeppelin/contracts/utils/ShortStrings.sol";
import {ShortString} from "@openzeppelin/contracts/utils/ShortStrings.sol";

contract UserTest is Test {
    address private constant USER_REGISTER_ADDRESS = address(1);

    UpgradeableBeacon private userUpgradeableBeacon;

    function setUp() public {
        userUpgradeableBeacon = new UpgradeableBeacon(address(new User()), address(this));
    }

    function test_BasicUsage() public {
        User user = util_createUser(address(this), ShortStrings.toShortString("user"), 1);

        assertEq("user", user.getNick());
        assertEq(1, user.getIndex());

        vm.prank(USER_REGISTER_ADDRESS);
        user.setIndex(777);

        assertEq(777, user.getIndex());
    }

    function test_setIndex_RevertWhen_IllegalIndexChange() public {
        User user = util_createUser(address(this), ShortStrings.toShortString("user"), 1);

        vm.expectRevert(abi.encodeWithSelector(User.UnauthorizedIndexChange.selector, this));
        user.setIndex(666);
    }

    function util_createUser(address owner, ShortString nickShortString, uint256 index) private returns (User user) {
        BeaconProxy userBeaconProxy = new BeaconProxy(
            address(userUpgradeableBeacon),
            abi.encodeWithSignature(
                "initialize(address,bytes32,uint256,address)", owner, nickShortString, index, USER_REGISTER_ADDRESS
            )
        );
        user = User(address(userBeaconProxy));
        return user;
    }
}
