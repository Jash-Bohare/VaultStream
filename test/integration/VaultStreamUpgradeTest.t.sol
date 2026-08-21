// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV1} from "../../src/VaultStreamV1.sol";
import {VaultStreamV2} from "../../src/VaultStreamV2.sol";
import {DeployVaultStream} from "../../script/DeployVaultStream.s.sol";
import {UpgradeVaultStream} from "../../script/UpgradeVaultStream.s.sol";

contract VaultStreamUpgradeTest is Test {
    VaultStreamV1 public proxyV1;
    VaultStreamV2 public proxyV2;

    address public OWNER;
    address public USER1 = makeAddr("user1");
    address public USER2 = makeAddr("user2");
    address public USER3 = makeAddr("user3");
    address public FEE_RECIPIENT = makeAddr("feeRecipient");

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant SUBSCRIPTION_PRICE = 0.01 ether;
    uint256 public constant SUBSCRIPTION_DURATION = 30 days;

    function setUp() public {
        DeployVaultStream deployer = new DeployVaultStream();
        address proxyAddress = deployer.run();

        proxyV1 = VaultStreamV1(payable(proxyAddress));
        OWNER = proxyV1.owner();

        vm.deal(OWNER, STARTING_BALANCE);
        vm.deal(USER1, STARTING_BALANCE);
        vm.deal(USER2, STARTING_BALANCE);
        vm.deal(USER3, STARTING_BALANCE);
    }

    function test_UpgradePreservesStateAndEnablesV2Features() public {
        // Step 1: Users subscribe on V1
        vm.prank(USER1);
        proxyV1.subscribe{value: SUBSCRIPTION_PRICE}();

        vm.prank(USER2);
        proxyV1.subscribe{value: SUBSCRIPTION_PRICE}();

        // Capture V1 state
        uint256 priceV1 = proxyV1.subscriptionPrice();
        uint256 durationV1 = proxyV1.subscriptionDuration();
        uint256 totalDepositedV1 = proxyV1.totalDeposited();
        uint256 expiryUser1V1 = proxyV1.subscriptionExpiry(USER1);
        uint256 expiryUser2V1 = proxyV1.subscriptionExpiry(USER2);
        address ownerV1 = proxyV1.owner();

        assertEq(proxyV1.version(), 1);
        assertEq(totalDepositedV1, SUBSCRIPTION_PRICE * 2);

        // Step 2: Upgrade to V2 implementation as OWNER
        VaultStreamV2 newImplementation = new VaultStreamV2();

        vm.prank(OWNER);
        proxyV1.upgradeToAndCall(address(newImplementation), "");

        proxyV2 = VaultStreamV2(payable(address(proxyV1)));

        // Step 3: Verify version and state preservation
        assertEq(proxyV2.version(), 2);
        assertEq(proxyV2.subscriptionPrice(), priceV1);
        assertEq(proxyV2.subscriptionDuration(), durationV1);
        assertEq(proxyV2.totalDeposited(), totalDepositedV1);
        assertEq(proxyV2.subscriptionExpiry(USER1), expiryUser1V1);
        assertEq(proxyV2.subscriptionExpiry(USER2), expiryUser2V1);
        assertEq(proxyV2.owner(), ownerV1);
        assertTrue(proxyV2.isActive(USER1));
        assertTrue(proxyV2.isActive(USER2));

        // Step 4: Configure V2 parameters by owner
        vm.startPrank(OWNER);
        proxyV2.setFeeRecipient(FEE_RECIPIENT);
        proxyV2.setFeeBps(500); // 5%
        vm.stopPrank();

        assertEq(proxyV2.feeRecipient(), FEE_RECIPIENT);
        assertEq(proxyV2.feeBps(), 500);

        // Step 5: V1 subscriber (USER1) cancels subscription in V2 after 10 days
        vm.warp(block.timestamp + 10 days);

        uint256 remainingTime = expiryUser1V1 - block.timestamp;
        uint256 expectedRefund = (SUBSCRIPTION_PRICE * remainingTime) / SUBSCRIPTION_DURATION;
        uint256 expectedFee = (expectedRefund * 500) / 10_000;
        uint256 expectedUserRefund = expectedRefund - expectedFee;

        uint256 feeRecipientBalBefore = FEE_RECIPIENT.balance;

        vm.prank(USER1);
        proxyV2.cancelSubscription();

        assertEq(proxyV2.subscriptionExpiry(USER1), 0);
        assertFalse(proxyV2.isActive(USER1));
        assertEq(proxyV2.withdrawableBalance(USER1), expectedUserRefund);
        assertEq(FEE_RECIPIENT.balance, feeRecipientBalBefore + expectedFee);

        // USER1 withdraws refund
        uint256 user1BalBefore = USER1.balance;
        vm.prank(USER1);
        proxyV2.withdraw();

        assertEq(proxyV2.withdrawableBalance(USER1), 0);
        assertEq(USER1.balance, user1BalBefore + expectedUserRefund);

        // Step 6: USER2's subscription remains intact and active
        assertTrue(proxyV2.isActive(USER2));
        assertEq(proxyV2.subscriptionExpiry(USER2), expiryUser2V1);

        // Step 7: New user (USER3) subscribes on V2, renews, and cancels
        vm.prank(USER3);
        proxyV2.subscribe{value: SUBSCRIPTION_PRICE}();
        assertTrue(proxyV2.isActive(USER3));

        assertEq(proxyV2.totalDeposited(), totalDepositedV1 + SUBSCRIPTION_PRICE);
    }

    function test_UpgradeRevertsForNonOwner() public {
        VaultStreamV2 newImplementation = new VaultStreamV2();

        vm.prank(USER1);
        vm.expectRevert();
        proxyV1.upgradeToAndCall(address(newImplementation), "");
    }

    function test_V2_UpgradeRevertsForNonOwner() public {
        // Upgrade to V2 first
        VaultStreamV2 implV2 = new VaultStreamV2();
        vm.prank(OWNER);
        proxyV1.upgradeToAndCall(address(implV2), "");

        VaultStreamV2 proxyV2Contract = VaultStreamV2(payable(address(proxyV1)));
        VaultStreamV2 implV2_2 = new VaultStreamV2();

        vm.prank(USER1);
        vm.expectRevert();
        proxyV2Contract.upgradeToAndCall(address(implV2_2), "");
    }

    function test_V2_UpgradeSuccessAsOwner() public {
        // Upgrade to V2 first
        VaultStreamV2 implV2 = new VaultStreamV2();
        vm.prank(OWNER);
        proxyV1.upgradeToAndCall(address(implV2), "");

        VaultStreamV2 proxyV2Contract = VaultStreamV2(payable(address(proxyV1)));
        VaultStreamV2 implV2_2 = new VaultStreamV2();

        vm.prank(OWNER);
        proxyV2Contract.upgradeToAndCall(address(implV2_2), "");

        assertEq(proxyV2Contract.version(), 2);
    }
}
