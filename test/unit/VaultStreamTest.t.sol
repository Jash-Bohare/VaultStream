// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV1} from "../../src/VaultStreamV1.sol";
import {DeployVaultStream} from "../../script/DeployVaultStream.s.sol";

contract VaultStreamTest is Test {
    VaultStreamV1 public vaultStream;

    address public OWNER;
    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant SUBSCRIPTION_PRICE = 0.01 ether;
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;

    function setUp() public {
        DeployVaultStream deployer = new DeployVaultStream();
        vaultStream = VaultStreamV1(deployer.run());

        OWNER = vaultStream.owner();

        vm.deal(OWNER, STARTING_BALANCE);
        vm.deal(USER1, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    function test_Initialization() public {
        assertEq(vaultStream.subscriptionPrice(), SUBSCRIPTION_PRICE);

        assertEq(vaultStream.subscriptionDuration(), SUBSCRIPTION_DURATION);

        assertEq(vaultStream.totalDeposited(), 0);
        assertEq(vaultStream.owner(), OWNER);
    }

    function test_InitializeCannotBeCalledTwice() public {
        vm.expectRevert();

        vaultStream.initialize(SUBSCRIPTION_PRICE, SUBSCRIPTION_DURATION);
    }

    function test_ImplementationCannotBeInitialized() public {
        VaultStreamV1 implementation = new VaultStreamV1();

        vm.expectRevert();

        implementation.initialize(SUBSCRIPTION_PRICE, SUBSCRIPTION_DURATION);
    }

    function test_Version() public {
        assertEq(vaultStream.version(), 1);
    }

    function test_Subscribe() public {
        uint256 expectedExpiry = block.timestamp + SUBSCRIPTION_DURATION;

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(vaultStream.subscriptionExpiry(USER1), expectedExpiry);

        assertEq(vaultStream.totalDeposited(), SUBSCRIPTION_PRICE);
    }

    function test_SubscribeMakesUserActive() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertTrue(vaultStream.isActive(USER1));
    }

    function test_SubscribeEmitsSubscribedEvent() public {
        uint256 expectedExpiry = block.timestamp + SUBSCRIPTION_DURATION;

        vm.expectEmit(true, false, false, true);

        emit VaultStreamV1.Subscribed(USER1, expectedExpiry);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();
    }

    function test_SubscribeIncreasesTotalDeposited() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(vaultStream.totalDeposited(), SUBSCRIPTION_PRICE);
    }

    function test_SubscribeIncreasesContractBalance() public {
        uint256 balanceBefore = address(vaultStream).balance;

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(address(vaultStream).balance, balanceBefore + SUBSCRIPTION_PRICE);
    }

    function test_SubscribeRevertsWithLessPayment() public {
        uint256 sent = 0.005 ether;

        vm.prank(USER1);

        vm.expectRevert(
            abi.encodeWithSelector(VaultStreamV1.VaultStream__IncorrectPayment.selector, sent, SUBSCRIPTION_PRICE)
        );

        vaultStream.subscribe{value: sent}();
    }

    function test_SubscribeRevertsWithZeroPayment() public {
        vm.prank(USER1);

        vm.expectRevert(
            abi.encodeWithSelector(VaultStreamV1.VaultStream__IncorrectPayment.selector, 0, SUBSCRIPTION_PRICE)
        );

        vaultStream.subscribe();
    }

    function test_SubscribeRevertsWithMorePayment() public {
        uint256 sent = 0.02 ether;

        vm.prank(USER1);

        vm.expectRevert(
            abi.encodeWithSelector(VaultStreamV1.VaultStream__IncorrectPayment.selector, sent, SUBSCRIPTION_PRICE)
        );

        vaultStream.subscribe{value: sent}();
    }

    function test_IncorrectPaymentDoesNotChangeState() public {
        uint256 sent = 0.005 ether;

        vm.prank(USER1);

        vm.expectRevert(
            abi.encodeWithSelector(VaultStreamV1.VaultStream__IncorrectPayment.selector, sent, SUBSCRIPTION_PRICE)
        );

        vaultStream.subscribe{value: sent}();

        assertEq(vaultStream.subscriptionExpiry(USER1), 0);

        assertEq(vaultStream.totalDeposited(), 0);

        assertEq(address(vaultStream).balance, 0);
    }

    function test_SubscribeRenewsActiveSubscription() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 firstExpiry = vaultStream.subscriptionExpiry(USER1);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(vaultStream.subscriptionExpiry(USER1), firstExpiry + SUBSCRIPTION_DURATION);
    }

    function test_RenewalEmitsRenewedEvent() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 newExpiry = vaultStream.subscriptionExpiry(USER1) + SUBSCRIPTION_DURATION;

        vm.expectEmit(true, false, false, true);

        emit VaultStreamV1.Renewed(USER1, newExpiry);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();
    }

    function test_RenewalIncreasesTotalDeposited() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(vaultStream.totalDeposited(), SUBSCRIPTION_PRICE * 2);
    }

    function test_RenewalIncreasesContractBalance() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(address(vaultStream).balance, SUBSCRIPTION_PRICE * 2);
    }

    function test_RenewalPreservesOriginalExpiryPlusDuration() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 originalExpiry = vaultStream.subscriptionExpiry(USER1);

        vm.warp(block.timestamp + 10 days);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(vaultStream.subscriptionExpiry(USER1), originalExpiry + SUBSCRIPTION_DURATION);
    }

    function test_IsActiveReturnsFalseForUnsubscribedUser() public {
        assertFalse(vaultStream.isActive(USER1));
    }

    function test_IsActiveReturnsTrueForSubscribedUser() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertTrue(vaultStream.isActive(USER1));
    }

    function test_IsActiveReturnsTrueBeforeExpiry() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + SUBSCRIPTION_DURATION - 1);

        assertTrue(vaultStream.isActive(USER1));
    }

    function test_IsActiveReturnsFalseAtExpiry() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 expiry = vaultStream.subscriptionExpiry(USER1);

        vm.warp(expiry);

        assertFalse(vaultStream.isActive(USER1));
    }

    function test_IsActiveReturnsFalseAfterExpiry() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 expiry = vaultStream.subscriptionExpiry(USER1);

        vm.warp(expiry + 1);

        assertFalse(vaultStream.isActive(USER1));
    }

    function test_MultipleUsersCanSubscribe() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.prank(USER2);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertTrue(vaultStream.isActive(USER1));
        assertTrue(vaultStream.isActive(USER2));

        assertEq(vaultStream.totalDeposited(), SUBSCRIPTION_PRICE * 2);
    }

    function test_UserSubscriptionsAreIndependent() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + 10 days);

        vm.prank(USER2);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 user1Expiry = vaultStream.subscriptionExpiry(USER1);

        uint256 user2Expiry = vaultStream.subscriptionExpiry(USER2);

        assertEq(user2Expiry, block.timestamp + SUBSCRIPTION_DURATION);

        assertEq(user1Expiry, block.timestamp - 10 days + SUBSCRIPTION_DURATION);
    }

    function test_OneUsersRenewalDoesNotChangeAnotherUsersExpiry() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.prank(USER2);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 user2Expiry = vaultStream.subscriptionExpiry(USER2);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        assertEq(vaultStream.subscriptionExpiry(USER2), user2Expiry);
    }

    function test_OwnerIsSetCorrectly() public {
        assertEq(vaultStream.owner(), OWNER);
    }

    function test_NonOwnerCannotUpgrade() public {
        VaultStreamV1 newImplementation = new VaultStreamV1();

        vm.prank(USER1);

        vm.expectRevert();

        vaultStream.upgradeToAndCall(address(newImplementation), "");
    }
}
