// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @notice Library containing common Arbitrum One addresses
library ArbitrumLib {
    // Chain ID
    uint256 public constant ARBITRUM_ONE_CHAIN_ID = 42161;

    // EVC (Ethereum Vault Connector)
    // TODO: Update with actual EVC address when deployed
    address public constant EVC = address(0);

    // EVC USDC VAULT
    // TODO: Update with actual vault address when deployed
    address public constant EVC_USDC_VAULT = address(0);

    // EVC WETH VAULT
    // TODO: Update with actual vault address when deployed
    address public constant EVC_WETH_VAULT = address(0);

    // USDC (Arbitrum One)
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // WETH (Arbitrum One)
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // user 
    address public constant USER = 0xFfF746E4a7aA6CF533052b64D79830Ccc499EF92;

    // USDC 
    // WETH
}