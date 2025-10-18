// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "@contract/RecycloToken.sol";
import "@contract/RewardManager.sol";
import "@contract/Marketplace.sol";

/**
 * @title Configuration Helper Script
 * @dev Helper functions for post-deployment configuration and management
 * @notice Use these functions to manage roles and settings after deployment
 */
contract ConfigHelper is Script {
    /**
     * @dev Configure additional minter addresses for RewardManager
     * @param rewardManagerAddress Address of deployed RewardManager
     * @param minters Array of addresses to grant MINTER_ROLE
     */
    function configureMinters(
        address rewardManagerAddress,
        address[] memory minters
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        RewardManager rewardManager = RewardManager(rewardManagerAddress);
        
        for (uint256 i = 0; i < minters.length; i++) {
            rewardManager.grantMinterRole(minters[i]);
            console.log("Granted MINTER_ROLE to:", minters[i]);
        }

        vm.stopBroadcast();
        
        console.log("Configured", minters.length, "additional minters");
    }

    /**
     * @dev Configure additional lister addresses for Marketplace
     * @param marketplaceAddress Address of deployed Marketplace
     * @param listers Array of addresses to grant LISTER_ROLE
     */
    function configureListers(
        address marketplaceAddress,
        address[] memory listers
    ) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        Marketplace marketplace = Marketplace(marketplaceAddress);
        
        for (uint256 i = 0; i < listers.length; i++) {
            marketplace.grantListerRole(listers[i]);
            console.log("Granted LISTER_ROLE to:", listers[i]);
        }

        vm.stopBroadcast();
        
        console.log("Configured", listers.length, "additional listers");
    }

    /**
     * @dev Verify contract configuration and role assignments
     * @param tokenAddress RecycloToken address
     * @param rewardManagerAddress RewardManager address
     * @param marketplaceAddress Marketplace address
     */
    function verifyConfiguration(
        address tokenAddress,
        address rewardManagerAddress,
        address marketplaceAddress
    ) external view {
        RecycloToken token = RecycloToken(tokenAddress);
        RewardManager rewardManager = RewardManager(rewardManagerAddress);
        Marketplace marketplace = Marketplace(marketplaceAddress);

        console.log("\nVerifying Contract Configuration...");

        // Check token setup
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("Token Cap:", token.cap() / 10**18, "tokens");
        console.log("Total Supply:", token.totalSupply() / 10**18, "tokens");

        // Check role assignments
        console.log("\nRole Assignments:");
        console.log("RewardManager has MINTER_ROLE on Token:", 
            token.hasRole(token.MINTER_ROLE(), rewardManagerAddress));
        console.log("Marketplace token reference:", address(marketplace.token()));

        // Check drop count
        console.log("RewardManager drop count:", rewardManager.dropCount());
        console.log("Marketplace listing count:", marketplace.listingCount());

        console.log("\nConfiguration verification complete");
    }
}