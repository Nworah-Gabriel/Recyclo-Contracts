// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RecycloToken} from "@contract/RecycloToken.sol";
import {RewardManager} from "@contract/RewardManager.sol";
import {Marketplace} from "@contract/Marketplace.sol";

/**
 * @title Recyclo Ecosystem Integration Test Suite
 * @dev Tests the integration between RecycloToken, RewardManager, and Marketplace
 */
contract RecycloTest is Test {
    RecycloToken public token;
    RewardManager public rewardManager;
    Marketplace public marketplace;
    
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public user = makeAddr("user");
    address public collector = makeAddr("collector");
    
    uint256 public constant TOKEN_CAP = 100_000_000 * 10**18;

    function setUp() public {
        vm.startPrank(admin);
        
        token = new RecycloToken("Recyclo Token", "RECYCLO", TOKEN_CAP, admin);
        rewardManager = new RewardManager(address(token), admin);
        marketplace = new Marketplace(address(token), admin);
        
        // Setup roles
        token.grantMinterRole(address(rewardManager));
        rewardManager.grantMinterRole(minter);
        marketplace.grantListerRole(minter);
        
        vm.stopPrank();
    }

    // ============ TOKEN TESTS ============

    function test_TokenDeployment() public view {
        assertEq(token.name(), "Recyclo Token");
        assertEq(token.symbol(), "RECYCLO");
        assertEq(token.cap(), TOKEN_CAP);
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Token_CapEnforcement() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 excessiveAmount = TOKEN_CAP + 1;
        
        vm.prank(minter);
        vm.expectRevert("RecycloToken: cap exceeded");
        rewardManager.confirmDropOff(user, excessiveAmount, collector, metadataHash);
    }

    // ============ REWARD MANAGER TESTS ============

    function test_RewardManager_MintTokens() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 100 * 10**18;
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, amount, collector, metadataHash);
        
        // Check token balance
        assertEq(token.balanceOf(user), amount);
        assertEq(token.totalSupply(), amount);
        
        // Use getDrop function to get the full struct
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(drop.user, user);
        assertEq(drop.amount, amount);
        assertEq(drop.collector, collector);
        assertEq(drop.metadataHash, metadataHash);
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Issued));
    }

    function test_RewardManager_OnlyMinterCanMint() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 100 * 10**18;
        
        // Regular user shouldn't be able to mint
        vm.prank(user); 
        vm.expectRevert();
        rewardManager.confirmDropOff(user, amount, collector, metadataHash);
    }

    function test_RewardManager_RevokeDrop() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 100 * 10**18;
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, amount, collector, metadataHash);
        
        vm.prank(admin);
        rewardManager.revokeDrop(dropId, "fraud detected");
        
        // Use getDrop function
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Revoked));
    }

    function test_RewardManager_DropCount() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 100 * 10**18;
        
        assertEq(rewardManager.dropCount(), 0);
        
        vm.prank(minter);
        rewardManager.confirmDropOff(user, amount, collector, metadataHash);
        
        assertEq(rewardManager.dropCount(), 1);
    }

    function test_RewardManager_IndividualFieldAccess() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 100 * 10**18;
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, amount, collector, metadataHash);
        
        // Use tuple destructuring for auto-generated getters
        (address dropUser, uint256 dropAmount, , address dropCollector, , ) = rewardManager.drops(dropId);
        
        assertEq(dropUser, user);
        assertEq(dropAmount, amount);
        assertEq(dropCollector, collector);
    }

    function test_EventEmissions() public {
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 100 * 10**18;
        
        vm.expectEmit(true, true, true, true, address(rewardManager));
        emit RewardManager.DropIssued(1, user, amount, collector, metadataHash);
        
        vm.prank(minter);
        rewardManager.confirmDropOff(user, amount, collector, metadataHash);
    }

    // ============ MARKETPLACE TESTS ============

    function test_Marketplace_CreateAndBuyListing() public {
        // First mint some tokens to user
        bytes32 metadataHash = keccak256("test-metadata");
        uint256 amount = 1000 * 10**18;
        
        vm.prank(minter);
        rewardManager.confirmDropOff(user, amount, collector, metadataHash);
        
        // Create listing as minter
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("listing-metadata"));
        
        // User buys from listing
        vm.prank(user);
        token.approve(address(marketplace), 1000 * 10**18);
        
        vm.prank(user);
        marketplace.buyListing(listingId, 10);
        
        // Use getListing function to get the full struct
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, 90);
        assertTrue(listing.active);
    }

    function test_Marketplace_CancelListing() public {
        // Create listing
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("listing-metadata"));
        
        // Cancel listing
        vm.prank(minter);
        marketplace.cancelListing(listingId);
        
        // Use getListing function
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.active);
    }

    function test_Marketplace_IndividualFieldAccess() public {
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(100, 10 * 10**18, keccak256("listing-metadata"));
        
        // Use tuple destructuring for auto-generated getters
        (address seller, uint256 quantity, uint256 pricePerUnit, bytes32 metaHash, bool active, ) = marketplace.listings(listingId);
        
        assertEq(seller, minter);
        assertEq(quantity, 100);
        assertEq(pricePerUnit, 10 * 10**18);
        assertTrue(active);
    }

    // ============ INTEGRATION TESTS ============

    /// @dev Test complete ecosystem flow
    function test_Integration_FullEcosystemFlow() public {
        // Step 1: User earns tokens through reward manager
        bytes32 dropMetadata = keccak256("recycling-drop");
        uint256 earnedAmount = 500 * 10**18;
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, earnedAmount, collector, dropMetadata);
        
        assertEq(token.balanceOf(user), earnedAmount);
        assertEq(rewardManager.dropCount(), 1);

        // Step 2: User creates a marketplace listing (if they had lister role)
        vm.prank(minter);
        uint256 listingId = marketplace.createListing(50, 5 * 10**18, keccak256("marketplace-item"));
        
        // Step 3: User buys from marketplace
        vm.prank(user);
        token.approve(address(marketplace), earnedAmount);
        
        uint256 buyQuantity = 10;
        vm.prank(user);
        marketplace.buyListing(listingId, buyQuantity);
        
        // Verify final state
        uint256 spentAmount = buyQuantity * 5 * 10**18;
        assertEq(token.balanceOf(user), earnedAmount - spentAmount);
        assertEq(token.balanceOf(minter), spentAmount);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.quantity, 50 - buyQuantity);
        assertTrue(listing.active);
        
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Issued));
    }
}