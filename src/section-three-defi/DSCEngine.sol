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
    error DSCEngine__HealthFactorTooLow(uint256 healthFactor);
    error DSCEngine__MintedFailed();
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__NotEnoughCollateral();
    error DSCEngine__NotEnoughDscToBurn();

    //////////////////////////
    //   State Variables   //
    /////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10%

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
    event CollateralRedeemed(
        address indexed from,
        address indexed to,
        address indexed collateralToken,
        uint256 amount
    );
    ////////////////////
    //   Modifiers   //
    ///////////////////
    modifier moreThanZero(uint256 _amount) {
        if (_amount == 0) revert DSCEngine__MustBeMoreThanZero();
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
        public
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
        if (!success) revert DSCEngine__TransferFailed();
    }

    /**
     * @notice This function allows a user to deposit collateral and mint DSC tokens in one transaction.
     * @param _collateralToken The address of the collateral token to deposit.
     * @param _collateralAmount The amount of collateral to deposit.
     * @param _dscAmountToMint The amount of DSC tokens to mint.
     */
    function depositCollateralAndMintDsc(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmountToMint
    ) external {
        depositCollateral(_collateralToken, _collateralAmount);
        mintDsc(_dscAmountToMint);
    }

    /**
     * @notice This function allows a user to redeem collateral from the system.
     * @param _collateralToken The address of the collateral token to redeem.
     * @param _collateralAmount The amount of collateral to redeem.
     * @dev This function will revert if the user's health factor is too low after redeeming the collateral.
     */
    function redeemCollateral(
        address _collateralToken,
        uint256 _collateralAmount
    )
        public
        moreThanZero(_collateralAmount)
        isAllowedToken(_collateralToken)
        nonReentrant
    {
        _redeemCollateral(
            _collateralToken,
            _collateralAmount,
            msg.sender,
            msg.sender
        );
        _revertIfHealthFactorIsTooLow(msg.sender);
    }

    /**
     * @notice This function allows a user to mint DSC tokens if collateral is deposited.
     * @param _dscAmount The amount of DSC tokens to mint.
     */
    function mintDsc(
        uint256 _dscAmount
    ) public moreThanZero(_dscAmount) nonReentrant {
        s_dscMinted[msg.sender] += _dscAmount;
        _revertIfHealthFactorIsTooLow(msg.sender);
        bool minted = i_dsc.mint(msg.sender, _dscAmount);
        if (!minted) {
            revert DSCEngine__MintedFailed();
        }
        emit DscMinted(msg.sender, _dscAmount);
        // 1. Mint the DSC token to the user
        // 2. Update the DSC balance for the user
    }

    /**
     * @notice This function allows a user to redeem collateral for DSC tokens.
     * @param _collateralToken The address of the collateral token to redeem.
     * @param _collateralAmount The amount of collateral to redeem.
     * @param _dscAmountToBurn The amount of DSC tokens to burn.
     * @dev This function will first burn the DSC tokens and then redeem the collateral.
     * @dev This function will revert if the user's health factor is too low after burning the DSC tokens.
     */
    function redeemCollateralForDsc(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmountToBurn
    ) external {
        burnDsc(_dscAmountToBurn);
        redeemCollateral(_collateralToken, _collateralAmount);
        // redeemCollateral already checks the health factor
    }

    /**
     * @notice This function allows a user to burn DSC tokens.
     * @param _dscAmountToBurn The amount of DSC tokens to burn.
     */
    function burnDsc(
        uint256 _dscAmountToBurn
    ) public moreThanZero(_dscAmountToBurn) {
        _burnDsc(_dscAmountToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsTooLow(msg.sender); // i don't think this would ever hit...
    }

    /**
     * @notice This function allows a user to liquidate their position if their health factor is below the minimum threshold.
     * @param _collateralToken The address of the collateral token to redeem.
     * @param _user The address of the user to liquidate.
     * @param _dscDebtToCoverAmount The amount of DSC debt to cover.
     * @dev This function will revert if the user's health factor is above the minimum threshold.
     */
    function liquidate(
        address _collateralToken,
        address _user,
        uint256 _dscDebtToCoverAmount
    ) external moreThanZero(_dscDebtToCoverAmount) nonReentrant {
        uint256 _startingUserHealthFactor = _healthFactor(_user);
        if (_startingUserHealthFactor >= MIN_HEALTH_FACTOR)
            revert DSCEngine__HealthFactorOk();

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            _collateralToken,
            _dscDebtToCoverAmount
        );
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered +
            bonusCollateral;
        _redeemCollateral(
            _collateralToken,
            totalCollateralToRedeem,
            _user,
            msg.sender
        );
        _burnDsc(_dscDebtToCoverAmount, _user, msg.sender);
        uint256 _endingUserHealthFactor = _healthFactor(_user);
        if (_endingUserHealthFactor <= _startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsTooLow(msg.sender);
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }
    ////////////////////////////////////////////
    //   Private & Internal View Functions   //
    //////////////////////////////////////////

    /**
     * @notice This function burns DSC tokens from a user's account.
     * @param _dscAmountToBurn The amount of DSC tokens to burn.
     * @param _onBehalfOf The address of the user on whose behalf the DSC tokens are being burned.
     * @param _dscFrom The address from which the DSC tokens are being burned.
     *
     * @dev Low-level internal function, do not call unless the function calling it is
     * checking for health factors being broken.
     */
    function _burnDsc(
        uint256 _dscAmountToBurn,
        address _onBehalfOf,
        address _dscFrom
    ) private {
        if (s_dscMinted[_onBehalfOf] < _dscAmountToBurn)
            revert DSCEngine__NotEnoughDscToBurn();
        s_dscMinted[_onBehalfOf] -= _dscAmountToBurn;
        bool success = i_dsc.transferFrom(
            _dscFrom,
            address(this),
            _dscAmountToBurn
        );
        if (!success) revert DSCEngine__TransferFailed();
        i_dsc.burn(_dscAmountToBurn);
    }

    /**
     * @notice This function allows a user to redeem collateral from the system.
     * @param _tokenCollateralAddress The address of the collateral token to redeem.
     * @param _amountCollateral The amount of collateral to redeem.
     * @param _from The address of the user redeeming the collateral.
     * @param _to The address to send the redeemed collateral to.
     */
    function _redeemCollateral(
        address _tokenCollateralAddress,
        uint256 _amountCollateral,
        address _from,
        address _to
    ) private {
        if (
            _amountCollateral >
            s_collateralDeposited[_from][_tokenCollateralAddress]
        ) revert DSCEngine__NotEnoughCollateral();
        s_collateralDeposited[_from][
            _tokenCollateralAddress
        ] -= _amountCollateral;
        emit CollateralRedeemed(
            _from,
            _to,
            _tokenCollateralAddress,
            _amountCollateral
        );
        bool success = IERC20(_tokenCollateralAddress).transfer(
            _to,
            _amountCollateral
        );
        if (!success) revert DSCEngine__TransferFailed();
    }

    /**
     * @notice This function retrieves the total DSC minted and the collateral value in USD for a user.
     * @param _user The address of the user to retrieve information for.
     * @return totalDscMinted The total amount of DSC tokens minted by the user.
     * @return collateralValueInUsd The total value of the user's collateral in USD.
     */
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

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) internal pure returns (uint256) {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * @notice This function calculates the health factor for a user.
     * @param _user The address of the user to calculate the health factor for.
     * @return healthFactor The health factor for the user.
     * @dev The health factor is calculated as the collateral value in USD divided by the total DSC minted.
     */
    function _healthFactor(address _user) internal view returns (uint256) {
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(_user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    /**
     * @notice This function checks if the health factor for a user is above the minimum threshold.
     * @param _user The address of the user to check the health factor for.
     * @dev This function will revert if the user's health factor is below the minimum threshold.
     */
    function _revertIfHealthFactorIsTooLow(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorTooLow(userHealthFactor);
        }
    }

    ///////////////////////////////////////////
    //   Public & External View Functions   //
    /////////////////////////////////////////

    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    function getHealthFactor(address _user) public view returns (uint256) {
        return _healthFactor(_user);
    }

    function getCollateralBalanceOfUser(
        address _user,
        address _collateralToken
    ) public view returns (uint256) {
        return s_collateralDeposited[_user][_collateralToken];
    }

    function getTokenAmountFromUsd(
        address _collateralToken,
        uint256 _usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_collateralToken]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            (_usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    /**
     * @notice This function retrieves the total value of a user's collateral in USD.
     * @param _user The address of the user to retrieve information for.
     * @return totalCollateralValueInUsd The total value of the user's collateral in USD.
     * @dev This function iterates through all collateral tokens and calculates their value in USD.
     * @dev The value is calculated using the price feed for each collateral token.
     */
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
        return totalCollateralValueInUsd;
    }

    /**
     * @notice This function retrieves the USD value of a given token amount.
     * @param _token The address of the token to retrieve the value for.
     * @param _amount The amount of the token to convert to USD.
     * @return The USD value of the given token amount.
     */
    function getUsdValue(
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        if (_amount == 0) return 0;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) /
            PRECISION;
    }

    function getAccountInformation(
        address _user
    )
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(_user);
    }
}
