// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "@contract/RecycloToken.sol";
import "@contract/RewardManager.sol";
import "@contract/Marketplace.sol";

/**
 * @title Upgrade Deployment Script
 * @dev Script for upgrading specific components of the Recyclo ecosystem
 * @notice Use this when deploying new versions of contracts while preserving state
 */
contract DeployUpgrade is Script {
    /**
     * @dev Deploy new Marketplace while keeping existing Token and RewardManager
     * @param existingTokenAddress Address of existing RecycloToken
     * @param existingRewardManagerAddress Address of existing RewardManager
     * @param admin Admin address for role assignment
     * @return newMarketplace New Marketplace instance
     * 
     * @notice Use case: Upgrade Marketplace logic while preserving token and rewards
     */
    function upgradeMarketplace(
        address existingTokenAddress,
        address existingRewardManagerAddress,
        address admin
    ) external returns (Marketplace newMarketplace) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Upgrading Marketplace...");
        console.log("Existing Token:", existingTokenAddress);
        console.log("Existing RewardManager:", existingRewardManagerAddress);

        vm.startBroadcast(deployerPrivateKey);

        newMarketplace = new Marketplace(
            existingTokenAddress,
            admin
        );

        vm.stopBroadcast();

        console.log("New Marketplace deployed at:", address(newMarketplace));
    }

    /**
     * @dev Deploy new RewardManager with migration capabilities
     * @param existingTokenAddress Address of existing RecycloToken
     * @param admin Admin address for role assignment
     * @return newRewardManager New RewardManager instance
     * 
     * @notice Important: This requires transferring MINTER_ROLE and potentially migrating state
     */
    function upgradeRewardManager(
        address existingTokenAddress,
        address admin
    ) external returns (RewardManager newRewardManager) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Upgrading RewardManager...");
        console.log("Existing Token:", existingTokenAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new RewardManager
        newRewardManager = new RewardManager(
            existingTokenAddress,
            admin
        );

        // Transfer MINTER_ROLE to new RewardManager
        RecycloToken token = RecycloToken(existingTokenAddress);
        token.grantMinterRole(address(newRewardManager));
        
        // Note: In production, you might want to revoke old RewardManager's role
        // token.revokeMinterRole(oldRewardManagerAddress);

        vm.stopBroadcast();

        console.log("New RewardManager deployed at:", address(newRewardManager));
        console.log("MINTER_ROLE transferred to new RewardManager");
    }
}