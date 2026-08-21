// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {VaultStreamV1} from "../../src/VaultStreamV1.sol";
import {VaultStreamV2} from "../../src/VaultStreamV2.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Handler} from "./Handler.t.sol";

contract VaultStreamInvariant is Test {
    VaultStreamV2 public vaultStream;
    Handler public handler;

    address public OWNER = makeAddr("owner");
    address public FEE_RECIPIENT = makeAddr("feeRecipient");

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
        vaultStream.setFeeBps(500); // 5% fee
        vm.stopPrank();

        handler = new Handler(vaultStream);
        targetContract(address(handler));
    }

    function invariant_contractBalanceCoversWithdrawable() public view {
        address[] memory users = handler.getUsers();
        uint256 totalWithdrawable = 0;

        for (uint256 i = 0; i < users.length; i++) {
            totalWithdrawable += vaultStream.withdrawableBalance(users[i]);
        }

        assertGe(address(vaultStream).balance, totalWithdrawable);
    }
}
