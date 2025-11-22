// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @notice Library containing common Arbitrum One addresses
library ArbitrumLib {
    // Chain ID
    uint256 public constant ARBITRUM_ONE_CHAIN_ID = 42161;

    // EVC (Ethereum Vault Connector)
    // TODO: Update with actual EVC address when deployed
    address public constant EVC = 0x6302ef0F34100CDDFb5489fbcB6eE1AA95CD1066;

    // EVC USDC VAULT
    // TODO: Update with actual vault address when deployed
    address public constant EVC_USDC_VAULT = 0x0a1eCC5Fe8C9be3C809844fcBe615B46A869b899;

    // EVC WETH VAULT
    // TODO: Update with actual vault address when deployed
    address public constant EVC_WETH_VAULT = 0x78E3E051D32157AACD550fBB78458762d8f7edFF;

    // USDC (Arbitrum One)
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    // WETH (Arbitrum One)
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    // user 
    address public constant USER = 0xFfF746E4a7aA6CF533052b64D79830Ccc499EF92;

    address public constant USDC_WHALE = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7;

    // USDC 
    // WETH
}