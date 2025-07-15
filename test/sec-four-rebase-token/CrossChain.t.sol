// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";

// Importing necessary contracts and interfaces for testing RebaseToken functionality on cross-chain operations.
import {RebaseToken} from "../../src/sec-four-rebase-token/RebaseToken.sol";
import {RebaseTokenPool} from "../../src/sec-four-rebase-token/RebaseTokenPool.sol";
import {Vault} from "../../src/sec-four-rebase-token/Vault.sol";
import {IRebaseToken} from "../../src/sec-four-rebase-token/interfaces/IRebaseToken.sol";

// Importing ChainLink CCIP contracts and interfaces for simulating cross-chain interactions.
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink-local/lib/ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

// Defining the CrossChainTest contract that inherits from Test for testing purposes.
contract CrossChainTest is Test {
    address public owner = makeAddr("owner"); // Define the owner address
    address public user = makeAddr("user");
    uint256 SEND_VALUE = 1e5;

    uint256 public sepoliaFork; // Variable to store the Sepolia fork ID
    uint256 public arbSepoliaFork; // Variable to store the Arbitrum on Sepolia fork ID

    CCIPLocalSimulatorFork public ccipLocalSimulatorFork; // Instance of the CCIP Local Simulator Fork contract
    RebaseToken public sepoliaToken; // Instance of the RebaseToken deployed on Sepolia
    RebaseToken public arbSepoliaToken; // Instance of the RebaseToken deployed on Arbitrum on Sepolia

    Vault public vault; // Instance of the Vault contract

    RebaseTokenPool public sepoliaPool; // Instance of the RebaseTokenPool on Sepolia
    RebaseTokenPool public arbSepoliaPool; // Instance of the RebaseTokenPool on Arbitrum on Sepolia

    Register.NetworkDetails public sepoliaNetworkDetails; // Network details for Sepolia
    Register.NetworkDetails public arbSepoliaNetworkDetails; // Network details for Arbitrum on Sepolia

    // Function to set up the testing environment.
    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia"); // Create a fork of the Sepolia network
        arbSepoliaFork = vm.createFork("arb-sepolia"); // Create a fork of the Arbitrum on Sepolia network

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork(); // Deploy the CCIP Local Simulator Fork contract
        vm.makePersistent(address(ccipLocalSimulatorFork)); // Make the CCIP Local Simulator Fork contract persistent across forks

        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails( // Fetch network details for Sepolia
        block.chainid);

        // 1. Deploy and config on sepolia
        vm.startPrank(owner); // Start impersonating the owner account

        sepoliaToken = new RebaseToken(); // Deploy a new RebaseToken contract on Sepolia
        vault = new Vault(IRebaseToken(address(sepoliaToken))); // Deploy a new Vault contract using the deployed RebaseToken
        sepoliaPool = new RebaseTokenPool( // Deploy a new RebaseTokenPool contract for the RebaseToken on Sepolia
            IERC20(address(sepoliaToken)),
            new address[](0),
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        sepoliaToken.grantMintAndBurnRole(address(vault)); // Grant mint and burn roles to the Vault contract on Sepolia
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool)); // Grant mint and burn roles to the RebaseTokenPool contract on Sepolia

        // Register the token as an admin via owner for both registry modules and set the pool for TokenAdminRegistry on Sepolia
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(sepoliaToken)
        );

        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(sepoliaToken));
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(sepoliaToken), address(sepoliaPool)
        );

        // 2. Deploy and config on arbitrum sepolia
        vm.selectFork(arbSepoliaFork); // Switch to the Arbitrum on Sepolia fork
        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails( // Fetch network details for Arbitrum on Sepolia
        block.chainid);

        arbSepoliaToken = new RebaseToken(); // Deploy a new RebaseToken contract on Arbitrum on Sepolia
        arbSepoliaPool = new RebaseTokenPool( // Deploy a new RebaseTokenPool contract for the RebaseToken on Arbitrum on Sepolia
            IERC20(address(arbSepoliaToken)),
            new address[](0),
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );

        arbSepoliaToken.grantMintAndBurnRole(address(arbSepoliaPool)); // Grant mint and burn roles to the RebaseTokenPool contract on Arbitrum on Sepolia

        // Register the token as an admin via owner for both registry modules and set the pool for TokenAdminRegistry on Arbitrum on Sepolia
        RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(arbSepoliaToken)
        );

        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).acceptAdminRole(address(arbSepoliaToken));
        TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress).setPool(
            address(arbSepoliaToken), address(arbSepoliaPool)
        );

        configureTokenPool(
            sepoliaFork,
            address(sepoliaPool),
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSepoliaPool),
            address(arbSepoliaToken)
        );
        configureTokenPool(
            arbSepoliaFork,
            address(arbSepoliaPool),
            sepoliaNetworkDetails.chainSelector,
            address(sepoliaPool),
            address(sepoliaToken)
        );
        vm.stopPrank(); // Stop impersonating the owner account
    }

    // Function to configure token pools for cross-chain operations.
    function configureTokenPool(
        uint256 fork,
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteTokenAddress
    ) public {
        vm.selectFork(fork);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: remotePoolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0), chainsToAdd);
    }

    // Function to bridge tokens between two chains.
    function bridgeTokens(
        uint256 amountToBridge, // Amount of tokens to bridge
        uint256 localFork, // Fork ID for the local chain
        uint256 remoteFork, // Fork ID for the remote chain
        Register.NetworkDetails memory localNetworkDetails, // Details of the local network
        Register.NetworkDetails memory remoteNetworkDetails, // Details of the remote network
        RebaseToken localToken, // Local token contract instance
        RebaseToken remoteToken // Remote token contract instance
    ) public {
        vm.selectFork(localFork); // Select the fork for the local chain
        vm.startPrank(user); // Impersonate the user to perform actions on their behalf

        // Prepare the token amounts to be transferred
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken), // Token contract address for local network
            amount: amountToBridge // Amount to transfer
        });

        // Create the message object with necessary details
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user), // Receiver of the tokens
            data: "", // No additional data required for this message
            tokenAmounts: tokenAmounts, // Array of token amounts to transfer
            feeToken: localNetworkDetails.linkAddress, // Link token address for paying fees
            extraArgs: Client._argsToBytes( // Extra arguments for the message
                Client.EVMExtraArgsV1({gasLimit: 200_000}))
        });

        // Calculate the fee required for the transaction
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(
            remoteNetworkDetails.chainSelector, // Chain selector for the remote network
            message // Message object
        );

        // Request LINK from the faucet for paying fees
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);

        // Approve the Router to use the required amount of LINK and local tokens
        vm.startPrank(user);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        // Get the balance of the user's local token before bridging
        uint256 localBalanceBefore = localToken.balanceOf(user);

        // Send the message to the remote chain using the Router
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        // Get the balance of the user's local token after bridging
        uint256 localBalanceAfter = localToken.balanceOf(user);

        // Stop impersonating the user
        vm.stopPrank();

        // Assert that the local balance is reduced by the amount bridged
        assertEq(
            localBalanceAfter,
            localBalanceBefore - amountToBridge,
            "local balance should be reduced by the amount to bridge"
        );

        // Select the fork for the remote chain
        vm.selectFork(remoteFork);

        // Warp time forward to simulate a delay in receiving the message
        vm.warp(block.timestamp + 20 minutes);

        // Get the balance of the user's remote token before bridging
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user);

        // Switch to the remote fork and route the message
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        // Get the balance of the user's remote token after bridging
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user);

        // Assert that the remote balance is increased by the amount bridged
        assertEq(
            remoteBalanceAfter,
            remoteBalanceBefore + amountToBridge,
            "remote balance should be increased by the amount to bridge"
        );

        // Get the user's interest rate on both tokens before and after bridging
        // uint256 localUserInterestRate = localToken.getUserInterestRate(user);
        // uint256 remoteUserInterestRate = remoteToken.getUserInterestRate(user);

        // Assert that the user's interest rate remains unchanged
        // assertEq(
        //     remoteUserInterestRate,
        //     localUserInterestRate,
        //     "user interest rate should remain unchanged"
        // );
    }

    function test_bridgeAllTokens() public {
        vm.selectFork(sepoliaFork); // Switch to the Sepolia fork
        vm.deal(user, SEND_VALUE); // Assign a balance to the user on the Sepolia network
        vm.startPrank(user); // Start prank mode from the user's perspective
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}(); // Deposit tokens into the vault and assert that the value has been sent
        assertEq(sepoliaToken.balanceOf(user), SEND_VALUE, "user should have sent the value");

        // Bridge tokens from Sepolia to Arbitrum on Sepolia fork
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sepoliaToken,
            arbSepoliaToken
        );

        vm.selectFork(arbSepoliaFork); // Switch to the Arbitrum on Sepolia fork
        vm.warp(block.timestamp + 20 minutes); // Warp time forward by 20 minutes to ensure the bridge is ready

        // Bridge tokens back from Arbitrum on Sepolia to Sepolia fork
        bridgeTokens(
            arbSepoliaToken.balanceOf(user),
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            arbSepoliaToken,
            sepoliaToken
        );
    }
}
