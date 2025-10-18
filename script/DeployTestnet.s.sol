// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "@contract/RecycloToken.sol";
import "@contract/RewardManager.sol";
import "@contract/Marketplace.sol";
import "@interface/IDeploymentStructs.sol";

/**
 * @title Testnet Deployment Script
 * @dev Optimized deployment script for testnet environments
 * @notice Uses test-specific parameters and includes test data setup
 */
contract DeployTestnet is Script, IDeploymentStructs {
    /// @notice Testnet-specific configuration
    struct TestnetConfig {
        uint256 tokenCap;
        string tokenName;
        string tokenSymbol;
        address testMinter;
        address testUser;
    }

    /**
     * @dev Deploys contracts with testnet-optimized parameters
     * @return deployed Struct containing all deployed contract instances
     * 
     * @notice Testnet-specific features:
     * - Smaller token cap (10M vs 100M)
     * - Test token naming
     * - Optional test data population
     * - Role assignments for testing
     * 
     * @custom:environment Testnet environment variables:
     *   - PRIVATE_KEY: Testnet deployer private key
     *   - TEST_MINTER: Optional test minter address
     *   - TEST_USER: Optional test user address
     */
    function run() external returns (DeployedContracts memory) {
        return _deployTestnet();
    }

    /**
     * @dev Internal testnet deployment function
     */
    function _deployTestnet() internal returns (DeployedContracts memory deployed) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey); // Use deployer as admin for testnet
        
        // Testnet configuration
        TestnetConfig memory config = TestnetConfig({
            tokenCap: 10_000_000 * 10**18, // 10M for testnet
            tokenName: "Recyclo Test Token",
            tokenSymbol: "TRECYCLO",
            testMinter: vm.envOr("TEST_MINTER", address(0)),
            testUser: vm.envOr("TEST_USER", address(0))
        });

        console.log("Starting testnet deployment...");
        console.log("Testnet Admin:", admin);
        console.log("Token Cap:", config.tokenCap / 10**18, "tokens");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy contracts with testnet parameters
        deployed.token = new RecycloToken(
            config.tokenName,
            config.tokenSymbol,
            config.tokenCap,
            admin
        );

        deployed.rewardManager = new RewardManager(
            address(deployed.token),
            admin
        );

        deployed.marketplace = new Marketplace(
            address(deployed.token),
            admin
        );

        // Configure roles
        deployed.token.grantMinterRole(address(deployed.rewardManager));

        // Optional: Set up test roles if addresses provided
        if (config.testMinter != address(0)) {
            deployed.rewardManager.grantMinterRole(config.testMinter);
            deployed.marketplace.grantListerRole(config.testMinter);
            console.log("Test minter configured:", config.testMinter);
        }

        vm.stopBroadcast();

        console.log("\nTestnet deployment completed!");
        console.log("RecycloToken:     ", address(deployed.token));
        console.log("RewardManager:    ", address(deployed.rewardManager));
        console.log("Marketplace:      ", address(deployed.marketplace));

        return deployed;
    }

    /**
     * @dev Optional: Populate test data after deployment
     * @notice Use this to set up initial test state
     * @param rewardManager The deployed RewardManager instance
     * @param testUser Address to receive test rewards
     */
    function populateTestData(RewardManager rewardManager, address testUser) external {
        if (testUser == address(0)) {
            console.log("No test user provided, skipping test data population");
            return;
        }

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address minter = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Grant minter role to deployer for testing
        rewardManager.grantMinterRole(minter);

        // Create some test drop-offs
        bytes32[] memory metadataHashes = new bytes32[](3);
        metadataHashes[0] = keccak256("test-drop-1");
        metadataHashes[1] = keccak256("test-drop-2"); 
        metadataHashes[2] = keccak256("test-drop-3");

        address collector = address(0x123); // Test collector address

        for (uint256 i = 0; i < metadataHashes.length; i++) {
            rewardManager.confirmDropOff(
                testUser,
                100 * 10**18, // 100 tokens per drop
                collector,
                metadataHashes[i]
            );
        }

        vm.stopBroadcast();

        console.log("Test data populated: 3 test drop-offs created for", testUser);
    }
}