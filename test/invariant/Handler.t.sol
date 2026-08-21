// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV2} from "../../src/VaultStreamV2.sol";

contract Handler is Test {
    VaultStreamV2 public vaultStream;

    address[] public users;
    uint256 public constant SUBSCRIPTION_PRICE = 0.01 ether;

    constructor(VaultStreamV2 _vaultStream) {
        vaultStream = _vaultStream;

        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));

        for (uint256 i = 0; i < users.length; i++) {
            vm.deal(users[i], 100 ether);
        }
    }

    function subscribe(uint256 userSeed) public {
        address user = users[userSeed % users.length];
        vm.prank(user);
        vaultStream.subscribe{value: SUBSCRIPTION_PRICE}();
    }

    function cancelSubscription(uint256 userSeed) public {
        address user = users[userSeed % users.length];
        if (vaultStream.isActive(user)) {
            vm.prank(user);
            vaultStream.cancelSubscription();
        }
    }

    function withdraw(uint256 userSeed) public {
        address user = users[userSeed % users.length];
        if (vaultStream.withdrawableBalance(user) > 0) {
            vm.prank(user);
            vaultStream.withdraw();
        }
    }

    function warpTime(uint256 secondsToWarp) public {
        secondsToWarp = bound(secondsToWarp, 1 seconds, 30 days);
        vm.warp(block.timestamp + secondsToWarp);
    }

    function getUsers() external view returns (address[] memory) {
        return users;
    }
}
