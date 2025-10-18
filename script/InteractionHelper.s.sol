// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "@contract/RecycloToken.sol";
import "@contract/RewardManager.sol";
import "@contract/Marketplace.sol";

/**
 * @title Recyclo Ecosystem Interaction Helper
 * @dev Script for common interactions with deployed Recyclo contracts
 * @notice Provides helper functions for testing, maintenance, and administration
 */
contract InteractionHelper is Script {
    /// @notice The RecycloToken contract instance
    RecycloToken public token;
    
    /// @notice The RewardManager contract instance  
    RewardManager public rewardManager;
    
    /// @notice The Marketplace contract instance
    Marketplace public marketplace;

    /**
     * @dev Initialize contract instances from environment variables
     * @notice Loads contract addresses from environment and creates instances
     * 
     * @custom:environment Required environment variables:
     *   - TOKEN_ADDRESS: RecycloToken contract address
     *   - REWARD_MANAGER_ADDRESS: RewardManager contract address  
     *   - MARKETPLACE_ADDRESS: Marketplace contract address (optional)
     */
    function initializeContracts() internal {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address rewardManagerAddress = vm.envAddress("REWARD_MANAGER_ADDRESS");
        address marketplaceAddress = vm.envOr("MARKETPLACE_ADDRESS", address(0));

        require(tokenAddress != address(0), "TOKEN_ADDRESS not set");
        require(rewardManagerAddress != address(0), "REWARD_MANAGER_ADDRESS not set");

        token = RecycloToken(tokenAddress);
        rewardManager = RewardManager(rewardManagerAddress);
        
        if (marketplaceAddress != address(0)) {
            marketplace = Marketplace(marketplaceAddress);
        }

        console.log("Contracts initialized:");
        console.log("Token: %s", tokenAddress);
        console.log("RewardManager: %s", rewardManagerAddress);
        if (marketplaceAddress != address(0)) {
            console.log("Marketplace: %s", marketplaceAddress);
        }
    }

    /**
     * @dev Initialize contract instances for view functions (without state modification)
     * @notice Creates local instances without modifying contract state
     */
    function _initializeContractsForView() internal view returns (
        RecycloToken token_,
        RewardManager rewardManager_,
        Marketplace marketplace_
    ) {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address rewardManagerAddress = vm.envAddress("REWARD_MANAGER_ADDRESS");
        address marketplaceAddress = vm.envOr("MARKETPLACE_ADDRESS", address(0));

        require(tokenAddress != address(0), "TOKEN_ADDRESS not set");
        require(rewardManagerAddress != address(0), "REWARD_MANAGER_ADDRESS not set");

        token_ = RecycloToken(tokenAddress);
        rewardManager_ = RewardManager(rewardManagerAddress);
        
        if (marketplaceAddress != address(0)) {
            marketplace_ = Marketplace(marketplaceAddress);
        }

        return (token_, rewardManager_, marketplace_);
    }

    /**
     * @dev Main interaction function - demonstrates common operations
     * @notice Use this for general maintenance and role management
     * 
     * @custom:operation Examples of operations performed:
     * - Grant MINTER_ROLE to new addresses
     * - Display contract statistics
     * - Verify role assignments
     */
    function run() external {
        _runInteractionHelper();
    }

    /**
     * @dev Internal implementation of the main interaction function
     */
    function _runInteractionHelper() internal {
        initializeContracts();
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Display current contract state
        _displayContractStats();

        // Example: Grant minter role to a new address if provided
        address newMinter = vm.envOr("NEW_MINTER", address(0));
        if (newMinter != address(0)) {
            rewardManager.grantMinterRole(newMinter);
            console.log("Granted MINTER_ROLE to: %s", newMinter);
        }

        // Example: Grant lister role if marketplace is configured
        address newLister = vm.envOr("NEW_LISTER", address(0));
        if (newLister != address(0) && address(marketplace) != address(0)) {
            marketplace.grantListerRole(newLister);
            console.log("Granted LISTER_ROLE to: %s", newLister);
        }

        vm.stopBroadcast();

        console.log("Interaction helper completed successfully!");
    }

    /**
     * @notice Simulate a recycling drop-off and token reward issuance
     * @dev Useful for testing reward distribution or creating test data
     * @param user Address to receive the reward tokens
     * @param amount Amount of tokens to issue (in wei)
     * @param collector Address of the collection point/operator
     * @param metadataHash Hash of off-chain verification data
     * 
     * @custom:environment Requires MINTER_PRIVATE_KEY environment variable
     * @return dropId The ID of the created drop record
     */
    function simulateDropOff(
        address user,
        uint256 amount,
        address collector,
        bytes32 metadataHash
    ) external returns (uint256 dropId) {
        return _simulateDropOff(user, amount, collector, metadataHash);
    }

    /**
     * @dev Internal implementation of simulateDropOff
     */
    function _simulateDropOff(
        address user,
        uint256 amount,
        address collector,
        bytes32 metadataHash
    ) internal returns (uint256 dropId) {
        initializeContracts();
        
        uint256 minterPrivateKey = vm.envUint("MINTER_PRIVATE_KEY");
        require(minterPrivateKey != 0, "MINTER_PRIVATE_KEY not set");
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be positive");
        require(collector != address(0), "Invalid collector address");

        console.log("Simulating drop-off...");
        console.log("User: %s", user);
        console.log("Amount: %s tokens", amount / 10**18);
        console.log("Collector: %s", collector);
        console.log("Metadata Hash: %s", vm.toString(metadataHash));

        vm.startBroadcast(minterPrivateKey);

        // Record balance before for verification
        uint256 balanceBefore = token.balanceOf(user);
        uint256 dropCountBefore = rewardManager.dropCount();

        // Execute the drop-off
        dropId = rewardManager.confirmDropOff(user, amount, collector, metadataHash);

        vm.stopBroadcast();

        // Verify the operation
        uint256 balanceAfter = token.balanceOf(user);
        uint256 dropCountAfter = rewardManager.dropCount();

        require(balanceAfter == balanceBefore + amount, "Token balance not updated correctly");
        require(dropCountAfter == dropCountBefore + 1, "Drop count not incremented");
        require(dropId == dropCountAfter, "Drop ID mismatch");

        console.log("Drop-off simulation completed successfully!");
        console.log("Drop issued with ID: %s", dropId);
        console.log("Tokens minted to: %s", user);
        console.log("Amount: %s tokens", amount / 10**18);
        console.log("New balance: %s tokens", balanceAfter / 10**18);

        return dropId;
    }

    /**
     * @notice Batch simulate multiple drop-offs
     * @dev Efficient way to create multiple test records
     * @param users Array of user addresses to receive rewards
     * @param amounts Array of token amounts to issue
     * @param collectors Array of collector addresses
     * @param metadataHashes Array of metadata hashes
     * 
     * @return dropIds Array of created drop IDs
     */
    function batchSimulateDropOffs(
        address[] memory users,
        uint256[] memory amounts,
        address[] memory collectors,
        bytes32[] memory metadataHashes
    ) external returns (uint256[] memory dropIds) {
        return _batchSimulateDropOffs(users, amounts, collectors, metadataHashes);
    }

    /**
     * @dev Internal implementation of batchSimulateDropOffs
     */
    function _batchSimulateDropOffs(
        address[] memory users,
        uint256[] memory amounts,
        address[] memory collectors,
        bytes32[] memory metadataHashes
    ) internal returns (uint256[] memory dropIds) {
        require(
            users.length == amounts.length && 
            amounts.length == collectors.length && 
            collectors.length == metadataHashes.length,
            "Array length mismatch"
        );

        initializeContracts();
        uint256 minterPrivateKey = vm.envUint("MINTER_PRIVATE_KEY");
        require(minterPrivateKey != 0, "MINTER_PRIVATE_KEY not set");

        console.log("Batch simulating %s drop-offs...", users.length);

        dropIds = new uint256[](users.length);
        uint256 totalAmount = 0;

        vm.startBroadcast(minterPrivateKey);

        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid user address");
            require(amounts[i] > 0, "Amount must be positive");
            require(collectors[i] != address(0), "Invalid collector address");

            dropIds[i] = rewardManager.confirmDropOff(
                users[i],
                amounts[i],
                collectors[i],
                metadataHashes[i]
            );

            totalAmount += amounts[i];
            console.log("Drop %s - ID: %s, User: %s", i + 1, dropIds[i], users[i]);
        }

        vm.stopBroadcast();

        console.log("Batch simulation completed!");
        console.log("Total drops created: %s", users.length);
        console.log("Total tokens distributed: %s tokens", totalAmount / 10**18);

        return dropIds;
    }

    /**
     * @notice Revoke a drop (admin function)
     * @dev Useful for testing revocation functionality or handling disputes
     * @param dropId ID of the drop to revoke
     * @param reason Explanation for the revocation
     */
    function revokeDrop(uint256 dropId, string calldata reason) external {
        _revokeDrop(dropId, reason);
    }

    /**
     * @dev Internal implementation of revokeDrop
     */
    function _revokeDrop(uint256 dropId, string calldata reason) internal {
        initializeContracts();
        
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        require(adminPrivateKey != 0, "PRIVATE_KEY not set");

        console.log("Revoking drop ID: %s", dropId);
        console.log("Reason: %s", reason);

        // Check drop status before revocation
        RewardManager.Drop memory dropBefore = rewardManager.getDrop(dropId);
        require(dropBefore.status == RewardManager.Status.Issued, "Drop not in Issued status");

        vm.startBroadcast(adminPrivateKey);

        rewardManager.revokeDrop(dropId, reason);

        vm.stopBroadcast();

        // Verify revocation
        RewardManager.Drop memory dropAfter = rewardManager.getDrop(dropId);
        require(dropAfter.status == RewardManager.Status.Revoked, "Drop status not updated to Revoked");

        console.log("Drop revoked successfully");
    }

    /**
     * @notice Display current contract statistics
     * @dev Useful for monitoring and debugging
     */
    function displayStats() external view {
        _displayStats();
    }

    /**
     * @dev Internal implementation of displayStats
     */
    function _displayStats() internal view {
        (RecycloToken token_, RewardManager rewardManager_, Marketplace marketplace_) = _initializeContractsForView();
        _displayContractStats(token_, rewardManager_, marketplace_);
    }

    /**
     * @dev Internal function to display contract statistics
     */
    function _displayContractStats(
        RecycloToken token_,
        RewardManager rewardManager_,
        Marketplace marketplace_
    ) internal view {
        console.log("Contract Statistics:");
        console.log("======================");
        
        // Token stats
        console.log("Token Stats:");
        console.log("  Name: %s", token_.name());
        console.log("  Symbol: %s", token_.symbol());
        console.log("  Total Supply: %s tokens", token_.totalSupply() / 10**18);
        console.log("  Cap: %s tokens", token_.cap() / 10**18);
        
        // RewardManager stats
        console.log("RewardManager Stats:");
        console.log("  Total Drops: %s", rewardManager_.dropCount());
        
        // Marketplace stats (if available)
        if (address(marketplace_) != address(0)) {
            console.log("Marketplace Stats:");
            console.log("  Total Listings: %s", marketplace_.listingCount());
        }
        
        console.log("======================");
    }

    /**
     * @notice Verify role assignments for an address
     * @dev Useful for debugging permission issues
     * @param account Address to check roles for
     */
    function verifyRoles(address account) external view {
        _verifyRoles(account);
    }

    /**
     * @dev Internal implementation of verifyRoles
     */
    function _verifyRoles(address account) internal view {
        (RecycloToken token_, RewardManager rewardManager_, Marketplace marketplace_) = _initializeContractsForView();
        
        console.log("Role Verification for: %s", account);
        console.log("======================");
        
        // Token roles
        console.log("Token Roles:");
        console.log("  DEFAULT_ADMIN_ROLE: %s", token_.hasRole(token_.DEFAULT_ADMIN_ROLE(), account));
        console.log("  MINTER_ROLE: %s", token_.hasRole(token_.MINTER_ROLE(), account));
        console.log("  BURNER_ROLE: %s", token_.hasRole(token_.BURNER_ROLE(), account));
        
        // RewardManager roles
        console.log("RewardManager Roles:");
        console.log("  DEFAULT_ADMIN_ROLE: %s", rewardManager_.hasRole(rewardManager_.DEFAULT_ADMIN_ROLE(), account));
        console.log("  MINTER_ROLE: %s", rewardManager_.hasRole(rewardManager_.MINTER_ROLE(), account));
        
        // Marketplace roles (if available)
        if (address(marketplace_) != address(0)) {
            console.log("Marketplace Roles:");
            console.log("  DEFAULT_ADMIN_ROLE: %s", marketplace_.hasRole(marketplace_.DEFAULT_ADMIN_ROLE(), account));
            console.log("  LISTER_ROLE: %s", marketplace_.hasRole(marketplace_.LISTER_ROLE(), account));
        }
        
        console.log("======================");
    }

    /**
     * @notice Create a test marketplace listing
     * @dev Useful for testing marketplace functionality
     * @param quantity Number of items to list
     * @param pricePerUnit Price per item in tokens
     * @param metaHash Hash of listing metadata
     * @return listingId The ID of the created listing
     */
    function createTestListing(
        uint256 quantity,
        uint256 pricePerUnit,
        bytes32 metaHash
    ) external returns (uint256 listingId) {
        initializeContracts();
        require(address(marketplace) != address(0), "Marketplace not configured");

        uint256 listerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(listerPrivateKey != 0, "PRIVATE_KEY not set");

        console.log("Creating test listing...");
        console.log("Quantity: %s", quantity);
        console.log("Price per unit: %s tokens", pricePerUnit / 10**18);

        vm.startBroadcast(listerPrivateKey);

        listingId = marketplace.createListing(quantity, pricePerUnit, metaHash);

        vm.stopBroadcast();

        console.log("Test listing created with ID: %s", listingId);
        return listingId;
    }

    /**
     * @notice Buy from a marketplace listing
     * @dev Useful for testing marketplace purchases
     * @param listingId ID of the listing to buy from
     * @param quantity Number of items to purchase
     */
    function buyFromListing(uint256 listingId, uint256 quantity) external {
        initializeContracts();
        require(address(marketplace) != address(0), "Marketplace not configured");

        uint256 buyerPrivateKey = vm.envUint("PRIVATE_KEY");
        require(buyerPrivateKey != 0, "PRIVATE_KEY not set");

        address buyer = vm.addr(buyerPrivateKey);

        console.log("Buying from listing ID: %s", listingId);
        console.log("Quantity: %s", quantity);
        console.log("Buyer: %s", buyer);

        // Get listing details to calculate cost
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        uint256 totalCost = quantity * listing.pricePerUnit;

        console.log("Total cost: %s tokens", totalCost / 10**18);

        vm.startBroadcast(buyerPrivateKey);

        // Ensure buyer has sufficient allowance
        token.approve(address(marketplace), totalCost);

        // Execute purchase
        marketplace.buyListing(listingId, quantity);

        vm.stopBroadcast();

        console.log("Purchase completed successfully!");
    }

    /**
     * @dev Internal function to display contract statistics (for non-view contexts)
     */
    function _displayContractStats() internal view {
        console.log("Contract Statistics:");
        console.log("======================");
        
        // Token stats
        console.log("Token Stats:");
        console.log("  Name: %s", token.name());
        console.log("  Symbol: %s", token.symbol());
        console.log("  Total Supply: %s tokens", token.totalSupply() / 10**18);
        console.log("  Cap: %s tokens", token.cap() / 10**18);
        
        // RewardManager stats
        console.log("RewardManager Stats:");
        console.log("  Total Drops: %s", rewardManager.dropCount());
        
        // Marketplace stats (if available)
        if (address(marketplace) != address(0)) {
            console.log("Marketplace Stats:");
            console.log("  Total Listings: %s", marketplace.listingCount());
        }
        
        console.log("======================");
    }
}