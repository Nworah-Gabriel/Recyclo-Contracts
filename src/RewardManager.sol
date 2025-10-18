// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@contract/RecycloToken.sol";

/**
 * @title RewardManager
 * @dev Manages token rewards for recycling drop-offs with audit trail and dispute resolution
 * @notice Handles the issuance, revocation, and disputing of recycling rewards with on-chain records
 */
contract RewardManager is AccessControl {
    /// @notice Role identifier for addresses allowed to confirm drop-offs and issue rewards
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice The RecycloToken contract used for reward distribution
    RecycloToken public immutable token;

    /// @notice Enum representing the status of a recycling drop
    enum Status { 
        Unknown,    // Drop not yet processed or doesn't exist
        Issued,     // Tokens successfully issued for drop-off
        Revoked,    // Tokens revoked by admin (fraud, error, etc.)
        Disputed    // Drop is under dispute/investigation
    }
    
    /**
     * @dev Structure representing a recycling drop-off record
     * @param user Address of the user receiving the tokens
     * @param amount Amount of tokens issued
     * @param timestamp When the drop-off was confirmed
     * @param collector Address of the collection point/operator
     * @param status Current status of the drop
     * @param metadataHash Hash of off-chain metadata (photos, weight, signatures, etc.)
     */
    struct Drop {
        address user;
        uint256 amount;
        uint64 timestamp;
        address collector;
        Status status;
        bytes32 metadataHash;
    }

    /// @notice Mapping from drop ID to Drop struct
    mapping(uint256 => Drop) public drops;
    
    /// @notice Counter for generating unique drop IDs
    uint256 public dropCount;

    /**
     * @dev Emitted when a new drop-off is confirmed and tokens are issued
     * @param dropId The unique identifier of the drop
     * @param user Address of the user receiving tokens
     * @param amount Amount of tokens issued
     * @param collector Address of the collection point
     * @param metadataHash Hash of the drop-off metadata
     */
    event DropIssued(
        uint256 indexed dropId,
        address indexed user,
        uint256 amount,
        address indexed collector,
        bytes32 metadataHash
    );
    
    /**
     * @dev Emitted when a drop is revoked by admin
     * @param dropId The unique identifier of the revoked drop
     * @param reason Explanation for the revocation
     */
    event DropRevoked(uint256 indexed dropId, string reason);
    
    /**
     * @dev Emitted when a drop is marked as disputed
     * @param dropId The unique identifier of the disputed drop
     * @param reason Explanation for the dispute
     */
    event DropDisputed(uint256 indexed dropId, string reason);

    /**
     * @dev Initializes the RewardManager contract
     * @param tokenAddr Address of the RecycloToken contract
     * @param admin Address to be granted DEFAULT_ADMIN_ROLE
     */
    constructor(address tokenAddr, address admin) {
        token = RecycloToken(tokenAddr);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Confirms a recycling drop-off and issues tokens to the user
     * @dev Only callable by addresses with MINTER_ROLE. Auto-increments dropCount.
     * @param user Address to receive the reward tokens
     * @param amount Amount of tokens to issue
     * @param collector Address of the collection point/operator
     * @param metadataHash Hash of off-chain verification data
     * @return dropId The unique identifier of the created drop record
     * @custom:throws InvalidUser if user address is zero
     * @custom:throws InvalidAmount if amount is zero
     * @custom:throws InvalidCollector if collector address is zero
     */
    function confirmDropOff(
        address user,
        uint256 amount,
        address collector,
        bytes32 metadataHash
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(user != address(0), "RewardManager: invalid user");
        require(amount > 0, "RewardManager: amount must be positive");
        require(collector != address(0), "RewardManager: invalid collector");

        uint256 dropId = ++dropCount;
        
        drops[dropId] = Drop({
            user: user,
            amount: amount,
            timestamp: uint64(block.timestamp),
            collector: collector,
            status: Status.Issued,
            metadataHash: metadataHash
        });

        token.mint(user, amount);
        
        emit DropIssued(dropId, user, amount, collector, metadataHash);
        
        return dropId;
    }

    /**
     * @notice Confirms a drop-off with a specific ID (for pre-allocated IDs)
     * @dev Only callable by addresses with MINTER_ROLE. Useful for idempotent operations.
     * @param dropId Pre-determined ID for the drop record
     * @param user Address to receive the reward tokens
     * @param amount Amount of tokens to issue
     * @param collector Address of the collection point/operator
     * @param metadataHash Hash of off-chain verification data
     * @custom:throws InvalidDropId if dropId is out of range
     * @custom:throws InvalidUser if user address is zero
     * @custom:throws InvalidAmount if amount is zero
     * @custom:throws InvalidCollector if collector address is zero
     * @custom:throws DropAlreadyProcessed if drop was already processed
     */
    function confirmDropOffWithId(
        uint256 dropId,
        address user,
        uint256 amount,
        address collector,
        bytes32 metadataHash
    ) external onlyRole(MINTER_ROLE) {
        require(dropId > 0 && dropId <= dropCount, "RewardManager: invalid dropId");
        require(user != address(0), "RewardManager: invalid user");
        require(amount > 0, "RewardManager: amount must be positive");
        require(collector != address(0), "RewardManager: invalid collector");
        require(drops[dropId].status == Status.Unknown, "RewardManager: drop already processed");

        drops[dropId] = Drop({
            user: user,
            amount: amount,
            timestamp: uint64(block.timestamp),
            collector: collector,
            status: Status.Issued,
            metadataHash: metadataHash
        });

        token.mint(user, amount);
        
        emit DropIssued(dropId, user, amount, collector, metadataHash);
    }

    /**
     * @notice Revokes a previously issued drop (e.g., for fraud or error correction)
     * @dev Only callable by DEFAULT_ADMIN_ROLE. Changes status to Revoked.
     * @param dropId ID of the drop to revoke
     * @param reason Explanation for the revocation
     * @custom:throws DropNotIssued if drop is not in Issued status
     */
    function revokeDrop(uint256 dropId, string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(drops[dropId].status == Status.Issued, "RewardManager: drop not issued");
        
        drops[dropId].status = Status.Revoked;
        emit DropRevoked(dropId, reason);
    }

    /**
     * @notice Marks a drop as disputed (e.g., for investigation)
     * @dev Only callable by DEFAULT_ADMIN_ROLE. Changes status to Disputed.
     * @param dropId ID of the drop to dispute
     * @param reason Explanation for the dispute
     * @custom:throws DropNotIssued if drop is not in Issued status
     */
    function disputeDrop(uint256 dropId, string calldata reason) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(drops[dropId].status == Status.Issued, "RewardManager: drop not issued");
        
        drops[dropId].status = Status.Disputed;
        emit DropDisputed(dropId, reason);
    }

    /**
     * @notice Retrieves a full drop record by ID
     * @param dropId ID of the drop to retrieve
     * @return drop The complete Drop struct
     */
    function getDrop(uint256 dropId) external view returns (Drop memory) {
        return drops[dropId];
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
     * @notice Revokes MINTER_ROLE from an account
     * @dev Only callable by DEFAULT_ADMIN_ROLE
     * @param account Address to revoke the MINTER_ROLE from
     */
    function revokeMinterRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, account);
    }
}