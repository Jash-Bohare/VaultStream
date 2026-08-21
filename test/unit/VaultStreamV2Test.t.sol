// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV2} from "../../src/VaultStreamV2.sol";
import {VaultStreamV1} from "../../src/VaultStreamV1.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RejectETH {
    // Contract that rejects receiving ETH

    }

contract VaultStreamV2Test is Test {
    VaultStreamV2 public vaultStream;

    address public OWNER = makeAddr("owner");
    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");
    address public FEE_RECIPIENT = makeAddr("feeRecipient");

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant SUBSCRIPTION_PRICE = 0.01 ether;
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;

    function setUp() public {
        vm.startPrank(OWNER);
        VaultStreamV1 implV1 = new VaultStreamV1();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implV1), abi.encodeCall(VaultStreamV1.initialize, (SUBSCRIPTION_PRICE, SUBSCRIPTION_DURATION))
        );
        VaultStreamV2 implV2 = new VaultStreamV2();
        VaultStreamV1(payable(address(proxy))).upgradeToAndCall(address(implV2), "");
        vaultStream = VaultStreamV2(payable(address(proxy)));
        vm.stopPrank();

        vm.deal(OWNER, STARTING_BALANCE);
        vm.deal(USER1, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    /* SetFeeRecipient Tests */

    function test_SetFeeRecipient_Success() public {
        vm.prank(OWNER);
        vaultStream.setFeeRecipient(FEE_RECIPIENT);

        assertEq(vaultStream.feeRecipient(), FEE_RECIPIENT);
    }

    function test_SetFeeRecipient_RevertsIfNonOwner() public {
        vm.prank(USER1);
        vm.expectRevert();
        vaultStream.setFeeRecipient(FEE_RECIPIENT);
    }

    function test_SetFeeRecipient_RevertsIfZeroAddress() public {
        vm.prank(OWNER);
        vm.expectRevert(VaultStreamV2.VaultStream__ZeroAddress.selector);
        vaultStream.setFeeRecipient(address(0));
    }

    /* SetFeeBps Tests */

    function test_SetFeeBps_Success() public {
        vm.prank(OWNER);
        vaultStream.setFeeBps(1000); // 10%

        assertEq(vaultStream.feeBps(), 1000);
    }

    function test_SetFeeBps_SuccessMaxFee() public {
        vm.prank(OWNER);
        vaultStream.setFeeBps(2000); // 20% (max fee)

        assertEq(vaultStream.feeBps(), 2000);
    }

    function test_SetFeeBps_RevertsIfExceedsMaxFeeBps() public {
        uint16 invalidFeeBps = 2001;

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(VaultStreamV2.VaultStream__ExceedsMaxFeeBps.selector, invalidFeeBps));
        vaultStream.setFeeBps(invalidFeeBps);
    }

    function test_SetFeeBps_RevertsIfNonOwner() public {
        vm.prank(USER1);
        vm.expectRevert();
        vaultStream.setFeeBps(500);
    }

    /* CancelSubscription Tests */

    function test_CancelSubscription_RevertsIfNoSubscription() public {
        vm.prank(USER1);
        vm.expectRevert(VaultStreamV2.VaultStream__NoActiveSubscription.selector);
        vaultStream.cancelSubscription();
    }

    function test_CancelSubscription_RevertsIfSubscriptionExpired() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + SUBSCRIPTION_DURATION + 1);

        vm.prank(USER1);
        vm.expectRevert(VaultStreamV2.VaultStream__NoActiveSubscription.selector);
        vaultStream.cancelSubscription();
    }

    function test_CancelSubscription_RevertsIfSubscriptionAtExactExpiry() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 expiry = vaultStream.subscriptionExpiry(USER1);
        vm.warp(expiry);

        vm.prank(USER1);
        vm.expectRevert(VaultStreamV2.VaultStream__NoActiveSubscription.selector);
        vaultStream.cancelSubscription();
    }

    function test_CancelSubscription_SuccessZeroFee() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        // Warp 15 days into 30 day subscription (halfway)
        vm.warp(block.timestamp + 15 days);

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        assertEq(vaultStream.subscriptionExpiry(USER1), 0);
        assertFalse(vaultStream.isActive(USER1));

        uint256 expectedRefund = (SUBSCRIPTION_PRICE * 15 days) / SUBSCRIPTION_DURATION;
        assertEq(vaultStream.withdrawableBalance(USER1), expectedRefund);
    }

    function test_CancelSubscription_SuccessWithFee() public {
        vm.startPrank(OWNER);
        vaultStream.setFeeRecipient(FEE_RECIPIENT);
        vaultStream.setFeeBps(1000); // 10% fee
        vm.stopPrank();

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        // Warp 10 days into subscription (20 days remaining)
        vm.warp(block.timestamp + 10 days);

        uint256 feeRecipientBalBefore = FEE_RECIPIENT.balance;

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        uint256 refund = (SUBSCRIPTION_PRICE * 20 days) / SUBSCRIPTION_DURATION;
        uint256 fee = (refund * 1000) / 10_000;
        uint256 userRefund = refund - fee;

        assertEq(vaultStream.subscriptionExpiry(USER1), 0);
        assertEq(vaultStream.withdrawableBalance(USER1), userRefund);
        assertEq(FEE_RECIPIENT.balance, feeRecipientBalBefore + fee);
    }

    function test_CancelSubscription_RevertsIfFeeRecipientRejectsETH() public {
        RejectETH rejector = new RejectETH();

        vm.startPrank(OWNER);
        vaultStream.setFeeRecipient(address(rejector));
        vaultStream.setFeeBps(500); // 5% fee
        vm.stopPrank();

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + 10 days);

        vm.prank(USER1);
        vm.expectRevert();
        vaultStream.cancelSubscription();
    }

    /* Withdraw Tests */

    function test_Withdraw_RevertsIfNothingToWithdraw() public {
        vm.prank(USER1);
        vm.expectRevert(VaultStreamV2.VaultStream__NothingToWithdraw.selector);
        vaultStream.withdraw();
    }

    function test_Withdraw_Success() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + 15 days);

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        uint256 withdrawableAmount = vaultStream.withdrawableBalance(USER1);
        uint256 userBalBefore = USER1.balance;

        vm.prank(USER1);
        vaultStream.withdraw();

        assertEq(vaultStream.withdrawableBalance(USER1), 0);
        assertEq(USER1.balance, userBalBefore + withdrawableAmount);
    }

    function test_Withdraw_CannotBeDoubleWithdrawn() public {
        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + 15 days);

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        // First withdrawal succeeds
        vm.prank(USER1);
        vaultStream.withdraw();

        // Second withdrawal attempt reverts
        vm.prank(USER1);
        vm.expectRevert(VaultStreamV2.VaultStream__NothingToWithdraw.selector);
        vaultStream.withdraw();
    }

    function test_Withdraw_RevertsIfReceiverRejectsETH() public {
        // Create a contract caller that doesn't accept ETH
        RejectETHContract caller = new RejectETHContract(payable(address(vaultStream)));
        vm.deal(address(caller), 10 ether);

        caller.subscribeAndCancel(SUBSCRIPTION_PRICE);

        // Attempting to withdraw should revert because RejectETHContract has no receive function
        vm.expectRevert();
        caller.withdraw();
    }

    function test_Version() public view {
        assertEq(vaultStream.version(), 2);
    }
}

contract RejectETHContract {
    VaultStreamV2 public vaultStream;

    constructor(address payable _vaultStream) {
        vaultStream = VaultStreamV2(_vaultStream);
    }

    function subscribeAndCancel(uint256 price) external {
        vaultStream.subscribe{value: price}();
        vaultStream.cancelSubscription();
    }

    function withdraw() external {
        vaultStream.withdraw();
    }
}
