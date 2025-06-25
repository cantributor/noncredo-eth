// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {UserRegister} from "../src/UserRegister.sol";
import {IAccessManaged} from "../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {AccessManager} from "../lib/openzeppelin-contracts/contracts/access/manager/AccessManager.sol";
import {ERC2771Forwarder} from "../lib/openzeppelin-contracts/contracts/metatx/ERC2771Forwarder.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {Initializable} from "../lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {UserUtils} from "../src/UserUtils.sol";
import {User} from "../src/User.sol";

contract UserFactoryTest is Test {
    AccessManager public accessManager;
    UserRegister public userRegister;
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
        userRegister = new UserRegister(address(accessManager), address(testErc2771Forwarder));

        vm.startPrank(address(OWNER));

        bytes4[] memory userOfStringSelector = new bytes4[](1);
        userOfStringSelector[0] = bytes4(keccak256("userOf(string)"));
        accessManager.setTargetFunctionRole(address(userRegister), bytes4[](userOfStringSelector), ADMIN_ROLE);

        bytes4[] memory userOfAddressSelector = new bytes4[](1);
        userOfAddressSelector[0] = bytes4(keccak256("userOf(address)"));
        accessManager.setTargetFunctionRole(address(userRegister), bytes4[](userOfAddressSelector), ADMIN_ROLE);

        accessManager.grantRole(ADMIN_ROLE, ADMIN, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_CallerIsNotAuthorized() public {
        bytes memory encodedUnauthorized =
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER);

        vm.expectRevert(encodedUnauthorized);
        userRegister.userOf("nick");

        vm.expectRevert(encodedUnauthorized);
        userRegister.userOf(OWNER);
    }

    function test_RevertWhen_NickTooShortOrTooLong() public {
        vm.expectRevert(abi.encodeWithSelector(UserUtils.NickTooShort.selector, "al", 2, 3));
        userRegister.registerUser("al");

        vm.expectRevert(
            abi.encodeWithSelector(UserUtils.NickTooLong.selector, "ab123456789012345678901234567890", 32, 31)
        );
        userRegister.registerUser("ab123456789012345678901234567890");

        userRegister.registerUser("a123456789012345678901234567890");
    }

    function test_RevertWhen_NotFound() public {
        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountNotRegistered.selector, USER));
        userRegister.me();

        vm.startPrank(address(ADMIN));

        vm.expectRevert(abi.encodeWithSelector(UserRegister.NickNotRegistered.selector, "nick"));
        userRegister.userOf("nick");

        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountNotRegistered.selector, USER));
        userRegister.userOf(USER);

        vm.stopPrank();
    }

    function test_userOfAddress() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(ADMIN));

        assertEq(userRegister.userOf(OWNER).getNick(), "owner");
        assertEq(userRegister.userOf(USER).getNick(), "user");

        vm.stopPrank();
    }

    function test_userOfString() public {
        util_RegisterOwnerAndUser();

        vm.startPrank(address(ADMIN));

        assertEq(userRegister.userOf("owner").getNick(), "owner");
        assertEq(userRegister.userOf("user").getNick(), "user");

        vm.stopPrank();
    }

    function test_me() public {
        util_RegisterOwnerAndUser();

        assertEq(userRegister.me().getNick(), "user");
    }

    function test_getTotalUsers() public {
        assertEq(userRegister.getTotalUsers(), 0);

        util_RegisterOwnerAndUser();

        assertEq(userRegister.getTotalUsers(), 2);
    }

    function test_getAllNicks() public {
        assertEq(userRegister.getAllNicks().length, 0);

        util_RegisterOwnerAndUser();

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user";
        expectedNicks[1] = "owner";
        assertEq(userRegister.getAllNicks(), expectedNicks);
    }

    function test_RevertWhen_AlreadyExists() public {
        util_RegisterOwnerAndUser();

        vm.expectRevert(abi.encodeWithSelector(UserRegister.NickAlreadyRegistered.selector, "owner"));
        userRegister.registerUser("owner");

        vm.expectRevert(abi.encodeWithSelector(UserRegister.AccountAlreadyRegistered.selector, USER));
        userRegister.registerUser("user2");
    }

    function test_emit_SuccessfulUserRegistration() public {
        vm.expectEmit(true, true, false, false);

        emit UserRegister.SuccessfulUserRegistration(address(USER), "user");

        userRegister.registerUser("user");
    }

    function test_RevertWhen_TryingToReinitializeUser() public {
        userRegister.registerUser("user");

        User user = userRegister.me();

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        user.initialize(USER, ShortStrings.toShortString("hacker"));
    }

    function test_MetaTransaction() public {
        vm.prank(address(ADMIN));

        ERC2771Forwarder.ForwardRequestData memory request = ERC2771Forwarder.ForwardRequestData({
            from: SIGNER,
            to: address(userRegister),
            data: abi.encodeCall(UserRegister.registerUser, ("signer")),
            value: 0,
            gas: 1000000,
            deadline: uint48(block.timestamp + 1),
            signature: "" // should be overriden with util_signRequestData
        });

        util_signRequestData(request, testErc2771Forwarder.nonces(SIGNER));

        testErc2771Forwarder.execute(request);

        vm.prank(address(ADMIN));
        assertEq(userRegister.userOf(SIGNER).getNick(), "signer");
    }

    function util_RegisterOwnerAndUser() private {
        userRegister.registerUser("user");
        vm.prank(address(OWNER));
        userRegister.registerUser("owner");
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
