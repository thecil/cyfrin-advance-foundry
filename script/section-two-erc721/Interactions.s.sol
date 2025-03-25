// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BasicNft} from "../../src/section-two-erc721/BasicNft.sol";
import {DevOpsTools} from "../../lib/foundry-devops/src/DevOpsTools.sol";

contract MintBasicNft is Script {
    uint256 constant INITIAL_SUPPLY = 100 ether;

    function run() external {
        address _mostRecentDeployment = DevOpsTools.get_most_recent_deployment(
            "BasicNft",
            block.chainid
        );
        mintNftOnContract(_mostRecentDeployment);
    }

    function mintNftOnContract(address _contractAddress) public {
        vm.startBroadcast();
        BasicNft(_contractAddress).mintNft();
        vm.stopBroadcast();
    }
}
