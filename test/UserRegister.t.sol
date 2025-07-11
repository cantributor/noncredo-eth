// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {UserRegister} from "../src/UserRegister.sol";
import {Roles} from "../src/Roles.sol";
import {User} from "../src/User.sol";
import {UserUtils} from "../src/UserUtils.sol";

import {IAccessManaged} from "../lib/openzeppelin-contracts/contracts/access/manager/IAccessManaged.sol";
import {AccessManagerUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/access/manager/AccessManagerUpgradeable.sol";
import {ERC2771ForwarderUpgradeable} from
    "../lib/openzeppelin-contracts-upgradeable/contracts/metatx/ERC2771ForwarderUpgradeable.sol";
import {ShortStrings} from "../lib/openzeppelin-contracts/contracts/utils/ShortStrings.sol";
import {Initializable} from
    "../lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "../lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract UserFactoryTest is Test {
    AccessManagerUpgradeable public accessManagerUpgradeable;
    UserRegister public userRegister;
    TestERC2771Forwarder public testErc2771Forwarder;
    ERC1967Proxy erc1967Proxy;

    uint256 private constant SIGNER_PRIVATE_KEY = 0xACE101;

    address private constant OWNER = address(1);
    address private constant ADMIN = address(3);
    address private immutable USER = address(this);
    address private immutable SIGNER = vm.addr(SIGNER_PRIVATE_KEY);

    function setUp() public {
        accessManagerUpgradeable = new AccessManagerUpgradeable();
        accessManagerUpgradeable.initialize(OWNER);

        testErc2771Forwarder = new TestERC2771Forwarder();
        testErc2771Forwarder.initialize("testForwarder");

        userRegister = new UserRegister(address(testErc2771Forwarder));
        erc1967Proxy = new ERC1967Proxy(
            address(userRegister), abi.encodeWithSignature("initialize(address)", accessManagerUpgradeable)
        );

        vm.startPrank(address(OWNER));

        bytes4[] memory userOfStringSelector = new bytes4[](1);
        userOfStringSelector[0] = bytes4(keccak256("userOf(string)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), bytes4[](userOfStringSelector), Roles.ADMIN_ROLE
        );

        bytes4[] memory userOfAddressSelector = new bytes4[](1);
        userOfAddressSelector[0] = bytes4(keccak256("userOf(address)"));
        accessManagerUpgradeable.setTargetFunctionRole(
            address(erc1967Proxy), bytes4[](userOfAddressSelector), Roles.ADMIN_ROLE
        );

        accessManagerUpgradeable.grantRole(Roles.ADMIN_ROLE, ADMIN, 0);

        vm.stopPrank();
    }

    function test_RevertWhen_CallerIsNotAuthorized() public {
        bytes memory encodedUnauthorized =
            abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, USER);

        vm.expectRevert(encodedUnauthorized);
        address(erc1967Proxy).call(abi.encodeWithSignature("userOf(address)", USER));

        vm.expectRevert(encodedUnauthorized);
        address(erc1967Proxy).call(abi.encodeWithSignature("userOf(string)", "user"));
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
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        vm.prank(address(ADMIN));

        (bool success, bytes memory result) =
            address(erc1967Proxy).call(abi.encodeWithSignature("userOf(address)", USER));
        assertTrue(success);
        User user = abi.decode(result, (User));
        assertEq("user", user.getNick());
    }

    function test_userOfString() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        vm.startPrank(address(ADMIN));

        assertEq(userRegister.userOf("owner").getNick(), "owner");
        assertEq(userRegister.userOf("user").getNick(), "user");

        vm.stopPrank();
    }

    function test_me() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        assertEq(userRegister.me().getNick(), "user");
    }

    function test_getTotalUsers() public {
        assertEq(userRegister.getTotalUsers(), 0);

        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        assertEq(userRegister.getTotalUsers(), 2);
    }

    function test_getAllNicks() public {
        assertEq(userRegister.getAllNicks().length, 0);

        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

        string[] memory expectedNicks = new string[](2);
        expectedNicks[0] = "user";
        expectedNicks[1] = "owner";
        assertEq(userRegister.getAllNicks(), expectedNicks);
    }

    function test_RevertWhen_AlreadyExists() public {
        util_RegisterAccount(USER, "user");
        util_RegisterAccount(OWNER, "owner");

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

        ERC2771ForwarderUpgradeable.ForwardRequestData memory request = ERC2771ForwarderUpgradeable.ForwardRequestData({
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

    function test_Upgradeability() public {
        console.log("userRegister.authority()", userRegister.authority());

        UserRegister userRegisterV2 = new UserRegisterV2(address(accessManagerUpgradeable));

        //  bytes memory result
        (bool success,) = address(erc1967Proxy).call(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                userRegisterV2,
                abi.encodeWithSignature("initialize(address)", accessManagerUpgradeable)
            )
        );

        assertFalse(success);
    }

    function util_RegisterAccount(address account, string memory nick) private {
        vm.prank(account);
        (bool success,) = address(erc1967Proxy).call(abi.encodeWithSignature("registerUser(string)", nick));
        assertTrue(success);
    }

    function util_signRequestData(ERC2771ForwarderUpgradeable.ForwardRequestData memory request, uint256 nonce)
        private
        view
        returns (ERC2771ForwarderUpgradeable.ForwardRequestData memory)
    {
        bytes32 digest = testErc2771Forwarder.forwardRequestStructHash(request, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        request.signature = abi.encodePacked(r, s, v);
        return request;
    }
}

contract UserRegisterV2 is UserRegister {
    constructor(address trustedForwarder) UserRegister(trustedForwarder) {}
}

contract TestERC2771Forwarder is ERC2771ForwarderUpgradeable {
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
