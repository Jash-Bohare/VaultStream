// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV2} from "../../src/VaultStreamV2.sol";
import {VaultStreamV1} from "../../src/VaultStreamV1.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultStreamV2Fuzz is Test {
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
            address(implV1),
            abi.encodeCall(VaultStreamV1.initialize, (SUBSCRIPTION_PRICE, SUBSCRIPTION_DURATION))
        );
        VaultStreamV2 implV2 = new VaultStreamV2();
        VaultStreamV1(payable(address(proxy))).upgradeToAndCall(address(implV2), "");
        vaultStream = VaultStreamV2(payable(address(proxy)));

        vaultStream.setFeeRecipient(FEE_RECIPIENT);
        vm.stopPrank();

        vm.deal(OWNER, STARTING_BALANCE);
        vm.deal(USER1, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
    }

    function testFuzz_CancelSubscriptionAccounting(uint256 elapsedTime, uint16 feeBps) public {
        elapsedTime = bound(elapsedTime, 1, SUBSCRIPTION_DURATION - 1);
        feeBps = uint16(bound(feeBps, 0, 2000));

        vm.prank(OWNER);
        vaultStream.setFeeBps(feeBps);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 subTime = block.timestamp;
        vm.warp(subTime + elapsedTime);

        uint256 remainingTime = SUBSCRIPTION_DURATION - elapsedTime;
        uint256 expectedRefund = (SUBSCRIPTION_PRICE * remainingTime) / SUBSCRIPTION_DURATION;
        uint256 expectedFee = (expectedRefund * feeBps) / 10_000;
        uint256 expectedUserRefund = expectedRefund - expectedFee;

        uint256 feeRecipientBalBefore = FEE_RECIPIENT.balance;

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        assertEq(vaultStream.subscriptionExpiry(USER1), 0);
        assertEq(vaultStream.withdrawableBalance(USER1), expectedUserRefund);
        assertEq(FEE_RECIPIENT.balance, feeRecipientBalBefore + expectedFee);
        assertEq(expectedUserRefund + expectedFee, expectedRefund);
    }

    function testFuzz_WithdrawDrainsWithdrawableBalance(uint256 elapsedTime) public {
        elapsedTime = bound(elapsedTime, 1, SUBSCRIPTION_DURATION - 1);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + elapsedTime);

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        uint256 withdrawableAmount = vaultStream.withdrawableBalance(USER1);
        uint256 userBalBefore = USER1.balance;

        vm.prank(USER1);
        vaultStream.withdraw();

        assertEq(vaultStream.withdrawableBalance(USER1), 0);
        assertEq(USER1.balance, userBalBefore + withdrawableAmount);
    }

    function testFuzz_CancelRefundNeverExceedsPaid(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 1, SUBSCRIPTION_DURATION - 1);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.warp(block.timestamp + timeElapsed);

        vm.prank(USER1);
        vaultStream.cancelSubscription();

        uint256 refundAmount = vaultStream.withdrawableBalance(USER1);
        assertLe(refundAmount, SUBSCRIPTION_PRICE);
    }

    function testFuzz_FeeNeverExceedsCap(uint16 fee) public {
        vm.startPrank(OWNER);
        if (fee > 2000) {
            vm.expectRevert(abi.encodeWithSelector(VaultStreamV2.VaultStream__ExceedsMaxFeeBps.selector, fee));
            vaultStream.setFeeBps(fee);
        } else {
            vaultStream.setFeeBps(fee);
            assertEq(vaultStream.feeBps(), fee);
        }
        vm.stopPrank();
    }
}
