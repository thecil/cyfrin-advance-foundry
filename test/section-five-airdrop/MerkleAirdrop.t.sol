// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {BagelToken} from "../../src/section-five-airdrop/BagelToken.sol";
import {MerkleAirdrop} from "../../src/section-five-airdrop/MerkleAirdrop.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdropScript} from "../../script/section-five-airdrop/DeployMerkleAirdrop.s.sol";

contract MerkleAirdropTest is ZkSyncChainChecker, Test {
    BagelToken public token;
    MerkleAirdrop public airdrop;

    uint256 public AMOUNT = 25 * 1e18;
    uint256 AMOUNT_TO_SEND = AMOUNT * 4;
    bytes32 public ROOT =
        0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    bytes32 proofOne =
        0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proofTwo =
        0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [proofOne, proofTwo];
    address user;
    uint256 userPrivKey;

    function setUp() public {
        if (!isZkSyncChain()) {
            DeployMerkleAirdropScript deployer = new DeployMerkleAirdropScript();
            (airdrop, token) = deployer.deployMerkleAirdrop();
        } else {
            token = new BagelToken();
            airdrop = new MerkleAirdrop(ROOT, IERC20(address(token)));
            token.mint(address(airdrop), AMOUNT_TO_SEND);
        }
        (user, userPrivKey) = makeAddrAndKey("user");
    }

    function test_usersCanClaim() public {
        uint256 startingBalance = token.balanceOf(user);
        vm.startPrank(user);
        airdrop.claim(user, AMOUNT, PROOF);
        vm.stopPrank();
        uint256 afterBalance = token.balanceOf(user);
        assertEq(afterBalance - startingBalance, AMOUNT);
    }
}
