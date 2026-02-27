# PentaChain (PENTA)

PentaChain is an Ethash-based EVM blockchain powered by CoreGeth.

---

## Network Specifications

- Consensus: Ethash (Proof-of-Work)
- Client: CoreGeth v1.12.14
- Chain ID: 7777
- Network ID: 7777
- Currency Symbol: PENTA
- Block Time: ~15 seconds


---

## Tokenomics

### Supply

- Max Supply: 1,000,000,000 PENTA
- Mining Allocation: 721,000,000 PENTA (72.1%)
- Initial Allocation: 279,000,000 PENTA (27.9%)

### Initial Allocation Breakdown

- Premine (Dev1 + Dev2): 60,000,000 (6%)
- Treasury Allocation: 219,000,000 (21.9%)

Treasury Structure:

- Staking Reserve: 80,000,000 (8%)
- Airdrop Reserve: 40,000,000 (4%)
- Future / R&D: 19,000,000 (1.9%)
- Listings & Liquidity Allocation: 50,000,000 (5%)
- Strategic Reserve: 30,000,000 (3%)

A total of 169,000,000 PENTA (Staking + Airdrop + Future allocation) are currently secured within a treasury contract and will be deployed gradually through dedicated smart contracts and ecosystem modules.

The Listings & Liquidity Allocation (50,000,000 PENTA) is reserved for exchange integrations, liquidity provisioning, and strategic ecosystem expansion.

Treasury-managed allocations may be utilized for liquidity events, ecosystem incentives, or future token distribution programs, subject to governance and compliance requirements.

### Mining Parameters

- Initial Block Reward: 75 PENTA
- Halving Interval: 8,409,600 blocks (~4 years)
- Minimum Reward: 1 PENTA
- Burn: 0.5% of block reward
- Developer Reward: 1.5% of block reward



## Public Infrastructure

Public RPC:
https://rpc.penta.org

Explorer:
https://explorer.pentamine.org

---

## Public P2P Node (Bootnode)
enode://403f37bd60237f82f45a7c43b58fcc92844cf0a793952933c36f933d5c7f48f5ba0731315cee607e9cc831f86818be2dfb29f9fe333584d76354abbc3d399c25@188.45.200.51:30307


P2P Port:
30307 (TCP / UDP)

---

## RPC APIs

Public RPC exposes only required APIs:

- eth
- net
- web3

Admin and debug namespaces are not exposed on public endpoints.

---

## Genesis

The official genesis file is available in this repository:

`chain/genesis.json`

---

## MetaMask Configuration

- Network Name: PentaChain
- RPC URL: https://rpc.penta.org
- Chain ID: 7777
- Currency Symbol: PENTA
- Block Explorer: https://explorer.pentamine.org

---

## Mining

PentaChain uses Ethash Proof-of-Work and is compatible with standard Ethash miners and Stratum-based mining pools.

RPC methods used by mining pools:

- eth_getWork
- eth_submitWork
- eth_blockNumber
- eth_getBlockByNumber

---

---

## Website

The official website is currently undergoing a redesign and infrastructure upgrade.
Updated documentation and ecosystem modules will be published soon.

## License

This repository contains network configuration and documentation for PentaChain.
