// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {VaultStreamV1} from "../src/VaultStreamV1.sol";
import {VaultStreamV2} from "../src/VaultStreamV2.sol";

contract UpgradeVaultStream is Script {
    function run() external returns (address) {
        address proxyAddress = 0xe87F945f263B3fD5F78dd12C0c20ae6A401f0322;

        vm.startBroadcast();

        VaultStreamV2 newImplementation = new VaultStreamV2();

        vm.stopBroadcast();

        return upgradeVaultStream(proxyAddress, address(newImplementation));
    }

    function upgradeVaultStream(address proxyAddress, address newImplementation) public returns (address) {
        vm.startBroadcast();

        VaultStreamV1 proxy = VaultStreamV1(payable(proxyAddress));

        proxy.upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();

        return address(proxy);
    }
}
