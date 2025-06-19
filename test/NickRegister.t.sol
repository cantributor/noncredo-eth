// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NickRegister} from "../src/NickRegister.sol";
import {IAccessManaged} from "../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {AccessManager} from "../lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";

contract NickRegisterTest is Test {
    AccessManager public accessManager;
    NickRegister public nickRegister;

    address private constant OWNER = address(101);
    address private constant ADMIN = address(777);
    address private immutable CALLER = address(this);

    uint64 private constant ADMIN_ROLE = 7;

    function setUp() public {
        accessManager = new AccessManager(OWNER);
        nickRegister = new NickRegister(address(accessManager));

        vm.startPrank(address(OWNER));

        bytes4[] memory nicksTotalSelector = new bytes4[](1);
        nicksTotalSelector[0] = bytes4(keccak256("nicksTotal()"));
        accessManager.setTargetFunctionRole(address(nickRegister), bytes4[](nicksTotalSelector), ADMIN_ROLE);

        bytes4[] memory getAllNicksSelector = new bytes4[](1);
        getAllNicksSelector[0] = bytes4(keccak256("getAllNicks()"));
        accessManager.setTargetFunctionRole(address(nickRegister), bytes4[](getAllNicksSelector), ADMIN_ROLE);

        bytes4[] memory nickOfSelector = new bytes4[](1);
        nickOfSelector[0] = bytes4(keccak256("nickOf(address)"));
        accessManager.setTargetFunctionRole(address(nickRegister), bytes4[](nickOfSelector), ADMIN_ROLE);

        bytes4[] memory accountOfSelector = new bytes4[](1);
        accountOfSelector[0] = bytes4(keccak256("accountOf(string)"));
        accessManager.setTargetFunctionRole(address(nickRegister), bytes4[](accountOfSelector), ADMIN_ROLE);

        accessManager.grantRole(ADMIN_ROLE, ADMIN, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_CallerIsNotAuthorized() public {
        bytes memory encodedUnauthorized =
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, CALLER);

        vm.expectRevert(encodedUnauthorized);
        nickRegister.nicksTotal();

        vm.expectRevert(encodedUnauthorized);
        nickRegister.nickOf(OWNER);

        vm.expectRevert(encodedUnauthorized);
        nickRegister.accountOf("nick");

        vm.expectRevert(encodedUnauthorized);
        nickRegister.getAllNicks();
    }

    function test_RevertWhen_NickTooShortOrTooLong() public {
        vm.expectRevert(abi.encodeWithSelector(NickRegister.NickTooShort.selector, "al", 2, 3));
        nickRegister.registerNick("al");

        vm.expectRevert(
            abi.encodeWithSelector(NickRegister.NickTooLong.selector, "ab123456789012345678901234567890", 32, 31)
        );
        nickRegister.registerNick("ab123456789012345678901234567890");

        nickRegister.registerNick("a123456789012345678901234567890");
    }

    function test_RevertWhen_NotFound() public {
        vm.startPrank(address(ADMIN));

        vm.expectRevert(abi.encodeWithSelector(NickRegister.NickNotRegistered.selector, "nick"));
        nickRegister.accountOf("nick");

        vm.expectRevert(abi.encodeWithSelector(NickRegister.AccountNotRegistered.selector, OWNER));
        nickRegister.nickOf(OWNER);

        vm.expectRevert(abi.encodeWithSelector(NickRegister.AccountNotRegistered.selector, ADMIN));
        nickRegister.myNick();

        vm.stopPrank();
    }

    function test_myNick_Repeatable() public {
        nickRegister.registerNick("nick1");
        assertEq(nickRegister.myNick(), "nick1");

        nickRegister.registerNick("nick2");
        assertEq(nickRegister.myNick(), "nick2");
    }

    function test_nicksTotal() public {
        vm.prank(address(ADMIN));
        assertEq(nickRegister.nicksTotal(), 0);

        util_RegisterOwnerAndUser();

        vm.prank(address(ADMIN));
        assertEq(nickRegister.nicksTotal(), 2);
    }

    function test_getAllNicks() public {
        vm.prank(address(ADMIN));
        assertEq(nickRegister.getAllNicks().length, 0);

        util_RegisterOwnerAndUser();

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user";
        expectedNicks[1] = "owner";
        vm.prank(address(ADMIN));
        assertEq(nickRegister.getAllNicks(), expectedNicks);
    }

    function test_nickOf() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(ADMIN));

        assertEq(nickRegister.nickOf(OWNER), "owner");
        assertEq(nickRegister.nickOf(CALLER), "user");

        vm.stopPrank();
    }

    function test_accountOf() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(ADMIN));

        assertEq(nickRegister.accountOf("owner"), OWNER);
        assertEq(nickRegister.accountOf("user"), CALLER);

        vm.stopPrank();
    }

    function test_RevertWhen_AlreadyExists() public {
        util_RegisterOwnerAndUser();

        vm.expectRevert(abi.encodeWithSelector(NickRegister.NickAlreadyRegistered.selector, "owner"));
        nickRegister.registerNick("owner");
    }

    function test_emit_SuccessfulNickRegistration() public {
        vm.expectEmit(true, true, false, false);

        emit NickRegister.SuccessfulNickRegistration(address(CALLER), "user");

        nickRegister.registerNick("user");
    }

    function util_RegisterOwnerAndUser() private {
        nickRegister.registerNick("user");
        vm.prank(address(OWNER));
        nickRegister.registerNick("owner");
    }
}
