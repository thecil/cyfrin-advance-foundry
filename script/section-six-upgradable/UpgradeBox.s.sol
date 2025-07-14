// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {BoxV2} from "../../src/section-six-upgradable/BoxV2.sol";
import {BoxV1} from "../../src/section-six-upgradable/BoxV1.sol";

contract UpgradeBox is Script {
    function run() external returns (address) {
        address mostRecentDeployedProxy = DevOpsTools
            .get_most_recent_deployment("ERC1967Proxy", block.chainid);
        vm.startBroadcast();
        BoxV2 newBox = new BoxV2();
        vm.stopBroadcast();
        address proxy = upgradeBox(mostRecentDeployedProxy, address(newBox)); // proxy contract now points to this new address
        return proxy;
    }

    function upgradeBox(
        address oldProxy,
        address newImplementation
    ) public returns (address) {
        vm.startBroadcast();
        BoxV1 proxy = BoxV1(payable(oldProxy));
        proxy.upgradeToAndCall(newImplementation, "");
        vm.stopBroadcast();
        return address(proxy);
    }
}
