// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "@contract/Marketplace.sol";
import {RecycloToken} from "@contract/RecycloToken.sol";
import {RewardManager} from "@contract/RewardManager.sol";

/**
 * @title Marketplace Extended Test Suite
 * @dev Comprehensive tests including unit, fuzz, and integration tests
 */
contract MarketplaceExtendedTest is Test {
    Marketplace public marketplace;
    RecycloToken public token;
    RewardManager public rewardManager;
    
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    address public collector = makeAddr("collector");
    
    uint256 public constant TOKEN_CAP = 100_000_000 * 10**18;
    uint256 public constant INITIAL_TOKENS = 100_000 * 10**18;

    // Events to test
    event ListingCreated(uint256 indexed id, address indexed seller, uint256 quantity, uint256 pricePerUnit, bytes32 metaHash);
    event ListingCancelled(uint256 indexed id);
    event ListingBought(uint256 indexed id, address indexed buyer, uint256 quantity);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy all contracts
        token = new RecycloToken("Recyclo Token", "RECYCLO", TOKEN_CAP, admin);
        rewardManager = new RewardManager(address(token), admin);
        marketplace = new Marketplace(address(token), admin);
        
        // Setup roles
        token.grantMinterRole(address(rewardManager));
        rewardManager.grantMinterRole(minter);
        marketplace.grantListerRole(minter);
        
        vm.stopPrank();
    }

    // ============ UNIT TESTS ============

    /// @dev Test contract deployment and initialization
    function test_Deployment() public view {
        assertEq(address(marketplace.token()), address(token));
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.LISTER_ROLE(), minter));
        assertEq(marketplace.listingCount(), 0);
    }

    /// @dev Test listing creation with valid parameters
    function test_CreateListing_Success() public {
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        assertEq(listingId, 1);
        assertEq(marketplace.listingCount(), 1);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.seller, minter);
        assertEq(listing.quantity, 100);
        assertEq(listing.pricePerUnit, 10 * 10**18);
        assertEq(listing.metaHash, keccak256("metadata"));
        assertTrue(listing.active);
        assertEq(listing.createdAt, block.timestamp);
    }

    /// @dev Test listing creation emits correct event
    function test_CreateListing_EmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit ListingCreated(1, minter, 100, 10 * 10**18, keccak256("metadata"));
        
        vm.prank(minter);
        marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
    }

    /// @dev Test unauthorized users cannot create listings
    function test_CreateListing_UnauthorizedReverts() public {
        vm.prank(user);
        vm.expectRevert();
        marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
    }

    /// @dev Test listing creation with zero quantity reverts
    function test_CreateListing_ZeroQuantityReverts() public {
        vm.prank(minter);
        vm.expectRevert("Marketplace: quantity must be positive");
        marketplace.createListing(0, 10 * 10**18, keccak256("metadata"));
    }

    /// @dev Test listing creation with zero price reverts
    function test_CreateListing_ZeroPriceReverts() public {
        vm.prank(minter);
        vm.expectRevert("Marketplace: price must be positive");
        marketplace.createListing(100, 0, keccak256("metadata"));
    }

    // ============ FUZZ TESTS ============

    /// @dev Fuzz test for listing creation with various quantities and prices
    function testFuzz_CreateListing(
        uint256 quantity,
        uint256 pricePerUnit,
        bytes32 metaHash
    ) public {
        // Bound fuzz inputs to reasonable ranges
        quantity = bound(quantity, 1, 1_000_000);
        pricePerUnit = bound(pricePerUnit, 1, 1000 * 10**18);
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(quantity, pricePerUnit, metaHash);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, quantity);
        assertEq(listing.pricePerUnit, pricePerUnit);
        assertEq(listing.metaHash, metaHash);
    }

    /// @dev Fuzz test for buying partial quantities
    function testFuzz_BuyListing_PartialQuantities(uint256 initialQty, uint256 buyQty) public {
        // Bound inputs to prevent overflow and edge cases
        initialQty = bound(initialQty, 10, 1000);
        buyQty = bound(buyQty, 1, initialQty - 1);
        
        // Setup: Mint tokens to user and create listing
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        uint256 pricePerUnit = 10 * 10**18;
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(initialQty, pricePerUnit, keccak256("metadata"));
        
        // Execute: Buy partial quantity
        _buyListing(user, listingId, buyQty);
        
        // Verify: Listing updated correctly
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, initialQty - buyQty);
        assertTrue(listing.active);
    }

    /// @dev Fuzz test for buying entire listing
    function testFuzz_BuyListing_CompleteQuantity(uint256 quantity) public {
        quantity = bound(quantity, 1, 1000);
        
        // Setup
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        uint256 pricePerUnit = 10 * 10**18;
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(quantity, pricePerUnit, keccak256("metadata"));
        
        // Execute
        _buyListing(user, listingId, quantity);
        
        // Verify: Listing should be inactive when quantity reaches 0
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, 0);
        assertFalse(listing.active);
    }

    // ============ INTEGRATION TESTS ============

    /// @dev Test complete flow: mint tokens -> create listing -> buy listing
    function test_Integration_CompleteFlow() public {
        uint256 listingQty = 100;
        uint256 pricePerUnit = 10 * 10**18;
        uint256 buyQty = 50;

        // Step 1: Mint tokens to user through the helper (which sets approval)
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        assertEq(token.balanceOf(user), INITIAL_TOKENS);

        // Step 2: Create listing
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(listingQty, pricePerUnit, keccak256("listing-metadata"));
        
        // Step 3: User buys listing using helper function
        _buyListing(user, listingId, buyQty);

        // Verify final state
        uint256 totalCost = buyQty * pricePerUnit;
        assertEq(token.balanceOf(user), INITIAL_TOKENS - totalCost);
        assertEq(token.balanceOf(minter), totalCost); // Seller received payment
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, listingQty - buyQty);
        assertTrue(listing.active);
    }

    /// @dev Test multiple users interacting with marketplace
    function test_Integration_MultipleUsers() public {
        // Setup: Mint tokens to multiple users using helper
        _mintTokensToUser(user, INITIAL_TOKENS);
        _mintTokensToUser(user2, INITIAL_TOKENS);
        
        uint256 listingQty = 200;
        uint256 pricePerUnit = 5 * 10**18;
        uint256 user1BuyQty = 100;
        uint256 user2BuyQty = 100;
        
        // Create listing
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(listingQty, pricePerUnit, keccak256("metadata"));
        
        // User 1 buys some items
        _buyListing(user, listingId, user1BuyQty);
        
        // User 2 buys remaining items
        _buyListing(user2, listingId, user2BuyQty);
        
        // Verify listing is now inactive and empty
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, 0);
        assertFalse(listing.active);
        
        // Verify token distribution
        uint256 totalCost = (user1BuyQty + user2BuyQty) * pricePerUnit;
        assertEq(token.balanceOf(minter), totalCost); // Full payment received
    }

    /// @dev Test role management integration
    function test_Integration_RoleManagement() public {
        // Admin grants lister role to new user
        vm.prank(admin);
        marketplace.grantListerRole(user);
        
        // New user can now create listings
        vm.prank(user);
        uint256 listingId = marketplace.createListing(50, 10 * 10**18, keccak256("new-lister"));
        
        assertEq(listingId, 1);
        assertEq(marketplace.listingCount(), 1);
    }

    // ============ EDGE CASE TESTS ============

    /// @dev Test buying from inactive listing reverts
    function test_BuyListing_InactiveReverts() public {
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        // Cancel listing first
        vm.prank(minter);
        marketplace.cancelListing(listingId);
        
        // Try to buy from cancelled listing - call buyListing directly with proper prank
        vm.prank(user);
        vm.expectRevert("Marketplace: listing not active");
        marketplace.buyListing(listingId, 10);
    }

    /// @dev Test buying more than available quantity reverts
    function test_BuyListing_ExcessQuantityReverts() public {
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        // Try to buy more than available - call buyListing directly with proper prank
        vm.prank(user);
        vm.expectRevert("Marketplace: insufficient quantity");
        marketplace.buyListing(listingId, 101);
    }

    /// @dev Test buying with insufficient token allowance reverts
    function test_BuyListing_InsufficientAllowanceReverts() public {
        // Mint tokens but DON'T set approval - use the special helper
        _mintTokensWithoutApproval(user, INITIAL_TOKENS);
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        // User has tokens but no allowance - call buyListing directly
        vm.prank(user);
        // Expect ERC20 insufficient allowance revert (not our custom error)
        vm.expectRevert();
        marketplace.buyListing(listingId, 10);
    }

    /// @dev Test cancel listing by seller
    function test_CancelListing_BySeller() public {
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        vm.prank(minter);
        marketplace.cancelListing(listingId);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.active);
    }

    /// @dev Test cancel listing by admin
    function test_CancelListing_ByAdmin() public {
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        vm.prank(admin);
        marketplace.cancelListing(listingId);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.active);
    }

    /// @dev Test unauthorized user cannot cancel listing
    function test_CancelListing_UnauthorizedReverts() public {
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        vm.prank(user);
        vm.expectRevert("Marketplace: not authorized");
        marketplace.cancelListing(listingId);
    }

    /// @dev Test cancel already cancelled listing reverts
    function test_CancelListing_AlreadyCancelledReverts() public {
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        vm.prank(minter);
        marketplace.cancelListing(listingId);
        
        vm.prank(minter);
        vm.expectRevert("Marketplace: listing not active");
        marketplace.cancelListing(listingId);
    }

    // ============ GAS OPTIMIZATION TESTS ============

    /// @dev Test gas usage for common operations
    function test_Gas_CreateListing() public {
        vm.prank(minter);
        uint256 gasBefore = gasleft();
        marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for createListing:", gasUsed);
        assertLt(gasUsed, 200000);
    }

    /// @dev Test gas usage for buying listings
    function test_Gas_BuyListing() public {
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        uint256 gasBefore = gasleft();
        _buyListing(user, listingId, 10);
        uint256 gasUsed = gasBefore - gasleft();
        
        console.log("Gas used for buyListing:", gasUsed);
        assertLt(gasUsed, 150000);
    }

    // ============ ADDITIONAL SECURITY TESTS ============

    /// @dev Test reentrancy protection (basic check)
    function test_NoReentrancy() public {
        _mintTokensToUser(user, INITIAL_TOKENS);
        
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("metadata"));
        
        // Should complete without reentrancy issues
        _buyListing(user, listingId, 10);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, 90);
    }

    /// @dev Test that listing IDs increment correctly
    function test_ListingIdIncrement() public {
        vm.prank(minter);
        uint256 listingId1 = marketplace.createListing(10, 10 * 10**18, keccak256("1"));
        
        vm.prank(minter);
        uint256 listingId2 = marketplace.createListing(20, 20 * 10**18, keccak256("2"));
        
        vm.prank(minter);
        uint256 listingId3 = marketplace.createListing(30, 30 * 10**18, keccak256("3"));
        
        assertEq(listingId1, 1);
        assertEq(listingId2, 2);
        assertEq(listingId3, 3);
        assertEq(marketplace.listingCount(), 3);
    }

    /// @dev Test that getListing returns correct data for non-existent listings
    function test_GetListing_NonExistent() public {
        Marketplace.Listing memory listing = marketplace.getListing(999);
        
        assertEq(listing.seller, address(0));
        assertEq(listing.quantity, 0);
        assertEq(listing.pricePerUnit, 0);
        assertEq(listing.metaHash, bytes32(0));
        assertFalse(listing.active);
        assertEq(listing.createdAt, 0);
    }

    // ============ HELPER FUNCTIONS ============

    /// @dev Helper to mint tokens to a user through the reward system
    function _mintTokensToUser(address userAddress, uint256 amount) internal {
        bytes32 metadataHash = keccak256("test-mint");
        vm.prank(minter);
        rewardManager.confirmDropOff(userAddress, amount, collector, metadataHash);
        
        // Approve marketplace for spending (max approval for simplicity)
        vm.prank(userAddress);
        token.approve(address(marketplace), type(uint256).max);
    }

    /// @dev Helper function to handle buying listings with proper setup
    function _buyListing(address buyer, uint256 listingId, uint256 quantity) internal {
        // Get listing details to calculate cost
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        uint256 totalCost = quantity * listing.pricePerUnit;
        
        // Ensure buyer has sufficient balance and allowance
        uint256 buyerBalance = token.balanceOf(buyer);
        require(buyerBalance >= totalCost, "Insufficient buyer balance");
        
        uint256 allowance = token.allowance(buyer, address(marketplace));
        require(allowance >= totalCost, "Insufficient allowance");
        
        // Execute the buy with proper prank
        vm.prank(buyer);
        marketplace.buyListing(listingId, quantity);
    }

    /// @dev Helper function for revert tests - sets up tokens but NO approval
    function _mintTokensWithoutApproval(address userAddress, uint256 amount) internal {
        bytes32 metadataHash = keccak256("test-mint");
        vm.prank(minter);
        rewardManager.confirmDropOff(userAddress, amount, collector, metadataHash);
        // Note: No approval is set here
    }
}