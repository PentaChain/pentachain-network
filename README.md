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

## License

This repository contains network configuration and documentation for PentaChain.
