// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/local/src/data-feeds/interfaces/AggregatorV3Interface.sol";

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
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    mapping(address token => address priceFeed) private s_priceFeeds; // tokenToPriceFeed
    mapping(address user => mapping(address token => uint256 amount))
        private s_collateralDeposited; // userToCollateralDeposited
    mapping(address user => uint256 amount) private s_dscMinted; // userToDscMinted
    address[] private s_collateralTokens; // collateralTokens

    DecentralizedStableCoin private immutable i_dsc; // DSC token address

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
            s_collateralTokens.push(_collateralTokens[i]);
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

    /**
     * @notice This function allows a user to mint DSC tokens if collateral is deposited.
     * @param _dscAmount The amount of DSC tokens to mint.
     */
    function mintDsc(
        uint256 _dscAmount
    ) external moreThanZero(_dscAmount) nonReentrant {
        s_dscMinted[msg.sender] += _dscAmount;
        emit DscMinted(msg.sender, _dscAmount);
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

    ////////////////////////////////////////////
    //   Private & Internal View Functions   //
    //////////////////////////////////////////

    function _getAccountInformation(
        address _user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        collateralValueInUsd = getAccountCollateralValueInUsd(_user);
        totalDscMinted = s_dscMinted[_user];
    }
    /**
     * @notice This function calculates the health factor for a user.
     * @param _user The address of the user to calculate the health factor for.
     */
    function _healthFactor(address _user) internal view returns (uint256) {
        // 1. Get the collateral value in USD
        // 2. Get the DSC value in USD
        // 3. Calculate the health factor
    }
    function revertIfHealthFactorIsTooLow(
        address _user,
        uint256 _collateralAmount,
        uint256 _dscAmount
    ) internal view {
        // 1. Get the health factor for the user
        // 2. Revert if the health factor is too low
    }

    ///////////////////////////////////////////
    //   Public & External View Functions   //
    /////////////////////////////////////////

    function getAccountCollateralValueInUsd(
        address _user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        uint256 length = s_collateralTokens.length;

        for (uint256 i = 0; i < length; i++) {
            address collateralToken = s_collateralTokens[i];
            uint256 collateralAmount = s_collateralDeposited[_user][
                collateralToken
            ];
            totalCollateralValueInUsd += getUsdValue(
                collateralToken,
                collateralAmount
            );
        }
    }

    function getUsdValue(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) /
            PRECISION;
    }
}
