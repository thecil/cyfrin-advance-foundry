// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BasicNft} from "../../src/sec-two-erc721/BasicNft.sol";

contract DeployBasicNft is Script {
    uint256 constant INITIAL_SUPPLY = 100 ether;

    function run() external returns (BasicNft) {
        vm.startBroadcast();
        BasicNft nft = new BasicNft("BasicNft-LilPudgys", "BNFT-LP");
        vm.stopBroadcast();
        return nft;
    }
}
