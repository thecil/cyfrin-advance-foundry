// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BasicNft} from "../../src/sec-two-erc721/BasicNft.sol";
import {DeployBasicNft} from "../../script/sec-two-erc721/DeployBasicNft.s.sol";

contract BasicNftTest is Test {
    BasicNft public nft_contract;
    DeployBasicNft public deployer;

    string constant name = "BasicNft-LilPudgys";
    string constant symbol = "BNFT-LP";
    string private constant TOKEN_URI =
        "https://api.pudgypenguins.io/lil/image/";

    function setUp() public {
        deployer = new DeployBasicNft();
        nft_contract = deployer.run();
    }

    function testDeployParams() public view {
        assertEq(nft_contract.name(), name);
        assertEq(nft_contract.symbol(), symbol);
    }

    function testMintNft() public {
        vm.startPrank(msg.sender);
        nft_contract.mintNft();
        vm.stopPrank();
        assertEq(nft_contract.balanceOf(msg.sender), 1);
    }

    function testTokenUri() public {
        vm.startPrank(msg.sender);
        nft_contract.mintNft();
        vm.stopPrank();
        string memory expectedUri = string(abi.encodePacked(TOKEN_URI, "1"));
        assertEq(nft_contract.tokenURI(1), expectedUri);
    }
}
