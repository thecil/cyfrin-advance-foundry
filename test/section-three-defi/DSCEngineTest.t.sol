// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/section-three-defi/DeployDSCEngine.s.sol";
import {DecentralizedStableCoin} from "../../src/section-three-defi/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/section-three-defi/DSCEngine.sol";
import {HelperConfig} from "../../script/section-three-defi/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDSCEngine deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    HelperConfig public config;
    address weth;
    address ethUsdPriceFeed;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() public {
        deployer = new DeployDSCEngine();
        (dsc, dscEngine, config) = deployer.run();
        (ethUsdPriceFeed, , weth, , ) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
    }

    //////////////////////
    // Price Feed Tests //
    //////////////////////
    function testGetUsdValue() public view {
        uint256 wethAmount = 15 ether;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = dscEngine.getUsdValue(weth, wethAmount);
        assertEq(
            actualUsdValue,
            expectedUsdValue,
            "The USD value is incorrect"
        );
    }

    ///////////////////////////////
    // Deposit Collateral Tests //
    /////////////////////////////
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
