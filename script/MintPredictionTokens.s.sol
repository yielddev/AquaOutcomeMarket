// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {PredictionMarket} from "../src/market/PredictionMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../test/lib/ArbitrumLib.sol";
import "forge-std/console.sol";

/// @notice Script for takers to mint prediction tokens with USDC
/// @dev Usage:
///   forge script script/MintPredictionTokens.s.sol:MintPredictionTokens --sig "run(address,uint256)" <market_address> <amount> --rpc-url <rpc_url> --broadcast
///   Or set MARKET_ADDRESS and AMOUNT environment variables and use: forge script script/MintPredictionTokens.s.sol:MintPredictionTokens --rpc-url <rpc_url> --broadcast
contract MintPredictionTokens is Script {
    function run() public {
        // Get parameters from environment variables
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        uint256 amount = vm.envUint("AMOUNT");
        _mintTokens(marketAddress, amount);
    }

    /// @notice Mint prediction tokens with parameters
    /// @param marketAddress The address of the PredictionMarket contract
    /// @param amount The amount of USDC to use for minting (will mint equal amounts of NO and YES tokens)
    // function run(address marketAddress, uint256 amount) public {
    //     _mintTokens(marketAddress, amount);
    // }

    function _mintTokens(address marketAddress, uint256 amount) internal {
        // Get private key from environment variable
        uint256 takerPrivateKey = vm.envUint("TAKER_PRIVATE_KEY");
        address taker = vm.addr(takerPrivateKey);

        vm.startBroadcast(takerPrivateKey);

        PredictionMarket market = PredictionMarket(marketAddress);
        address usdc = ArbitrumLib.USDC;
        address collateral = market.collateral();

        console.log("=== Minting Prediction Tokens ===");
        console.log("Taker:", taker);
        console.log("Market:", marketAddress);
        console.log("Collateral:", collateral);
        console.log("Amount:", amount);

        // Check current balances
        uint256 usdcBalanceBefore = IERC20(usdc).balanceOf(taker);
        uint256 noBalanceBefore = IERC20(market.no()).balanceOf(taker);
        uint256 yesBalanceBefore = IERC20(market.yes()).balanceOf(taker);

        console.log("USDC balance before:", usdcBalanceBefore);
        console.log("NO token balance before:", noBalanceBefore);
        console.log("YES token balance before:", yesBalanceBefore);

        // Verify taker has sufficient USDC
        require(usdcBalanceBefore >= amount, "Insufficient USDC balance");

        // Approve USDC to the market
        IERC20(usdc).approve(marketAddress, amount);
        console.log("Approved", amount, "USDC to market");

        // Mint prediction tokens
        market.mint(taker, amount);
        console.log("Minted", amount, "of both NO and YES tokens");

        // Check balances after
        uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(taker);
        uint256 noBalanceAfter = IERC20(market.no()).balanceOf(taker);
        uint256 yesBalanceAfter = IERC20(market.yes()).balanceOf(taker);

        console.log("USDC balance after:", usdcBalanceAfter);
        console.log("NO token balance after:", noBalanceAfter);
        console.log("YES token balance after:", yesBalanceAfter);

        // Verify the mint worked
        require(noBalanceAfter == noBalanceBefore + amount, "NO token balance mismatch");
        require(yesBalanceAfter == yesBalanceBefore + amount, "YES token balance mismatch");
        require(usdcBalanceAfter == usdcBalanceBefore - amount, "USDC balance mismatch");

        console.log("=== Mint Successful ===");
        console.log("NO token address:", market.no());
        console.log("YES token address:", market.yes());

        vm.stopBroadcast();
    }
}
