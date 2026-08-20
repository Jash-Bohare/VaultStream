// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV1} from "../../src/VaultStreamV1.sol";
import {DeployVaultStream} from "../../script/DeployVaultStream.s.sol";

contract VaultStreamFuzz is Test {
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

    function testFuzz_SubscribeThenIsActive(uint256 duration) public {
        duration = bound(duration, 1, 365 days);
        vm.warp(block.timestamp);

        vm.prank(USER1);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();

        uint256 expiry = vaultStream.subscriptionExpiry(USER1);

        assertEq(expiry, block.timestamp + SUBSCRIPTION_DURATION);

        // Move forward by the fuzzed duration.
        vm.warp(block.timestamp + duration);

        if (duration < SUBSCRIPTION_DURATION) {
            assertTrue(vaultStream.isActive(USER1));
        } else {
            assertFalse(vaultStream.isActive(USER1));
        }
    }
}
