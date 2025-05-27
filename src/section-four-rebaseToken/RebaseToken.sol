// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Carlos Zambrano - thecil
 * @notice This is a cross-chain rebase token that incentives users to deposit into a vault and gain interest as reward.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
 */
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 prevInterestRate,
        uint256 newInterestRate
    );

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 _newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /**
     * @notice Set the interest rate in the contract
     * @param _newInterestRate The new interest rate to set
     * @dev The interest rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external {
        // set interest rate
        if (_newInterestRate < s_interestRate)
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Get the principle balance of a user.
     * This is the number of tokens that have currently minted to the user, not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user the
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) _amount = balanceOf(_from);
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }
    /**
     * @notice calculate the balance for the user including the interest that has accumulated since the last update
     * (principle balance) + some interest that has accrued
     * @param _user The user to calculate the balance for
     *@ @return uint256 The balance of the user including that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) _amount = balanceOf(msg.sender);
        if (balanceOf(_recipient) == 0)
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _from The user to transfer the tokens from
     * @param _to The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);
        if (_amount == type(uint256).max) _amount = balanceOf(_from);
        if (balanceOf(_to) == 0)
            s_userInterestRate[_to] = s_userInterestRate[_from];
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user to calculate the interest accumulated for
     * @return linearInterest The interest that has accumulated since last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256 linearInterest) {
        uint256 timeElapse = block.timestamp -
            s_userLastUpdatedTimestamp[_user];
        linearInterest =
            PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeElapse);
    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the protocol. (eg. burn, mint, transfer)
     * @param _user The user to mint the accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    /**
     * @notice Get the interest rate that is currently set for the contract.
     * Any future deposit will receive this interest rate.
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
    /**
     * @notice Get the interest rate for the user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
