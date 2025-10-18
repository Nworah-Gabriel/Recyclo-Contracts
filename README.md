# Recyclo - Recycling Rewards Ecosystem

A decentralized recycling rewards system built on Celo blockchain that incentivizes recycling through token rewards and provides a marketplace for trading recycled materials.

## 📋 Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Testing](#testing)
- [Deployment](#deployment)
- [Scripts Usage](#scripts-usage)
- [Contract Architecture](#contract-architecture)
- [Security](#security)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

Recyclo consists of three main smart contracts:

1. **RecycloToken** - ERC20 token with minting/burning capabilities
2. **RewardManager** - Manages recycling drop-offs and token rewards
3. **Marketplace** - Platform for trading recycled materials using tokens

## 📁 Project Structure
```bash
Recylo/
├── script/ # Deployment and interaction scripts
│ ├── interfaces/
│ │ └── IDeploymentStructs.sol
│ ├── Deploy.s.sol # Main deployment script
│ ├── DeployTestnet.s.sol # Testnet deployment
│ ├── DeployMarketplace.s.sol # Marketplace-only deployment
│ ├── DeployUpgrade.s.sol # Upgrade deployment
│ ├── InteractionHelper.sol # Contract interaction helper
│ └── ConfigHelper.sol # Configuration helper
├── src/ # Smart contracts
│ ├── RecycloToken.sol
│ ├── RewardManager.sol
│ └── Marketplace.sol
├── test/ # Test files
│ ├── RecycloTest.t.sol
│ ├── RecycloTokenExtendedTest.t.sol
│ ├── RewardManagerExtendedTest.t.sol
│ └── MarketplaceExtendedTest.t.sol
├── .local.env # Environment variables template
├── foundry.toml # Foundry configuration
└── README.md # This file
```


## ⚙️ Prerequisites

- **Node.js** (v16 or higher)
- **Foundry** (Forge, Cast, Anvil)
- **Git**
- **Celo Wallet** (Valora or similar for testnet)

### Installing Foundry

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify installation
forge --version
cast --version
anvil --version
```

## 🚀 Installation

Clone the repository

```bash
git clone https://github.com/Nworah-Gabriel/Recyclo-Contracts.git
cd Recylo
```

## Install dependencies

```bash
# Install OpenZeppelin contracts and other dependencies
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```
## Set up environment variables

```bash
cp .env.example .env
```

## Build the project

```bash
forge build
```


## 🧪 Testing
Run All Tests

```bash
forge test

Run Specific Test Suites
bash

# Run token tests
forge test --match-test "RecycloTokenExtendedTest" -vv

# Run reward manager tests
forge test --match-test "RewardManagerExtendedTest" -vv

# Run marketplace tests
forge test --match-test "MarketplaceExtendedTest" -vv

# Run integration tests
forge test --match-test "test_Integration" -vv
```
## Run Tests with Gas Reports
```bash
forge test --gas-report
```

## Run Fuzz Tests
```bash
forge test --match-test "testFuzz" -vv
```

## 🚀 Deployment
1. Testnet Deployment (Alfajores)
```bash

# Deploy complete ecosystem
forge script script/DeployTestnet.s.sol:DeployTestnet \
  --rpc-url alfajores \
  --broadcast \
  --verify \
  -vvvv

# Expected output:
# RecycloToken deployed at: 0x...
# RewardManager deployed at: 0x...
# Marketplace deployed at: 0x...
```
2. Mainnet Deployment
```bash
# Deploy complete ecosystem
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url celo \
  --broadcast \
  --verify \
  -vvvv

# Verify deployment
forge script script/Deploy.s.sol:DeployScript \
  --sig "validateDeployment(address,address,address,address)" \
  0xTokenAddress 0xRewardManagerAddress 0xMarketplaceAddress 0xAdminAddress \
  --rpc-url celo
```

3. Marketplace-Only Deployment
```bash

# Deploy Marketplace separately
forge script script/DeployMarketplace.s.sol:DeployMarketplace \
  --rpc-url celo \
  --broadcast \
  --verify \
  -vvvv

# Deploy with additional listers
forge script script/DeployMarketplace.s.sol:DeployMarketplace \
  --sig "runWithAdditionalListers(address[])" \
  "[0xLister1,0xLister2,0xLister3]" \
  --rpc-url celo \
  --broadcast \
  -vvvv
```

## 📜 Scripts Usage
### Interaction Helper

```bash
# Display contract statistics
forge script script/InteractionHelper.sol:InteractionHelper \
  --sig "displayStats()" \
  --rpc-url alfajores \
  -vv

# Simulate a drop-off
forge script script/InteractionHelper.sol:InteractionHelper \
  --sig "simulateDropOff(address,uint256,address,bytes32)" \
  0xUserAddress 100000000000000000000 0xCollectorAddress 0xMetadataHash \
  --rpc-url alfajores \
  --broadcast \
  -vvvv

# Batch simulate drop-offs
forge script script/InteractionHelper.sol:InteractionHelper \
  --sig "batchSimulateDropOffs(address[],uint256[],address[],bytes32[])" \
  "[0xUser1,0xUser2]" "[100000000000000000000,200000000000000000000]" \
  "[0xCollector1,0xCollector2]" "[0xHash1,0xHash2]" \
  --rpc-url alfajores \
  --broadcast \
  -vvvv

# Verify roles for an address
forge script script/InteractionHelper.sol:InteractionHelper \
  --sig "verifyRoles(address)" \
  0xAddressToCheck \
  --rpc-url alfajores \
  -vv

# Create test marketplace listing
forge script script/InteractionHelper.sol:InteractionHelper \
  --sig "createTestListing(uint256,uint256,bytes32)" \
  100 5000000000000000000 0xListingMetadataHash \
  --rpc-url alfajores \
  --broadcast \
  -vvvv
```

Configuration Helper
```bash

# Configure additional minters
forge script script/ConfigHelper.sol:ConfigHelper \
  --sig "configureMinters(address,address[])" \
  0xRewardManagerAddress "[0xMinter1,0xMinter2]" \
  --rpc-url celo \
  --broadcast \
  -vvvv

# Configure additional listers
forge script script/ConfigHelper.sol:ConfigHelper \
  --sig "configureListers(address,address[])" \
  0xMarketplaceAddress "[0xLister1,0xLister2]" \
  --rpc-url celo \
  --broadcast \
  -vvvv

# Verify configuration
forge script script/ConfigHelper.sol:ConfigHelper \
  --sig "verifyConfiguration(address,address,address)" \
  0xTokenAddress 0xRewardManagerAddress 0xMarketplaceAddress \
  --rpc-url celo \
  -vv
```

## 🏗️ Contract Architecture
RecycloToken

- ERC20 Token with 100M token cap

- Minting/Burning capabilities with role-based access control

- Gasless approvals using ERC20Permit

- Roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE, BURNER_ROLE

RewardManager

- Drop-off confirmation with token issuance

- Status tracking: Issued, Revoked, Disputed

- Audit trail with metadata hashes for off-chain data

- Roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE

Marketplace

- Token-based marketplace for recycled materials

- Create/cancel listings with role-based access

- Purchase functionality with escrow-less design

- Roles: DEFAULT_ADMIN_ROLE, LISTER_ROLE

🔒 Security
Access Control

- Admin: Multisig wallet for critical operations

- Minters: Authorized servers/operators for reward distribution

- Listers: Approved entities for marketplace listings

Security Best Practices

- Use multisig for admin operations

- Regular security audits

- Test thoroughly on testnet before mainnet

- Monitor contract activity

- Keep private keys secure

Key Security Features

- Role-based access control

- Input validation on all functions

- Cap enforcement to prevent infinite minting

- Event emission for audit trails

- No reentrancy vulnerabilities

## 🐛 Troubleshooting
Common Issues
1. Compilation Errors

```bash
# Clean and rebuild
forge clean
forge build
```
2. Test Failures

```bash
# Run with verbose output
forge test -vvv

# Run specific failing test
forge test --match-test "testName" -vvvv
```
3. Deployment Failures

```bash
# Check environment variables
echo $PRIVATE_KEY

# Verify RPC endpoint
cast block --rpc-url alfajores

# Check gas prices
cast gas-price --rpc-url alfajores
```
4. Insufficient Funds

```bash
# Get testnet CELO from faucet
# Visit: https://faucet.celo.org/alfajores
```
5. Verification Issues

```bash
# Manual verification
forge verify-contract <address> src/RecycloToken.sol:RecycloToken \
  --chain alfajores \
  --verifier etherscan \
  --etherscan-api-key $ETHERSCAN_API_KEY
```
6. Getting Help

- Check the Foundry book: https://book.getfoundry.sh/

- Review Celo documentation: https://docs.celo.org/

- Check contract verification on CeloScan

- Review test outputs for specific error messages

## 📞 Support

For issues and questions:

- Check this README and documentation

- Review test cases for usage examples

- Check deployed contract verification on block explorer

- Ensure all environment variables are properly set

## 📄 License

This project is licensed under the MIT License.

## Author
### Name: Nworah CHimzuruoke Gabriel (SAGGIO)
