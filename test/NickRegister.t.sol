// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {NickRegister} from "../src/NickRegister.sol";

contract NickRegisterTest is Test {
    NickRegister public nickRegister;

    address constant private OWNER = address(101);
    address immutable private CALLER = address(this);

    function setUp() public {
        nickRegister = new NickRegister(OWNER);
    }

    function test_RevertWhen_CallerIsNotOwner() public {
        bytes memory encodedUnauthorized = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, CALLER);

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

        vm.expectRevert(abi.encodeWithSelector(NickRegister.NickTooLong.selector, "ab123456789012345678901234567890", 32, 31));
        nickRegister.registerNick("ab123456789012345678901234567890");

        nickRegister.registerNick("a123456789012345678901234567890");
    }

    function test_RevertWhen_NotFound() public {
        vm.startPrank(address(OWNER));

        vm.expectRevert(abi.encodeWithSelector(NickRegister.NickNotRegistered.selector, "nick"));
        nickRegister.accountOf("nick");

        vm.expectRevert(abi.encodeWithSelector(NickRegister.AccountNotRegistered.selector, OWNER));
        nickRegister.nickOf(OWNER);

        vm.expectRevert(abi.encodeWithSelector(NickRegister.AccountNotRegistered.selector, OWNER));
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
        vm.prank(address(OWNER));
        assertEq(nickRegister.nicksTotal(), 0);

        util_RegisterOwnerAndUser();

        vm.prank(address(OWNER));
        assertEq(nickRegister.nicksTotal(), 2);
    }

    function test_getAllNicks() public {
        vm.prank(address(OWNER));
        assertEq(nickRegister.getAllNicks().length, 0);

        util_RegisterOwnerAndUser();

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user";
        expectedNicks[1] = "owner";
        vm.prank(address(OWNER));
        assertEq(nickRegister.getAllNicks(), expectedNicks);
    }

    function test_nickOf() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(OWNER));

        assertEq(nickRegister.nickOf(OWNER), "owner");
        assertEq(nickRegister.nickOf(CALLER), "user");

        vm.stopPrank();
    }

    function test_accountOf() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(OWNER));

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
