// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/sec-three-defi/DeployDSCEngine.s.sol";
import {DecentralizedStableCoin} from "../../src/sec-three-defi/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/sec-three-defi/DSCEngine.sol";
import {HelperConfig} from "../../script/sec-three-defi/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/local/src/data-feeds/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSCEngine deployer;
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    HelperConfig public config;
    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address wbtcUsdPriceFeed;

    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant AMOUNT_MINT_DSC = 1000e18;
    uint256 public constant AMOUNT_BURN_DSC = 500e18;

    function setUp() public {
        deployer = new DeployDSCEngine();
        (dsc, dscEngine, config) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        ERC20Mock(weth).mint(LIQUIDATOR, AMOUNT_COLLATERAL);
    }

    ////////////////////////
    // Constructor Tests //
    ///////////////////////

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesNotMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__CollateralTokensAddressesAndPriceFeedsMustMatchLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }
    //////////////////
    // Price Tests //
    /////////////////

    function testGetUsdValue() public view {
        uint256 wethAmount = 15 ether;
        uint256 expectedUsdValue = 30000e18;
        uint256 actualUsdValue = dscEngine.getUsdValue(weth, wethAmount);
        assertEq(actualUsdValue, expectedUsdValue, "The USD value is incorrect");
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(actualWeth, expectedWeth, "The WETH amount is incorrect");
    }

    ///////////////////////////////
    // Deposit Collateral Tests //
    //////////////////////////////

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        ranToken.mint(USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dscEngine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted, "The total DSC minted is incorrect");
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount, "The collateral value in USD is incorrect");
    }

    ///////////////////////////////
    // Redeem Collateral Tests //
    //////////////////////////////

    function testRevertsIfRedeemMoreThanCollateral() public depositedCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NotEnoughCollateral.selector);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL + 1);
        vm.stopPrank();
    }

    function testRevertsIfRedeemZero() public depositedCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceBeforeRedeem, AMOUNT_COLLATERAL);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        uint256 userBalanceAfterRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }

    /////////////////////
    // Mint DSC Tests //
    ////////////////////

    modifier mintedDsc() {
        vm.startPrank(USER);
        dscEngine.mintDsc(AMOUNT_MINT_DSC);
        vm.stopPrank();
        _;
    }

    function testRevertsIfMintMoreThanCollateral() public depositedCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeMint = dsc.balanceOf(USER);
        assertEq(userBalanceBeforeMint, 0);
        vm.expectPartialRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        dscEngine.mintDsc(100000e18);
        vm.stopPrank();
    }

    function testRevertsIfMintZero() public depositedCollateral {
        vm.startPrank(USER);
        uint256 userBalanceBeforeMint = dsc.balanceOf(USER);
        assertEq(userBalanceBeforeMint, 0);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsAfterMintingIfRedeemHealthFactorTooLow() public depositedCollateral mintedDsc {
        vm.startPrank(USER);
        vm.expectPartialRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        dscEngine.redeemCollateral(weth, 9.9 ether);
        vm.stopPrank();
    }

    function testRevertsIfMintingWithoutCollateral() public {
        vm.startPrank(USER);
        vm.expectPartialRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        dscEngine.mintDsc(AMOUNT_MINT_DSC);
        vm.stopPrank();
    }

    function testCanMintDSC() public depositedCollateral mintedDsc {
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_MINT_DSC, "The DSC balance is incorrect");
    }

    function testCanMintAndRedeemCollateral() public depositedCollateral mintedDsc {
        vm.startPrank(USER);
        uint256 userBalance = dsc.balanceOf(USER);
        assertEq(userBalance, AMOUNT_MINT_DSC, "The DSC balance is incorrect");
        dscEngine.redeemCollateral(weth, 5 ether);
        uint256 userBalanceAfterRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userBalanceAfterRedeem, 5 ether, "The collateral value after redeeming is incorrect");
        vm.stopPrank();
    }

    /////////////////////
    // Burn DSC Tests //
    ////////////////////

    modifier burnDsc() {
        vm.startPrank(USER);
        dsc.approve(address(dscEngine), AMOUNT_BURN_DSC);
        dscEngine.burnDsc(AMOUNT_BURN_DSC);
        vm.stopPrank();
        _;
    }

    function testRevertsIfBurnMoreThanBalance() public depositedCollateral mintedDsc {
        vm.startPrank(USER);
        uint256 userBalanceBeforeBurn = dsc.balanceOf(USER);
        assertEq(userBalanceBeforeBurn, AMOUNT_MINT_DSC, "The DSC balance is incorrect");
        dsc.approve(address(dscEngine), AMOUNT_BURN_DSC);
        vm.expectRevert(DSCEngine.DSCEngine__NotEnoughDscToBurn.selector);
        dscEngine.burnDsc(AMOUNT_MINT_DSC + 1);
        vm.stopPrank();
    }

    function testRevertsIfBurnZero() public depositedCollateral mintedDsc {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dscEngine.burnDsc(0);
        vm.stopPrank();
    }

    function testCanBurnDSC() public depositedCollateral mintedDsc burnDsc {
        uint256 userBalanceAfterBurn = dsc.balanceOf(USER);
        assertEq(userBalanceAfterBurn, AMOUNT_BURN_DSC, "The DSC balance should be zero after burning");
    }

    function testCanRedeemCollateralForDsc() public depositedCollateral mintedDsc {
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, 5 ether);
        dsc.approve(address(dscEngine), AMOUNT_MINT_DSC);
        dscEngine.redeemCollateralForDsc(weth, 5 ether, AMOUNT_MINT_DSC);
        uint256 userCollateralBalanceAfterRedeem = dscEngine.getCollateralBalanceOfUser(USER, weth);
        assertEq(userCollateralBalanceAfterRedeem, 0, "The collateral value after redeeming is incorrect");
        uint256 userBalanceAfterRedeem = dsc.balanceOf(USER);
        assertEq(userBalanceAfterRedeem, 0, "The DSC balance after redeeming is incorrect");
        vm.stopPrank();
    }

    //////////////////////////
    // Liquidate DSC Tests //
    /////////////////////////

    modifier liquidatorSetUp() {
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(address(weth), AMOUNT_COLLATERAL);
        dscEngine.mintDsc(AMOUNT_MINT_DSC);
        dsc.approve(address(dscEngine), AMOUNT_MINT_DSC);
        vm.stopPrank();
        _;
    }

    function testRevertsIfLiquidateWithNoDebt() public depositedCollateral {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dscEngine.liquidate(weth, USER, AMOUNT_MINT_DSC);
        vm.stopPrank();
    }

    function testRevertsIfLiquidateHealthFactorOk() public depositedCollateral mintedDsc {
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dscEngine.liquidate(weth, USER, AMOUNT_MINT_DSC);
        vm.stopPrank();
    }

    function testCanLiquidate() public depositedCollateral mintedDsc liquidatorSetUp {
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, 9 ether);
        vm.stopPrank();
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(1500e8);
        vm.startPrank(LIQUIDATOR);
        uint256 dscBalanceBeforeLiquidate = dsc.balanceOf(LIQUIDATOR);
        assertEq(dscBalanceBeforeLiquidate, AMOUNT_MINT_DSC, "The DSC balance is incorrect");
        dscEngine.liquidate(weth, USER, AMOUNT_MINT_DSC);
        uint256 dscBalanceAfterLiquidate = dsc.balanceOf(LIQUIDATOR);
        assertEq(dscBalanceAfterLiquidate, 0, "The DSC balance after liquidating is incorrect");
        vm.stopPrank();
    }
}
