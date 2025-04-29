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

    //////////////////////////
    //   State Variables   //
    /////////////////////////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;

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
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );
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

    function redeemCollateral(
        address _collateralToken,
        uint256 _collateralAmount
    ) public moreThanZero(_collateralAmount) nonReentrant {
        s_collateralDeposited[msg.sender][
            _collateralToken
        ] -= _collateralAmount;
        emit CollateralRedeemed(
            msg.sender,
            _collateralToken,
            _collateralAmount
        );
        bool success = IERC20(_collateralToken).transfer(
            msg.sender,
            _collateralAmount
        );
        if (!success) revert DSCEngine__TransferFailed();
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
        burnDsc(_collateralToken, _collateralAmount, _dscAmountToBurn);
        redeemCollateral(_collateralToken, _collateralAmount);
        // redeemCollateral already checks the health factor
    }

    function burnDsc(
        address _collateralToken,
        uint256 _collateralAmount,
        uint256 _dscAmountToBurn
    ) public moreThanZero(_dscAmountToBurn) nonReentrant {
        s_dscMinted[msg.sender] -= _dscAmountToBurn;
        bool success = i_dsc.transferFrom(
            msg.sender,
            address(this),
            _dscAmount
        );
        if (!success) revert DSCEngine__TransferFailed();
        i_dsc.burn(_dscAmount);
        _revertIfHealthFactorIsTooLow(msg.sender); // i don't think this would ever hit...
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
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(_user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _revertIfHealthFactorIsTooLow(address _user) internal view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorTooLow(userHealthFactor);
        }
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
