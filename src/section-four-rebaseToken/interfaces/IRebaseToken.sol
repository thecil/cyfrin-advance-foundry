// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRebaseToken{
    
    /**
     * @notice Get the principle balance of a user.
     * This is the number of tokens that have currently minted to the user, not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user the
     */
    function principleBalanceOf(address _user) external view returns (uint256);
    
    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the tokens to
     * @param _amount The amount of tokens to mint
     */
    function mint(
        address _to,
        uint256 _amount
    ) external;
    
    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the tokens from
     * @param _amount The amount of tokens to burn
     */
    function burn(
        address _from,
        uint256 _amount
    ) external;
    
    /**
     * @notice Transfer tokens from one user to another
     * @param _recipient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(
        address _recipient,
        uint256 _amount
    ) external returns (bool);

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
    ) external returns (bool);

    /**
     * @notice Get the interest rate that is currently set for the contract.
     * Any future deposit will receive this interest rate.
     * @return The interest rate for the contract
     */
    function getInterestRate() external view returns (uint256);
    
    /**
     * @notice Get the interest rate for the user
     * @param _user The user to get the interest rate for
     * @return The interest rate for the user
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) 
}