// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test, console} from "forge-std/Test.sol";

import {DSCEngine} from "../../../src/section-three-defi/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../../src/section-three-defi/DecentralizedStableCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    DecentralizedStableCoin public dsc;
    DSCEngine public dscEngine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;
    uint256 public timesMintIsCalled;
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory _collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(_collateralTokens[0]);
        wbtc = ERC20Mock(_collateralTokens[1]);
    }

    function depositCollateral(
        uint256 _collateralSeed,
        uint256 _amountCollateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(_collateralSeed);
        _amountCollateral = bound(_amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, _amountCollateral);
        collateral.approve(address(dscEngine), _amountCollateral);
        dscEngine.depositCollateral(address(collateral), _amountCollateral);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(
        uint256 _collateralSeed,
        uint256 _amountCollateral
    ) public {
        ERC20Mock _collateral = _getCollateralFromSeed(_collateralSeed);
        uint256 maxCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(
            msg.sender,
            address(_collateral)
        );
        _amountCollateral = bound(_amountCollateral, 0, maxCollateralToRedeem);
        if (_amountCollateral == 0) return;
        dscEngine.redeemCollateral(address(_collateral), _amountCollateral);
    }

    function mintDsc(uint256 _amountToMint, uint256 _addressSeed) public {
        if(usersWithCollateralDeposited.length == 0) return;
        address sender = usersWithCollateralDeposited[
            _addressSeed % usersWithCollateralDeposited.length
        ];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine
            .getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) -
            int256(totalDscMinted);
        if (maxDscToMint < 0) return;
        _amountToMint = bound(_amountToMint, 0, uint256(maxDscToMint));
        if (_amountToMint == 0) return;
        vm.startPrank(sender);
        dscEngine.mintDsc(_amountToMint);
        vm.stopPrank();
        timesMintIsCalled++;
    }

    ////////////////////////
    // Helper Functions  //
    //////////////////////

    function _getCollateralFromSeed(
        uint256 _collateralSeed
    ) private view returns (ERC20Mock) {
        if (_collateralSeed % 2 == 0) return weth;
        return wbtc;
    }
}
