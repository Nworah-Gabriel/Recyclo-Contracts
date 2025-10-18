// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "@contract/RecycloToken.sol";
import "@contract/RewardManager.sol";
import "@contract/Marketplace.sol";
import "@interface/IDeploymentStructs.sol";

/**
 * @title Recyclo Ecosystem Deployment Script
 * @dev Script to deploy the complete Recyclo ecosystem contracts
 * @notice Deploys RecycloToken, RewardManager, and Marketplace with proper role configuration
 */
contract DeployScript is Script, IDeploymentStructs {
    /**
     * @dev Main deployment function
     * @return deployed Struct containing all deployed contract instances
     * 
     * @notice Deployment Steps:
     * 1. Deploy RecycloToken with 100M token cap
     * 2. Deploy RewardManager linked to the token
     * 3. Deploy Marketplace linked to the token  
     * 4. Configure roles:
     *    - Grant MINTER_ROLE to RewardManager for token minting
     *    - Admin gets DEFAULT_ADMIN_ROLE on all contracts
     * 
     * @custom:environment Requires environment variables:
     *   - PRIVATE_KEY: Private key of deployer account
     *   - ADMIN_ADDRESS: Address to receive admin roles
     * 
     * @custom:security Important security considerations:
     *   - ADMIN_ADDRESS should be a multisig wallet in production
     *   - Store deployed addresses securely for future interactions
     *   - Verify contracts on block explorer after deployment
     */
    function run() external returns (DeployedContracts memory) {
        return _deploy();
    }

    /**
     * @dev Internal deployment function
     */
    function _deploy() internal returns (DeployedContracts memory deployed) {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        
        // Validate configuration
        require(deployerPrivateKey != 0, "DeployScript: PRIVATE_KEY not set");
        require(admin != address(0), "DeployScript: ADMIN_ADDRESS not set");

        console.log("Starting deployment of Recyclo ecosystem...");
        console.log("Admin address:", admin);
        console.log("Deployer address:", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy RecycloToken
        console.log("\n1. Deploying RecycloToken...");
        deployed.token = new RecycloToken(
            "Recyclo Token",
            "RECYCLO",
            100_000_000 * 10**18, // 100M tokens with 18 decimals
            admin
        );
        console.log("RecycloToken deployed at:", address(deployed.token));

        // Step 2: Deploy RewardManager
        console.log("\n2. Deploying RewardManager...");
        deployed.rewardManager = new RewardManager(
            address(deployed.token),
            admin
        );
        console.log("RewardManager deployed at:", address(deployed.rewardManager));

        // Step 3: Deploy Marketplace
        console.log("\n3. Deploying Marketplace...");
        deployed.marketplace = new Marketplace(
            address(deployed.token),
            admin
        );
        console.log("Marketplace deployed at:", address(deployed.marketplace));

        // Step 4: Configure roles
        console.log("\n4. Configuring roles...");
        deployed.token.grantMinterRole(address(deployed.rewardManager));
        console.log("Granted MINTER_ROLE to RewardManager");

        vm.stopBroadcast();

        // Final deployment summary
        console.log("\nDeployment completed successfully!");
        console.log("=====================================");
        console.log("RecycloToken:     ", address(deployed.token));
        console.log("RewardManager:    ", address(deployed.rewardManager));
        console.log("Marketplace:      ", address(deployed.marketplace));
        console.log("Admin:            ", admin);
        console.log("=====================================");

        return deployed;
    }

    /**
     * @notice Validates the deployment by checking contract configurations
     * @dev Can be called after deployment to verify everything is set up correctly
     * @param token The deployed RecycloToken instance
     * @param rewardManager The deployed RewardManager instance  
     * @param marketplace The deployed Marketplace instance
     * @param admin The admin address that should have roles
     */
    function validateDeployment(
        RecycloToken token,
        RewardManager rewardManager,
        Marketplace marketplace,
        address admin
    ) external view {
        console.log("\nValidating deployment...");

        // Check token configuration
        require(keccak256(bytes(token.name())) == keccak256(bytes("Recyclo Token")), "Token name mismatch");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes("RECYCLO")), "Token symbol mismatch");
        require(token.cap() == 100_000_000 * 10**18, "Token cap mismatch");
        console.log("Token configuration valid");

        // Check role assignments
        require(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE on token");
        require(token.hasRole(token.MINTER_ROLE(), address(rewardManager)), "RewardManager should have MINTER_ROLE on token");
        console.log("Role assignments valid");

        // Check contract linkages
        require(rewardManager.token() == token, "RewardManager token reference mismatch");
        require(marketplace.token() == token, "Marketplace token reference mismatch");
        console.log("Contract linkages valid");

        // Check admin roles on all contracts
        require(rewardManager.hasRole(rewardManager.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE on RewardManager");
        require(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE on Marketplace");
        console.log("Admin roles valid");

        console.log("All deployment validations passed!");
    }
}