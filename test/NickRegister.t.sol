// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {NickRegister} from "../src/NickRegister.sol";
import {IAccessManaged} from "../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {AccessManager} from "../lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {ERC2771Forwarder} from "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Forwarder.sol";

contract NickRegisterTest is Test {
    AccessManager public accessManager;
    NickRegister public nickRegister;
    TestERC2771Forwarder public testErc2771Forwarder;

    uint256 private constant SIGNER_PRIVATE_KEY = 0xACE101;

    address private constant OWNER = address(101);
    address private constant ADMIN = address(777);
    address private immutable USER = address(this);
    address private immutable SIGNER = vm.addr(SIGNER_PRIVATE_KEY);

    uint64 private constant ADMIN_ROLE = 7;

    function setUp() public {
        accessManager = new AccessManager(OWNER);
        testErc2771Forwarder = new TestERC2771Forwarder("testForwarder");
        nickRegister = new NickRegister(address(accessManager), address(testErc2771Forwarder));

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
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER);

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
        assertEq(nickRegister.nickOf(USER), "user");

        vm.stopPrank();
    }

    function test_accountOf() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(ADMIN));

        assertEq(nickRegister.accountOf("owner"), OWNER);
        assertEq(nickRegister.accountOf("user"), USER);

        vm.stopPrank();
    }

    function test_RevertWhen_AlreadyExists() public {
        util_RegisterOwnerAndUser();

        vm.expectRevert(abi.encodeWithSelector(NickRegister.NickAlreadyRegistered.selector, "owner"));
        nickRegister.registerNick("owner");
    }

    function test_emit_SuccessfulNickRegistration() public {
        vm.expectEmit(true, true, false, false);

        emit NickRegister.SuccessfulNickRegistration(address(USER), "user");

        nickRegister.registerNick("user");
    }

    function test_MetaTransaction() public {
        vm.prank(address(ADMIN));
        assertEq(nickRegister.nicksTotal(), 0);

        ERC2771Forwarder.ForwardRequestData memory request = ERC2771Forwarder.ForwardRequestData({
            from: SIGNER,
            to: address(nickRegister),
            data: abi.encodeCall(NickRegister.registerNick, ("signer")),
            value: 0,
            gas: 1000000,
            deadline: uint48(block.timestamp + 1),
            signature: "" // should be overriden with util_signRequestData
        });

        util_signRequestData(request, testErc2771Forwarder.nonces(SIGNER));

        testErc2771Forwarder.execute(request);

        vm.prank(address(ADMIN));
        assertEq(nickRegister.nicksTotal(), 1);

        vm.prank(address(ADMIN));
        assertEq(nickRegister.nickOf(SIGNER), "signer");
    }

    function util_RegisterOwnerAndUser() private {
        nickRegister.registerNick("user");
        vm.prank(address(OWNER));
        nickRegister.registerNick("owner");
    }

    function util_signRequestData(ERC2771Forwarder.ForwardRequestData memory request, uint256 nonce)
        private
        view
        returns (ERC2771Forwarder.ForwardRequestData memory)
    {
        bytes32 digest = testErc2771Forwarder.forwardRequestStructHash(request, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        request.signature = abi.encodePacked(r, s, v);
        return request;
    }
}

contract TestERC2771Forwarder is ERC2771Forwarder {
    constructor(string memory name) ERC2771Forwarder(name) {}

    function forwardRequestStructHash(ERC2771Forwarder.ForwardRequestData calldata request, uint256 nonce)
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
