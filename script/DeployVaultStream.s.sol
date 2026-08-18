// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "lib/forge-std/src/Script.sol";
import {VaultStreamV1} from "src/VaultStreamV1.sol";
import {ERC1967Proxy} from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployVaultStream is Script {
    function run() external returns (address) {
        return deployVaultStream();
    }

    function deployVaultStream() public returns (address) {
        vm.startBroadcast();
        VaultStreamV1 implementation = new VaultStreamV1();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(implementation), abi.encodeCall(VaultStreamV1.initialize, (0.01 ether, 30 days)));
        vm.stopBroadcast();
        return address(proxy);
    }
}
