// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title RecycloToken
 * @dev ERC20 token with minting/burning capabilities, access control, and gasless approvals
 * @notice The native token of the Recyclo ecosystem, used for rewards and marketplace transactions
 */
contract RecycloToken is ERC20, AccessControl, ERC20Permit {
    /// @notice Role identifier for addresses allowed to mint new tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role identifier for addresses allowed to burn tokens
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Maximum total supply of tokens that can ever be minted
    uint256 public immutable cap;

    /// @notice Emitted when new tokens are minted
    event TokensMinted(address indexed to, uint256 amount);
    
    /// @notice Emitted when tokens are burned
    event TokensBurned(address indexed from, uint256 amount);

    /**
     * @dev Initializes the RecycloToken contract
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param cap_ Maximum total supply of tokens
     * @param admin Address to be granted DEFAULT_ADMIN_ROLE, MINTER_ROLE, and BURNER_ROLE
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 cap_,
        address admin
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        require(cap_ > 0, "RecycloToken: cap must be positive");
        cap = cap_;
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
    }

    /**
     * @notice Mints new tokens to the specified address
     * @dev Only callable by addresses with MINTER_ROLE
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     * @custom:throws CapExceeded if minting would exceed the token cap
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        require(totalSupply() + amount <= cap, "RecycloToken: cap exceeded");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /**
     * @notice Burns tokens from the specified address
     * @dev Only callable by addresses with BURNER_ROLE
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, amount);
        emit TokensBurned(from, amount);
    }

    /**
     * @notice Grants MINTER_ROLE to an account
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     * @param account Address to grant the MINTER_ROLE to
     */
    function grantMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MINTER_ROLE, account);
    }

    /**
     * @notice Grants BURNER_ROLE to an account
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     * @param account Address to grant the BURNER_ROLE to
     */
    function grantBurnerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }

    /**
     * @notice Revokes MINTER_ROLE from an account
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     * @param account Address to revoke the MINTER_ROLE from
     */
    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
    }

    /**
     * @notice Revokes BURNER_ROLE from an account
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     * @param account Address to revoke the BURNER_ROLE from
     */
    function revokeBurnerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, account);
    }
}