// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {RecycloToken} from "@contract/RecycloToken.sol";

/**
 * @title RecycloToken Extended Test Suite
 * @dev Comprehensive tests including unit, fuzz, and integration tests for RecycloToken
 */
contract RecycloTokenExtendedTest is Test {
    RecycloToken public token;
    
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public burner = makeAddr("burner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    
    uint256 public constant TOKEN_CAP = 100_000_000 * 10**18;
    uint256 public constant INITIAL_MINT_AMOUNT = 10_000 * 10**18;

    // Events to test
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    function setUp() public {
        vm.startPrank(admin);
        
        token = new RecycloToken("Recyclo Token", "RECYCLO", TOKEN_CAP, admin);
        
        // Setup roles for testing
        token.grantMinterRole(minter);
        token.grantBurnerRole(burner);
        
        vm.stopPrank();
    }

    // ============ UNIT TESTS ============

    /// @dev Test contract deployment and initialization
    function test_Deployment() public view {
        assertEq(token.name(), "Recyclo Token");
        assertEq(token.symbol(), "RECYCLO");
        assertEq(token.cap(), TOKEN_CAP);
        assertEq(token.totalSupply(), 0);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.BURNER_ROLE(), burner));
    }

    /// @dev Test token minting by authorized minter
    function test_Mint_ByMinter() public {
        vm.prank(minter);
        token.mint(user, INITIAL_MINT_AMOUNT);
        
        assertEq(token.balanceOf(user), INITIAL_MINT_AMOUNT);
        assertEq(token.totalSupply(), INITIAL_MINT_AMOUNT);
    }

    /// @dev Test minting emits correct event
    function test_Mint_EmitsEvent() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit TokensMinted(user, INITIAL_MINT_AMOUNT);
        
        vm.prank(minter);
        token.mint(user, INITIAL_MINT_AMOUNT);
    }

    /// @dev Test unauthorized users cannot mint tokens
    function test_Mint_UnauthorizedReverts() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, INITIAL_MINT_AMOUNT);
    }

    /// @dev Test token burning by authorized burner
    function test_Burn_ByBurner() public {
        // First mint tokens to user
        vm.prank(minter);
        token.mint(user, INITIAL_MINT_AMOUNT);
        
        // Then burn some tokens
        uint256 burnAmount = 1_000 * 10**18;
        vm.prank(burner);
        token.burn(user, burnAmount);
        
        assertEq(token.balanceOf(user), INITIAL_MINT_AMOUNT - burnAmount);
        assertEq(token.totalSupply(), INITIAL_MINT_AMOUNT - burnAmount);
    }

    /// @dev Test burning emits correct event
    function test_Burn_EmitsEvent() public {
        vm.prank(minter);
        token.mint(user, INITIAL_MINT_AMOUNT);
        
        uint256 burnAmount = 1_000 * 10**18;
        vm.expectEmit(true, true, true, true, address(token));
        emit TokensBurned(user, burnAmount);
        
        vm.prank(burner);
        token.burn(user, burnAmount);
    }

    /// @dev Test unauthorized users cannot burn tokens
    function test_Burn_UnauthorizedReverts() public {
        vm.prank(minter);
        token.mint(user, INITIAL_MINT_AMOUNT);
        
        vm.prank(user);
        vm.expectRevert();
        token.burn(user, 1000);
    }

    /// @dev Test token cap enforcement
    function test_Mint_CapEnforcement() public {
        uint256 excessiveAmount = TOKEN_CAP + 1;
        
        vm.prank(minter);
        vm.expectRevert("RecycloToken: cap exceeded");
        token.mint(user, excessiveAmount);
    }

    /// @dev Test minting up to but not exceeding cap
    function test_Mint_UpToCap() public {
        vm.prank(minter);
        token.mint(user, TOKEN_CAP);
        
        assertEq(token.balanceOf(user), TOKEN_CAP);
        assertEq(token.totalSupply(), TOKEN_CAP);
    }

    // ============ FUZZ TESTS ============

    /// @dev Fuzz test for minting various amounts
    function testFuzz_Mint(uint256 amount) public {
        // Bound amount to prevent overflow and cap issues
        amount = bound(amount, 1, TOKEN_CAP);
        
        vm.prank(minter);
        token.mint(user, amount);
        
        assertEq(token.balanceOf(user), amount);
        assertEq(token.totalSupply(), amount);
    }

    /// @dev Fuzz test for minting and burning
    function testFuzz_MintAndBurn(uint256 mintAmount, uint256 burnAmount) public {
        // Bound amounts to prevent underflow and cap issues
        mintAmount = bound(mintAmount, 1000, TOKEN_CAP / 2);
        burnAmount = bound(burnAmount, 1, mintAmount);
        
        // Mint tokens
        vm.prank(minter);
        token.mint(user, mintAmount);
        
        // Burn some tokens
        vm.prank(burner);
        token.burn(user, burnAmount);
        
        assertEq(token.balanceOf(user), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    // ============ ROLE MANAGEMENT TESTS ============

    /// @dev Test admin can grant minter role
    function test_GrantMinterRole() public {
        vm.prank(admin);
        token.grantMinterRole(user);
        
        assertTrue(token.hasRole(token.MINTER_ROLE(), user));
    }

    /// @dev Test admin can grant burner role
    function test_GrantBurnerRole() public {
        vm.prank(admin);
        token.grantBurnerRole(user);
        
        assertTrue(token.hasRole(token.BURNER_ROLE(), user));
    }

    /// @dev Test admin can revoke minter role
    function test_RevokeMinterRole() public {
        // grant admin the role
        vm.prank(admin);
        token.grantMinterRole(user);
        
        // Revoke the role
        vm.prank(admin);
        token.revokeMinterRole(user);
        
        assertFalse(token.hasRole(token.MINTER_ROLE(), user));
    }

    /// @dev Test admin can revoke burner role
    function test_RevokeBurnerRole() public {
        // First grant the role
        vm.prank(admin);
        token.grantBurnerRole(user);
        
        // Then revoke it
        vm.prank(admin);
        token.revokeBurnerRole(user);
        
        assertFalse(token.hasRole(token.BURNER_ROLE(), user));
    }

    /// @dev Test non-admin cannot grant roles
    function test_GrantRole_UnauthorizedReverts() public {
        vm.prank(user);
        vm.expectRevert();
        token.grantMinterRole(user2);
    }

    /// @dev Test non-admin cannot revoke roles
    function test_RevokeRole_UnauthorizedReverts() public {
        vm.prank(admin);
        token.grantMinterRole(user);
        
        vm.prank(user2);
        vm.expectRevert();
        token.revokeMinterRole(user);
    }

    // ============ INTEGRATION TESTS ============

    /// @dev Test complete token lifecycle: mint -> transfer -> burn
    function test_Integration_TokenLifecycle() public {
        uint256 mintAmount = 5_000 * 10**18;
        uint256 transferAmount = 2_000 * 10**18;
        uint256 burnAmount = 1_000 * 10**18;

        // Step 1: Mint tokens to user
        vm.prank(minter);
        token.mint(user, mintAmount);
        assertEq(token.balanceOf(user), mintAmount);

        // Step 2: User transfers tokens to another user
        vm.prank(user);
        token.transfer(user2, transferAmount);
        assertEq(token.balanceOf(user), mintAmount - transferAmount);
        assertEq(token.balanceOf(user2), transferAmount);

        // Step 3: Burn some tokens from user
        vm.prank(burner);
        token.burn(user, burnAmount);
        assertEq(token.balanceOf(user), mintAmount - transferAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    /// @dev Test multiple minters and burners
    function test_Integration_MultipleMintersBurners() public {
        address minter2 = makeAddr("minter2");
        address burner2 = makeAddr("burner2");
        
        // Grant roles to additional accounts
        vm.prank(admin);
        token.grantMinterRole(minter2);
        
        vm.prank(admin);
        token.grantBurnerRole(burner2);

        // Minter 1 mints to user
        vm.prank(minter);
        token.mint(user, 1000 * 10**18);
        
        // Minter 2 mints to user2
        vm.prank(minter2);
        token.mint(user2, 2000 * 10**18);
        
        assertEq(token.totalSupply(), 3000 * 10**18);

        // Burner 1 burns from user
        vm.prank(burner);
        token.burn(user, 500 * 10**18);
        
        // Burner 2 burns from user2
        vm.prank(burner2);
        token.burn(user2, 1000 * 10**18);
        
        assertEq(token.totalSupply(), 1500 * 10**18);
    }

    // ============ EDGE CASE TESTS ============

    /// @dev Test minting zero amount
    function test_Mint_ZeroAmount() public {
        vm.prank(minter);
        token.mint(user, 0);
        
        assertEq(token.balanceOf(user), 0);
        assertEq(token.totalSupply(), 0);
    }

    /// @dev Test burning zero amount
    function test_Burn_ZeroAmount() public {
        vm.prank(minter);
        token.mint(user, 1000);
        
        vm.prank(burner);
        token.burn(user, 0);
        
        assertEq(token.balanceOf(user), 1000);
        assertEq(token.totalSupply(), 1000);
    }

    /// @dev Test burning more than balance reverts
    function test_Burn_ExcessAmountReverts() public {
        vm.prank(minter);
        token.mint(user, 1000);
        
        vm.prank(burner);
        vm.expectRevert(); // ERC20: burn amount exceeds balance
        token.burn(user, 2000);
    }

    /// @dev Test transferring with insufficient balance reverts
    function test_Transfer_InsufficientBalanceReverts() public {
        vm.prank(minter);
        token.mint(user, 1000);
        
        vm.prank(user);
        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        token.transfer(user2, 2000);
    }

    // ============ GAS OPTIMIZATION TESTS ============

    /// @dev Test gas usage for minting
    function test_Gas_Mint() public {
        uint256 gasBefore = gasleft();
        
        vm.prank(minter);
        token.mint(user, 1000 * 10**18);
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for mint:", gasUsed);
        assertLt(gasUsed, 100000); 
    }

    /// @dev Test gas usage for burning
    function test_Gas_Burn() public {
        vm.prank(minter);
        token.mint(user, 1000 * 10**18);
        
        uint256 gasBefore = gasleft();
        
        vm.prank(burner);
        token.burn(user, 500 * 10**18);
        
        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for burn:", gasUsed);
        assertLt(gasUsed, 100000); 
    }

    // ============ SECURITY TESTS ============

    /// @dev Test that cap is immutable
    function test_Cap_Immutable() public view {
        // cap is declared as immutable, so this should always be true
        assertEq(token.cap(), TOKEN_CAP);
    }

    /// @dev Test that admin cannot mint without minter role
    function test_Admin_CannotMintWithoutRole() public {
        // Admin doesn't automatically have minter role unless granted in constructor
        
        address newAdmin = makeAddr("newAdmin");
        RecycloToken newToken = new RecycloToken("Test Token", "TEST", TOKEN_CAP, newAdmin);
        
        // newAdmin should have minter role from constructor
        vm.prank(newAdmin);
        newToken.mint(user, 1000);
        
        // But the role is revoked
        vm.prank(newAdmin);
        newToken.revokeMinterRole(newAdmin);
        
        // Now admin cannot mint
        vm.prank(newAdmin);
        vm.expectRevert();
        newToken.mint(user, 1000);
    }

    /// @dev Test ERC20 permit functionality
    function test_Permit() public {
        // Setup for permit
        uint256 privateKey = 0x1234;
        address owner = vm.addr(privateKey);
        
        // Mint tokens to owner
        vm.prank(minter);
        token.mint(owner, 1000 * 10**18);
        
        // Create permit signature
        uint256 value = 500 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                            owner,
                            user,
                            value,
                            token.nonces(owner),
                            deadline
                        )
                    )
                )
            )
        );
        
        // Use permit to approve spending
        token.permit(owner, user, value, deadline, v, r, s);
        
        assertEq(token.allowance(owner, user), value);
    }
}