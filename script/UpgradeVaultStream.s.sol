// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {VaultStreamV1} from "../src/VaultStreamV1.sol";
import {VaultStreamV2} from "../src/VaultStreamV2.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract UpgradeVaultStream is Script {
    // function run() external returns (address) {
    //     address proxyAddress =
    //         DevOpsTools.get_most_recent_deployment(
    //             "ERC1967Proxy",
    //             block.chainid
    //         );

    //     vm.startBroadcast();

    //     VaultStreamV2 newImplementation = new VaultStreamV2();

    //     vm.stopBroadcast();

    //     return upgradeVaultStream(
    //         proxyAddress,
    //         address(newImplementation)
    //     );
    // }

    function run() external returns (address) {
        address proxyAddress = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

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
