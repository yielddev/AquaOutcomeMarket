  === Deployment Summary ===
  Deployer: 0xFfF746E4a7aA6CF533052b64D79830Ccc499EF92
  Aqua: 0x68bC8b247ed1eee8A6712316570878ea51A7a372
  SwapVM: 0xdbeeA577AFA23Ae114C933ae0C21efBD7DBD407C
  Strategy (PredictionMarketAMM): 0x387252Fdb4ff3F9707616B81625F6d748b0C14F1
  MakerMintingHook: 0x3C25c6c89077B07717B9dA32032Dcf41a91a6Eab
  F1 Market: 0x610D5f07C24fbf1C3D381F52A291B80701F7607e
  Bitcoin Under Market: 0xeC540Acb86EA568Af2c481DC85B7F4efF4329055
  Lakers Win Market: 0xAac7afe0714268794855654bB009a68491e377F2
  F1 Order Hash:
  0x852a4b58622fcd2e82132c3cfcc233afe3853488943757f1fe34f37f858ce9f1
  Bitcoin Under Order Hash:
  0xc16b44d7dfa77bbfa8807328881bb9bad4313c2ff3f403d94b3e471a9badf836
  Lakers Win Order Hash:
  0xded91306393e4a3495663d264bbd7ee2d07ee32d17bd36a21d81821acb9db30d
  F1 Order Bytes Length: 384
  Bitcoin Under Order Bytes Length: 384
  Lakers Win Order Bytes Length: 384
  Deployment JSON written to: script/json/deployment-31337.json

== Logs ==
  === Minting Prediction Tokens ===
  Taker: 0xe90d4f9dE8768EFf77C43688101fCB0cd7A49B57
  Market: 0xeC540Acb86EA568Af2c481DC85B7F4efF4329055
  Collateral: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831
  Amount: 100000000
  USDC balance before: 399999900
  NO token balance before: 0
  YES token balance before: 0
  Approved 100000000 USDC to market
  Minted 100000000 of both NO and YES tokens
  USDC balance after: 299999900
  NO token balance after: 100000000
  YES token balance after: 100000000
  === Mint Successful ===
  NO token address: 0x8a5a077E40547923c398EE169d889fe0E3B7aa6b
  YES token address: 0xbEfEb6Fc6d823b4FD19844AD5DA71E9911B34F7A


  forge script script/DeployFullSystem.sol --rpc-url $RPC_URL
  forge script script/MintPredictionTokens.s.sol:MintPredictionTokens --rpc-url $RPC_URL --broadcast
  forge script script/ApproveMakerHook.s.sol:ApproveMakerHook --rpc-url $RPC_URL --broadcast
  forge script script/DepositToYieldVault.s.sol:DepositToYieldVault --rpc-url $RPC_URL --broadcast
  forge script script/ExecuteTakerSwap.s.sol:ExecuteTakerSwap --rpc-url $RPC_URL