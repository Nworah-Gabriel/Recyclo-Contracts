// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@contract/RecycloToken.sol";

/**
 * @title Marketplace for Recyclo Tokens
 * @dev A decentralized marketplace for trading Recyclo tokens with role-based access control
 * @notice Allows authorized listers to create listings and users to buy listed items using Recyclo tokens
 */
contract Marketplace is AccessControl {
    /// @notice Role identifier for users who can create listings
    bytes32 public constant LISTER_ROLE = keccak256("LISTER_ROLE");
    
    /// @notice The RecycloToken contract used for payments
    RecycloToken public immutable token;
    
    /**
     * @dev Structure representing a marketplace listing
     * @param seller Address of the seller who created the listing
     * @param quantity Number of items available in the listing
     * @param pricePerUnit Price per item in Recyclo tokens
     * @param metaHash Hash of off-chain metadata (IPFS, etc.)
     * @param active Whether the listing is currently active
     * @param createdAt Timestamp when the listing was created
     */
    struct Listing {
        address seller;
        uint256 quantity;
        uint256 pricePerUnit;
        bytes32 metaHash;
        bool active;
        uint64 createdAt;
    }

    /// @notice Mapping from listing ID to Listing struct
    mapping(uint256 => Listing) public listings;
    
    /// @notice Counter for generating unique listing IDs
    uint256 public listingCount;

    /**
     * @dev Emitted when a new listing is created
     * @param id The unique identifier of the listing
     * @param seller Address of the seller
     * @param quantity Number of items listed
     * @param pricePerUnit Price per item in tokens
     * @param metaHash Hash of the listing metadata
     */
    event ListingCreated(
        uint256 indexed id,
        address indexed seller,
        uint256 quantity,
        uint256 pricePerUnit,
        bytes32 metaHash
    );
    
    /**
     * @dev Emitted when a listing is cancelled
     * @param id The unique identifier of the cancelled listing
     */
    event ListingCancelled(uint256 indexed id);
    
    /**
     * @dev Emitted when a listing is purchased
     * @param id The unique identifier of the listing
     * @param buyer Address of the buyer
     * @param quantity Number of items purchased
     */
    event ListingBought(uint256 indexed id, address indexed buyer, uint256 quantity);

    /**
     * @dev Initializes the Marketplace contract
     * @param tokenAddr Address of the RecycloToken contract
     * @param admin Address to be granted DEFAULT_ADMIN_ROLE and LISTER_ROLE
     */
    constructor(address tokenAddr, address admin) {
        token = RecycloToken(tokenAddr);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(LISTER_ROLE, admin);
    }

    /**
     * @notice Creates a new marketplace listing
     * @dev Only users with LISTER_ROLE can create listings
     * @param quantity Number of items to list (must be > 0)
     * @param pricePerUnit Price per item in tokens (must be > 0)
     * @param metaHash Hash of off-chain metadata
     * @return listingId The unique identifier of the created listing
     */
    function createListing(
        uint256 quantity,
        uint256 pricePerUnit,
        bytes32 metaHash
    ) external onlyRole(LISTER_ROLE) returns (uint256) {
        require(quantity > 0, "Marketplace: quantity must be positive");
        require(pricePerUnit > 0, "Marketplace: price must be positive");

        uint256 listingId = ++listingCount;
        
        listings[listingId] = Listing({
            seller: msg.sender,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            metaHash: metaHash,
            active: true,
            createdAt: uint64(block.timestamp)
        });

        emit ListingCreated(listingId, msg.sender, quantity, pricePerUnit, metaHash);
        
        return listingId;
    }

    /**
     * @notice Cancels an existing listing
     * @dev Can be called by the listing seller or admin
     * @param listingId The ID of the listing to cancel
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), 
                "Marketplace: not authorized");
        require(listing.active, "Marketplace: listing not active");

        listing.active = false;
        emit ListingCancelled(listingId);
    }

    /**
     * @notice Purchases items from a listing
     * @dev Buyer must have approved sufficient tokens to the marketplace
     * @param listingId The ID of the listing to purchase from
     * @param quantity Number of items to purchase
     */
    function buyListing(uint256 listingId, uint256 quantity) external {
        Listing storage listing = listings[listingId];
        require(listing.active, "Marketplace: listing not active");
        require(quantity <= listing.quantity, "Marketplace: insufficient quantity");

        uint256 totalPrice = quantity * listing.pricePerUnit;
        
        require(token.transferFrom(msg.sender, listing.seller, totalPrice),
                "Marketplace: token transfer failed");

        listing.quantity -= quantity;
        if (listing.quantity == 0) {
            listing.active = false;
        }

        emit ListingBought(listingId, msg.sender, quantity);
    }

    /**
     * @notice Retrieves a full listing struct by ID
     * @param listingId The ID of the listing to retrieve
     * @return listing The complete Listing struct
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @notice Grants LISTER_ROLE to an account
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     * @param account Address to grant the LISTER_ROLE to
     */
    function grantListerRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(LISTER_ROLE, account);
    }
}