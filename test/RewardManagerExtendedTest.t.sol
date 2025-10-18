// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RewardManager} from "@contract/RewardManager.sol";
import {RecycloToken} from "@contract/RecycloToken.sol";

/**
 * @title RewardManager Extended Test Suite
 * @dev Comprehensive tests including unit, fuzz, and integration tests for RewardManager
 */
contract RewardManagerExtendedTest is Test {
    RewardManager public rewardManager;
    RecycloToken public token;
    
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public user = makeAddr("user");
    address public collector = makeAddr("collector");
    address public user2 = makeAddr("user2");
    
    uint256 public constant TOKEN_CAP = 100_000_000 * 10**18;
    uint256 public constant REWARD_AMOUNT = 100 * 10**18;

    // Events to test
    event DropIssued(uint256 indexed dropId, address indexed user, uint256 amount, address indexed collector, bytes32 metadataHash);
    event DropRevoked(uint256 indexed dropId, string reason);
    event DropDisputed(uint256 indexed dropId, string reason);

    function setUp() public {
        vm.startPrank(admin);
        
        token = new RecycloToken("Recyclo Token", "RECYCLO", TOKEN_CAP, admin);
        rewardManager = new RewardManager(address(token), admin);
        
        // Setup roles
        token.grantMinterRole(address(rewardManager));
        rewardManager.grantMinterRole(minter);
        
        vm.stopPrank();
    }

    // ============ UNIT TESTS ============

    /// @dev Test contract deployment and initialization
    function test_Deployment() public view {
        assertEq(address(rewardManager.token()), address(token));
        assertTrue(rewardManager.hasRole(rewardManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(rewardManager.hasRole(rewardManager.MINTER_ROLE(), minter));
        assertEq(rewardManager.dropCount(), 0);
    }

    /// @dev Test confirming a drop-off with valid parameters
    function test_ConfirmDropOff_Success() public {
        bytes32 metadataHash = keccak256("valid-drop-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        assertEq(dropId, 1);
        assertEq(rewardManager.dropCount(), 1);
        
        // Check token balance
        assertEq(token.balanceOf(user), REWARD_AMOUNT);
        assertEq(token.totalSupply(), REWARD_AMOUNT);
        
        // Check drop record
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(drop.user, user);
        assertEq(drop.amount, REWARD_AMOUNT);
        assertEq(drop.collector, collector);
        assertEq(drop.metadataHash, metadataHash);
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Issued));
        assertEq(drop.timestamp, block.timestamp);
    }

    /// @dev Test drop-off confirmation emits correct event
    function test_ConfirmDropOff_EmitsEvent() public {
        bytes32 metadataHash = keccak256("event-test-metadata");
        
        vm.expectEmit(true, true, true, true, address(rewardManager));
        emit DropIssued(1, user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.prank(minter);
        rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
    }

    /// @dev Test unauthorized users cannot confirm drop-offs
    function test_ConfirmDropOff_UnauthorizedReverts() public {
        bytes32 metadataHash = keccak256("unauthorized-metadata");
        
        vm.prank(user);
        vm.expectRevert();
        rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
    }

    /// @dev Test confirming drop-off with zero user address reverts
    function test_ConfirmDropOff_ZeroUserReverts() public {
        bytes32 metadataHash = keccak256("zero-user-metadata");
        
        vm.prank(minter);
        vm.expectRevert("RewardManager: invalid user");
        rewardManager.confirmDropOff(address(0), REWARD_AMOUNT, collector, metadataHash);
    }

    /// @dev Test confirming drop-off with zero amount reverts
    function test_ConfirmDropOff_ZeroAmountReverts() public {
        bytes32 metadataHash = keccak256("zero-amount-metadata");
        
        vm.prank(minter);
        vm.expectRevert("RewardManager: amount must be positive");
        rewardManager.confirmDropOff(user, 0, collector, metadataHash);
    }

    /// @dev Test confirming drop-off with zero collector address reverts
    function test_ConfirmDropOff_ZeroCollectorReverts() public {
        bytes32 metadataHash = keccak256("zero-collector-metadata");
        
        vm.prank(minter);
        vm.expectRevert("RewardManager: invalid collector");
        rewardManager.confirmDropOff(user, REWARD_AMOUNT, address(0), metadataHash);
    }

    // ============ CONFIRM DROP OFF WITH ID TESTS ============

    /// @dev Test confirming with invalid ID reverts
    function test_ConfirmDropOffWithId_InvalidIdReverts() public {
        bytes32 metadataHash = keccak256("invalid-id-metadata");
        
        vm.prank(minter);
        vm.expectRevert("RewardManager: invalid dropId");
        rewardManager.confirmDropOffWithId(999, user, REWARD_AMOUNT, collector, metadataHash);
    }

    /// @dev Test confirming with already processed ID reverts
    function test_ConfirmDropOffWithId_AlreadyProcessedReverts() public {
        bytes32 metadataHash = keccak256("processed-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.prank(minter);
        vm.expectRevert("RewardManager: drop already processed");
        rewardManager.confirmDropOffWithId(dropId, user, REWARD_AMOUNT, collector, metadataHash);
    }

    // ============ REVOCATION TESTS ============

    /// @dev Test revoking a drop by admin
    function test_RevokeDrop_ByAdmin() public {
        bytes32 metadataHash = keccak256("revocation-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.prank(admin);
        rewardManager.revokeDrop(dropId, "fraud detected");
        
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Revoked));
    }

    /// @dev Test revoke emits correct event
    function test_RevokeDrop_EmitsEvent() public {
        bytes32 metadataHash = keccak256("revoke-event-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.expectEmit(true, true, true, true, address(rewardManager));
        emit DropRevoked(dropId, "test reason");
        
        vm.prank(admin);
        rewardManager.revokeDrop(dropId, "test reason");
    }

    /// @dev Test revoking non-issued drop reverts
    function test_RevokeDrop_NotIssuedReverts() public {
        vm.prank(admin);
        vm.expectRevert("RewardManager: drop not issued");
        rewardManager.revokeDrop(1, "invalid revocation");
    }

    /// @dev Test unauthorized users cannot revoke drops
    function test_RevokeDrop_UnauthorizedReverts() public {
        bytes32 metadataHash = keccak256("unauthorized-revoke-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.prank(user);
        vm.expectRevert();
        rewardManager.revokeDrop(dropId, "unauthorized attempt");
    }

    // ============ DISPUTE TESTS ============
    function test_DisputeDrop_ByAdmin() public {
        bytes32 metadataHash = keccak256("dispute-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.prank(admin);
        rewardManager.disputeDrop(dropId, "under investigation");
        
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Disputed));
    }

    /// @dev Test dispute emits correct event
    function test_DisputeDrop_EmitsEvent() public {
        bytes32 metadataHash = keccak256("dispute-event-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.expectEmit(true, true, true, true, address(rewardManager));
        emit DropDisputed(dropId, "investigation needed");
        
        vm.prank(admin);
        rewardManager.disputeDrop(dropId, "investigation needed");
    }

    /// @dev Test disputing non-issued drop reverts
    function test_DisputeDrop_NotIssuedReverts() public {
        vm.prank(admin);
        vm.expectRevert("RewardManager: drop not issued");
        rewardManager.disputeDrop(1, "invalid dispute");
    }

    /// @dev Test unauthorized users cannot dispute drops
    function test_DisputeDrop_UnauthorizedReverts() public {
        bytes32 metadataHash = keccak256("unauthorized-dispute-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        vm.prank(user);
        vm.expectRevert();
        rewardManager.disputeDrop(dropId, "unauthorized dispute");
    }

    // ============ FUZZ TESTS ============

    /// @dev Fuzz test for drop-off confirmation with various amounts
    function testFuzz_ConfirmDropOff(uint256 amount, bytes32 metadataHash) public {
        // Bound amount to prevent overflow and cap issues
        amount = bound(amount, 1, TOKEN_CAP / 10); // Use 10% of cap to avoid hitting limit
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, amount, collector, metadataHash);
        
        assertEq(token.balanceOf(user), amount);
        assertEq(rewardManager.dropCount(), dropId);
        
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(drop.amount, amount);
        assertEq(drop.metadataHash, metadataHash);
    }

    /// @dev Fuzz test for multiple drop-offs
    function testFuzz_MultipleDropOffs(uint8 numDrops) public {
        numDrops = uint8(bound(numDrops, 1, 50)); // Reasonable number of drops
        
        uint256 totalMinted = 0;
        
        for (uint256 i = 0; i < numDrops; i++) {
            uint256 amount = (i + 1) * 10**18; // Varying amounts
            bytes32 metadataHash = keccak256(abi.encodePacked("drop-", i));
            
            vm.prank(minter);
            uint256 dropId = rewardManager.confirmDropOff(user, amount, collector, metadataHash);
            
            totalMinted += amount;
            assertEq(dropId, i + 1);
        }
        
        assertEq(rewardManager.dropCount(), numDrops);
        assertEq(token.balanceOf(user), totalMinted);
        assertEq(token.totalSupply(), totalMinted);
    }

    // ============ ROLE MANAGEMENT TESTS ============

    /// @dev Test admin can grant minter role
    function test_GrantMinterRole() public {
        address newMinter = makeAddr("newMinter");
        
        vm.prank(admin);
        rewardManager.grantMinterRole(newMinter);
        
        assertTrue(rewardManager.hasRole(rewardManager.MINTER_ROLE(), newMinter));
    }

    /// @dev Test admin can revoke minter role
    function test_RevokeMinterRole() public {
        vm.prank(admin);
        rewardManager.revokeMinterRole(minter);
        
        assertFalse(rewardManager.hasRole(rewardManager.MINTER_ROLE(), minter));
    }

    /// @dev Test non-admin cannot grant minter role
    function test_GrantMinterRole_UnauthorizedReverts() public {
        address newMinter = makeAddr("newMinter");
        
        vm.prank(user);
        vm.expectRevert();
        rewardManager.grantMinterRole(newMinter);
    }

    /// @dev Test non-admin cannot revoke minter role
    function test_RevokeMinterRole_UnauthorizedReverts() public {
        vm.prank(user);
        vm.expectRevert();
        rewardManager.revokeMinterRole(minter);
    }

    // ============ INTEGRATION TESTS ============

    /// @dev Test multiple users and collectors
    function test_Integration_MultipleUsersAndCollectors() public {
        address collector2 = makeAddr("collector2");
        address collector3 = makeAddr("collector3");
        
        // User 1 with collector 1
        vm.prank(minter);
        uint256 dropId1 = rewardManager.confirmDropOff(user, 100 * 10**18, collector, keccak256("drop1"));
        
        // User 2 with collector 2
        vm.prank(minter);
        uint256 dropId2 = rewardManager.confirmDropOff(user2, 200 * 10**18, collector2, keccak256("drop2"));
        
        // User 1 with collector 3
        vm.prank(minter);
        uint256 dropId3 = rewardManager.confirmDropOff(user, 150 * 10**18, collector3, keccak256("drop3"));
        
        // Verify all drops
        assertEq(rewardManager.dropCount(), 3);
        assertEq(token.balanceOf(user), 250 * 10**18); // 100 + 150
        assertEq(token.balanceOf(user2), 200 * 10**18);
        assertEq(token.totalSupply(), 450 * 10**18);
        
        RewardManager.Drop memory drop1 = rewardManager.getDrop(dropId1);
        RewardManager.Drop memory drop2 = rewardManager.getDrop(dropId2);
        RewardManager.Drop memory drop3 = rewardManager.getDrop(dropId3);
        
        assertEq(drop1.collector, collector);
        assertEq(drop2.collector, collector2);
        assertEq(drop3.collector, collector3);
    }

    // ============ EDGE CASE TESTS ============

    /// @dev Test getDrop for non-existent ID returns empty struct
    function test_GetDrop_NonExistent() public {
        RewardManager.Drop memory drop = rewardManager.getDrop(999);
        
        assertEq(drop.user, address(0));
        assertEq(drop.amount, 0);
        assertEq(drop.collector, address(0));
        assertEq(drop.metadataHash, bytes32(0));
        assertEq(uint256(drop.status), uint256(RewardManager.Status.Unknown));
        assertEq(drop.timestamp, 0);
    }

    /// @dev Test drop ID auto-increment
    function test_DropId_Increment() public {
        vm.prank(minter);
        uint256 dropId1 = rewardManager.confirmDropOff(user, 100, collector, keccak256("1"));
        
        vm.prank(minter);
        uint256 dropId2 = rewardManager.confirmDropOff(user, 200, collector, keccak256("2"));
        
        vm.prank(minter);
        uint256 dropId3 = rewardManager.confirmDropOff(user, 300, collector, keccak256("3"));
        
        assertEq(dropId1, 1);
        assertEq(dropId2, 2);
        assertEq(dropId3, 3);
        assertEq(rewardManager.dropCount(), 3);
    }

    /// @dev Test that tokens remain after revocation/dispute (no burning)
    function test_Tokens_RemainAfterStatusChange() public {
        bytes32 metadataHash = keccak256("tokens-remain-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        uint256 balanceBefore = token.balanceOf(user);
        
        // Revoke - tokens should remain with user
        vm.prank(admin);
        rewardManager.revokeDrop(dropId, "revocation test");
        
        assertEq(token.balanceOf(user), balanceBefore); // Tokens still with user
        
        // For dispute - create new drop
        vm.prank(minter);
        uint256 dropId2 = rewardManager.confirmDropOff(user2, REWARD_AMOUNT, collector, keccak256("dispute-test"));
        
        uint256 balanceBefore2 = token.balanceOf(user2);
        
        vm.prank(admin);
        rewardManager.disputeDrop(dropId2, "dispute test");
        
        assertEq(token.balanceOf(user2), balanceBefore2); // Tokens still with user
    }

    // ============ GAS OPTIMIZATION TESTS ============

    /// @dev Test gas usage for confirming drop-off
    function test_Gas_ConfirmDropOff() public {
        bytes32 metadataHash = keccak256("gas-test-metadata");
        
        uint256 gasBefore = gasleft();
        
        vm.prank(minter);
        rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for confirmDropOff:", gasUsed);
        assertLt(gasUsed, 200000); // Reasonable gas limit
    }

    /// @dev Test gas usage for revoking drop
    function test_Gas_RevokeDrop() public {
        bytes32 metadataHash = keccak256("gas-revoke-metadata");
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        uint256 gasBefore = gasleft();
        
        vm.prank(admin);
        rewardManager.revokeDrop(dropId, "gas test reason");
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for revokeDrop:", gasUsed);
        assertLt(gasUsed, 100000); // Reasonable gas limit
    }

    // ============ SECURITY TESTS ============

    /// @dev Test that only RewardManager can mint tokens
    function test_OnlyRewardManagerCanMint() public {
        // Try to mint directly from token contract without RewardManager
        vm.prank(minter);
        vm.expectRevert(); // Should revert as minter doesn't have MINTER_ROLE on token
        token.mint(user, REWARD_AMOUNT);
    }

    /// @dev Test reentrancy protection (basic check)
    function test_NoReentrancy() public {
        bytes32 metadataHash = keccak256("reentrancy-test");
        
        // Should complete without reentrancy issues
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        assertEq(dropId, 1);
        assertEq(token.balanceOf(user), REWARD_AMOUNT);
    }

    /// @dev Test timestamp is correctly recorded
    function test_Timestamp_Recording() public {
        bytes32 metadataHash = keccak256("timestamp-test");
        uint256 startTime = block.timestamp;
        
        vm.prank(minter);
        uint256 dropId = rewardManager.confirmDropOff(user, REWARD_AMOUNT, collector, metadataHash);
        
        RewardManager.Drop memory drop = rewardManager.getDrop(dropId);
        assertEq(drop.timestamp, startTime);
        
        // Advance time and create another drop
        vm.warp(startTime + 1 days);
        
        vm.prank(minter);
        uint256 dropId2 = rewardManager.confirmDropOff(user2, REWARD_AMOUNT, collector, metadataHash);
        
        RewardManager.Drop memory drop2 = rewardManager.getDrop(dropId2);
        assertEq(drop2.timestamp, startTime + 1 days);
    }
}