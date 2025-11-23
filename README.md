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



