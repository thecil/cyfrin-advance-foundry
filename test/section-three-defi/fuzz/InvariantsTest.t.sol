// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {DeployDSCEngine} from "../../../script/section-three-defi/DeployDSCEngine.s.sol";
import {DSCEngine} from "../../../src/section-three-defi/DSCEngine.sol";

import {DecentralizedStableCoin} from "../../../src/section-three-defi/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../../script/section-three-defi/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDSCEngine deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    HelperConfig public config;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDSCEngine();
        (dsc, dscEngine, config) = deployer.run();
        (, , weth, wbtc, ) = config.activeNetworkConfig();
        targetContract(address(dscEngine));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply()
        external
        view
    {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
        uint256 wethValueInUsd = dscEngine.getUsdValue(
            weth,
            totalWethDeposited
        );
        uint256 wbtcValueInUsd = dscEngine.getUsdValue(
            wbtc,
            totalWbtcDeposited
        );
        assertGe(
            wethValueInUsd + wbtcValueInUsd,
            totalSupply,
            "Total supply is more than the value of the collateral"
        );
    }
}
