// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title DSCEngine
 * @author thecil
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg.
 * This stablecoin has the properties:
 * - Exogenous Collateral
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no feed, and was only backed by WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the backed value of all the DSC.
 *
 * @notice This contract is the core of the DSC System. It handles all the logic for mining
 * and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system.
 *
 */
contract DSCEngine is ReentrancyGuard {
    ////////////////////
    //    Errors     //
    ///////////////////
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__NotAllowedCollateral();
    error DSCEngine__CollateralTokensAddressesAndPriceFeedsMustMatchLength();
    error DSCEngine__TransferFailed();
    //////////////////////////
    //   State Variables   //
    /////////////////////////
    mapping(address token => address priceFeed) public s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount))
        public s_collateralDeposited; // userToCollateralDeposited
    mapping(address user => uint256 amount) public s_dscMinted; // userToDscMinted

    DecentralizedStableCoin public immutable i_dsc; // DSC token address

    ////////////////////
    //    Events     //
    ///////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );
    event DscMinted(address indexed user, uint256 amount);

    ////////////////////
    //   Modifiers   //
    ///////////////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) revert DSCEngine__MustBeMoreThanZero();
        _;
    }

    modifier isAllowedToken(address _token) {
        if (s_priceFeeds[_token] == address(0))
            revert DSCEngine__NotAllowedToken();
        _;
    }
    ////////////////////
    //   Functions   //
    ///////////////////

    constructor(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds,
        address dscAddress
    ) {
        if (_collateralTokens.length != _priceFeeds.length)
            revert DSCEngine__CollateralTokensAddressesAndPriceFeedsMustMatchLength();
        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            s_priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /////////////////////////////
    //   External Functions   //
    ///////////////////////////

    /**
     * @notice This function allows a user to deposit collateral into the system.
     * @param _collateralToken The address of the collateral token to deposit.
     * @param _collateralAmount The amount of collateral to deposit.
     */
    function depositCollateral(
        address _collateralToken,
        uint256 _collateralAmount
    )
        external
        moreThanZero(_collateralAmount)
        isAllowedToken(_collateralToken)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            _collateralToken
        ] += _collateralAmount;
        emit CollateralDeposited(
            msg.sender,
            _collateralToken,
            _collateralAmount
        );
        bool success = IERC20(_collateralToken).transferFrom(
            msg.sender,
            address(this),
            _collateralAmount
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function depositCollateralAndMintDsc(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmount
    ) external {
        // 1. Transfer the collateral token from the user to this contract
        // 2. Mint the DSC token to the user
        // 3. Update the collateral and DSC balances for the user
    }

    function redeemCollateral(
        address _collateralToken,
        uint256 _collateralAmount
    ) external moreThanZero(_collateralAmount) {
        // 1. Transfer the collateral token from this contract to the user
        // 2. Update the collateral balance for the user
    }
    function mintDsc(address _collateralToken, uint256 _dscAmount) external {
        // 1. Mint the DSC token to the user
        // 2. Update the DSC balance for the user
    }

    function redeemCollateralForDsc(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmount
    ) external {
        // 1. Transfer the DSC token from the user to this contract
        // 2. Burn the DSC token
        // 3. Transfer the collateral token from this contract to the user
        // 4. Update the collateral and DSC balances for the user
    }

    function burnDsc(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmount
    ) external {
        // 1. Transfer the DSC token from the user to this contract
        // 2. Burn the DSC token
        // 3. Update the collateral and DSC balances for the user
    }

    function liquidate(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmount
    ) external {
        // 1. Transfer the collateral token from the user to this contract
        // 2. Burn the DSC token
        // 3. Update the collateral and DSC balances for the user
    }

    function getHealthFactor() external view returns (uint256) {}
}
