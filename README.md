# Readora Smart Contracts

Smart contracts for the Readora AI-powered reading platform, enabling on-chain reward distribution, task management, and user incentives.

## Overview

Readora combines reading, learning, and Web3 by allowing users to earn rewards through reading activities and task completion. This repository contains the smart contracts that power the reward system on Binance Smart Chain.

### Key Features

- **ReadoraRewards Contract**: Manages user points, task claims, and daily check-ins
- **EIP712 Signature Verification**: Secure off-chain signing with on-chain verification
- **Reentrancy Protection**: Safe contract interactions using OpenZeppelin Guards
- **Task-based Rewards**: Flexible reward system for different task types
- **Daily Check-in System**: Gamified user engagement with consistent rewards

## Tech Stack

- **Solidity** ^0.8.29
- **Hardhat** - Ethereum development environment
- **OpenZeppelin** - Secure contract libraries
- **BSC (Binance Smart Chain)** - Primary deployment network

## Quick Start

### Prerequisites

- Node.js 18+
- pnpm or npm

### Installation

```bash
cd on-chain
pnpm install
```

### Compile Contracts

```bash
pnpm run compile
```

### Run Tests

```bash
pnpm run test
```

### Deploy

**BSC Testnet:**
```bash
pnpm run deploy:testnet
```

**BSC Mainnet:**
```bash
pnpm run deploy:mainnet
```

## Project Structure

```
on-chain/
├── contracts/          # Solidity smart contracts
│   └── ReadoraRewards.sol
├── scripts/            # Deployment and interaction scripts
├── test/              # Unit tests
├── deployments/       # Deployment artifacts
└── hardhat.config.js  # Hardhat configuration
```

## Environment Configuration

Create a `.env` file with required variables:

```env
BACKEND_WALLET_PRIVATE_KEY=your_private_key
BACKEND_WALLET_ADDRESS=your_wallet_address
BSCSCAN_API_KEY=your_bscscan_api_key
BSC_TESTNET_RPC_URL=https://data-seed-prebsc-1-b.binance.org:8545
BSC_MAINNET_RPC_URL=https://bsc-dataseed.binance.org
```

See `.env.example` for all available configuration options.

## Contract Functions

### ReadoraRewards.sol

- **claimTask()**: User claims reward for completing a task
- **dailyCheckIn()**: User performs daily check-in for reward
- **getUserPoints()**: View user's total accumulated points
- **setPointsPerTask()**: Admin - set reward amount per task
- **updateBackendSigner()**: Admin - update signer address

## Security

- OpenZeppelin contracts for battle-tested security
- EIP712 for cryptographic message verification
- ReentrancyGuard to prevent reentrancy attacks
- Access control with Ownable pattern

## License

MIT

## Contributing

Part of the Readora project - an AI reading network turning attention into intelligence.

For the full Readora project, visit: https://github.com/LetsReadora
