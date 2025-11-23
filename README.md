## Aqua Outcome Markets

Predicition Market AMM built with swapVM and Aqua by 1inch. This project leverages several features of swapVM to improve the attractiveness of liquidity provision in AMM prediction markets through cost minimization and capital efficiancy.

It also benifits traders as in enable a long tail of assets to have tradeable markets and bootstrapped liquidity. 


## Dynamic PM-AMM

Implementing a novel AMM curve design specifically for prediction markets we minimize the cost to LPs from arbitrage (Loss Vc Rebalancing). This liquidity curve concentrates liquidity around the most volatile price in the market (50%) and liquidity decays over time to account for the fact that information about the true price of the market becomes known on a steady basis until some event horizon (expiry). 

This is implemented in `src/instruction/pmAMM.sol` which uses the swapVM registers to calculate the appropriate tokenIn/tokenOut amount according to our invariant and the time to expiry. 

## Aqua Integration

Using Aqua we enable liquidity providers to make a market in several seperate prediction markets using the same capital by implementing each market with virtual reserves. 

## HOOKS For Just-In-Time liquidity and Credit Based Market Making

By attaching the `src/hooks/MakerMintingHook.sol` as a preTransferOut hook, the maker need not hold any inventory in any market as the hooks executes a minting transaction in the takers desired market and mints the two sided outcome token by depositing the markets payout token. thus prior to transfering out, having a balance of the takers desired token. 

The hook is further extended with an awareness of the EVC, acting as an euler account operator the user is able to deposit funds in the predefined yield vault to earn lending yield. Funds are withdrawn from this vault when neccesary to complete a swap. 

Lastly the hook enables credit functionality if the maker order was deployed with `canBorrow` flag set. If the yield vault does not have enough balance to fulfill the swap, the hook will attempt to create a borrow on the vault to obtain the funds neccesary to make the market.

## Scripting

  forge script script/DeployFullSystem.sol --rpc-url $RPC_URL
  forge script script/MintPredictionTokens.s.sol:MintPredictionTokens --rpc-url $RPC_URL --broadcast
  forge script script/ApproveMakerHook.s.sol:ApproveMakerHook --rpc-url $RPC_URL --broadcast
  forge script script/DepositToYieldVault.s.sol:DepositToYieldVault --rpc-url $RPC_URL --broadcast
  forge script script/ExecuteTakerSwap.s.sol:ExecuteTakerSwap --rpc-url $RPC_URL

  set .env 

```
# Private Key for deployment and transactions
# WARNING: Never commit your actual private key to version control
PRIVATE_KEY=
TAKER_PRIVATE_KEY=

# BuildBear Network Configuration
RPC_URL=https://rpc.buildbear.io/payable-mystique-f89040ff
CHAIN_ID=31337

MARKET_ADDRESS=0x495cA044B3a447756896cBcf305f106D3c71D4b1
#For swap
TOKEN_IN=0xC7371eFbc80F37Cab81761E8e8e1B00793D84D72 #No token bitcoin
TOKEN_OUT=0xE0E5Df65bB4B3CBC26fFfdb009ad0fcaBB12B61B #yes token bitcoin
AMOUNT_IN=50000000 # 50 Tokens

DEPLOYMENT_JSON_PATH="./json/deployment-31337.json"
ORDER_KEY="bitcoinUnderOrder"


#ForMint
AMOUNT=100000000
```

