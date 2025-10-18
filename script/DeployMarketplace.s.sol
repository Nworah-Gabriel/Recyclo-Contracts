// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "@contract/Marketplace.sol";
import "@contract/RecycloToken.sol";

/**
 * @title Marketplace Deployment Script
 * @dev Script to deploy the Marketplace contract independently
 * @notice Use this when deploying Marketplace separately from the main ecosystem
 */
contract DeployMarketplace is Script {
    /// @notice The deployed Marketplace instance
    Marketplace public marketplace;

    /**
     * @dev Main deployment function for Marketplace
     * @return The deployed Marketplace instance
     * 
     * @notice Deployment Requirements:
     * - TOKEN_ADDRESS must be a valid RecycloToken contract
     * - ADMIN_ADDRESS will receive DEFAULT_ADMIN_ROLE and LISTER_ROLE
     * - PRIVATE_KEY must have sufficient funds for deployment
     * 
     * @custom:environment Environment variables required:
     *   - PRIVATE_KEY: Deployer's private key
     *   - ADMIN_ADDRESS: Address to receive admin roles
     *   - TOKEN_ADDRESS: Address of existing RecycloToken contract
     * 
     * @custom:security Security considerations:
     *   - Verify TOKEN_ADDRESS is the correct RecycloToken contract
     *   - ADMIN_ADDRESS should be a secure wallet/multisig
     *   - Store deployment address for future reference
     */
    function run() external returns (Marketplace) {
        return _deployMarketplace();
    }

    /**
     * @notice Deploy Marketplace and configure additional listers in one transaction
     * @dev Useful for setting up multiple listers during initial deployment
     * @param additionalListers Array of addresses to grant LISTER_ROLE
     * @return The deployed Marketplace instance
     */
    function runWithAdditionalListers(
        address[] memory additionalListers
    ) external returns (Marketplace) {
        // Deploy the marketplace using internal function
        Marketplace marketplaceInstance = _deployMarketplace();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Grant LISTER_ROLE to additional addresses
        for (uint256 i = 0; i < additionalListers.length; i++) {
            marketplaceInstance.grantListerRole(additionalListers[i]);
            console.log("Granted LISTER_ROLE to:", additionalListers[i]);
        }

        vm.stopBroadcast();

        console.log("Configured", additionalListers.length, "additional listers during deployment");

        return marketplaceInstance;
    }

    /**
     * @dev Internal function to handle Marketplace deployment
     * @return The deployed Marketplace instance
     */
    function _deployMarketplace() internal returns (Marketplace) {
        // Load configuration from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        
        // Validate configuration
        require(deployerPrivateKey != 0, "DeployMarketplace: PRIVATE_KEY not set");
        require(admin != address(0), "DeployMarketplace: ADMIN_ADDRESS not set");
        require(tokenAddress != address(0), "DeployMarketplace: TOKEN_ADDRESS not set");

        console.log("Starting Marketplace deployment...");
        console.log("Admin address:", admin);
        console.log("Token address:", tokenAddress);
        console.log("Deployer address:", vm.addr(deployerPrivateKey));

        // Verify token contract exists and is valid
        _validateTokenContract(tokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Marketplace contract
        console.log("\nDeploying Marketplace contract...");
        marketplace = new Marketplace(tokenAddress, admin);
        
        vm.stopBroadcast();

        console.log("\n Marketplace deployed successfully!");
        console.log("Marketplace address:", address(marketplace));
        console.log("Linked Token:", tokenAddress);
        console.log("Admin:", admin);

        // Post-deployment validation
        _validateDeployment(marketplace, tokenAddress, admin);

        return marketplace;
    }

    /**
     * @dev Validates the token contract before deployment
     * @param tokenAddress Address of the token contract to validate
     * @custom:throws If token contract is invalid or doesn't exist
     */
    function _validateTokenContract(address tokenAddress) internal view {
        // Basic checks
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(tokenAddress.code.length > 0, "No contract at token address");
        
        // Try to interact with token contract
        try RecycloToken(tokenAddress).symbol() returns (string memory symbol) {
            console.log("Token contract validated - Symbol:", symbol);
        } catch {
            revert("Invalid token contract at provided address");
        }
    }

    /**
     * @dev Validates the Marketplace deployment
     * @param marketplaceInstance The deployed Marketplace instance
     * @param expectedTokenAddress The expected token address
     * @param expectedAdmin The expected admin address
     */
    function _validateDeployment(
        Marketplace marketplaceInstance,
        address expectedTokenAddress,
        address expectedAdmin
    ) internal view {
        console.log("\nValidating Marketplace deployment...");

        // Check token reference
        require(
            address(marketplaceInstance.token()) == expectedTokenAddress,
            "Token reference mismatch"
        );
        console.log("Token reference correct");

        // Check admin roles
        require(
            marketplaceInstance.hasRole(marketplaceInstance.DEFAULT_ADMIN_ROLE(), expectedAdmin),
            "Admin role not assigned"
        );
        require(
            marketplaceInstance.hasRole(marketplaceInstance.LISTER_ROLE(), expectedAdmin),
            "Lister role not assigned"
        );
        console.log("Admin roles assigned correctly");

        // Check initial state
        require(marketplaceInstance.listingCount() == 0, "Initial listing count should be zero");
        console.log("Initial state correct");

        console.log("Marketplace deployment validation passed!");
    }
}