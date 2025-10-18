// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@contract/RecycloToken.sol";
import "@contract/RewardManager.sol";
import "@contract/Marketplace.sol";

/**
 * @title Deployment Structs Interface
 * @dev Shared structs for deployment scripts to avoid circular dependencies
 */
interface IDeploymentStructs {
    /// @notice Struct to hold deployed contract addresses
    struct DeployedContracts {
        RecycloToken token;
        RewardManager rewardManager;
        Marketplace marketplace;
    }
}