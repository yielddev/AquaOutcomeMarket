// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {PredictionMarket} from "../src/market/PredictionMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

/// @notice Script to check prediction token balances for a user
/// @dev Usage:
///   forge script script/CheckPredictionTokenBalances.s.sol:CheckPredictionTokenBalances --sig "run(address)" <market_address> --rpc-url <rpc_url>
///   Or set MARKET_ADDRESS and USER_ADDRESS environment variables and use: forge script script/CheckPredictionTokenBalances.s.sol:CheckPredictionTokenBalances --rpc-url <rpc_url>
contract CheckPredictionTokenBalances is Script {
    function run() public view {
        // Get parameters from environment variables
        address marketAddress = vm.envAddress("MARKET_ADDRESS");
        address userAddress;
        
        // Try to get user address from env var, otherwise derive from TAKER_PRIVATE_KEY
        try vm.envAddress("USER_ADDRESS") returns (address addr) {
            userAddress = addr;
        } catch {
            uint256 takerPrivateKey = vm.envUint("TAKER_PRIVATE_KEY");
            userAddress = vm.addr(takerPrivateKey);
        }
        
        _checkBalances(marketAddress, userAddress);
    }

    // /// @notice Check prediction token balances with parameters
    // /// @param marketAddress The address of the PredictionMarket contract
    // function run(address marketAddress) public view {
    //     address userAddress;
        
    //     // Try to get user address from env var, otherwise derive from TAKER_PRIVATE_KEY
    //     try vm.envAddress("USER_ADDRESS") returns (address addr) {
    //         userAddress = addr;
    //     } catch {
    //         uint256 takerPrivateKey = vm.envUint("TAKER_PRIVATE_KEY");
    //         userAddress = vm.addr(takerPrivateKey);
    //     }
        
    //     _checkBalances(marketAddress, userAddress);
    // }

    // /// @notice Check prediction token balances with both parameters
    // /// @param marketAddress The address of the PredictionMarket contract
    // /// @param userAddress The address of the user to check balances for
    // function run(address marketAddress, address userAddress) public view {
    //     _checkBalances(marketAddress, userAddress);
    // }

    function _checkBalances(address marketAddress, address userAddress) internal view {
        PredictionMarket market = PredictionMarket(marketAddress);
        
        address noToken = market.no();
        address yesToken = market.yes();
        address collateral = market.collateral();
        address underlying = market.underlying();
        address winner = market.winner();

        console.log("=== Prediction Token Balances ===");
        console.log("Market:", marketAddress);
        console.log("User:", userAddress);
        console.log("Collateral:", collateral);
        console.log("Underlying:", underlying);
        console.log("Winner (if set):", winner);
        console.log("");

        // Get balances
        uint256 noBalance = IERC20(noToken).balanceOf(userAddress);
        uint256 yesBalance = IERC20(yesToken).balanceOf(userAddress);
        uint256 collateralBalance = IERC20(collateral).balanceOf(userAddress);
        uint256 totalPredictionTokens = noBalance + yesBalance;

        console.log("Token Addresses:");
        console.log("  NO token:", noToken);
        console.log("  YES token:", yesToken);
        console.log("");

        console.log("Balances:");
        console.log("  NO tokens:", noBalance);
        console.log("  YES tokens:", yesBalance);
        console.log("  Total prediction tokens:", totalPredictionTokens);
        console.log("  Collateral (USDC):", collateralBalance);
        console.log("");

        // Calculate percentages if user has tokens
        if (totalPredictionTokens > 0) {
            uint256 noPercentage = (noBalance * 100e18) / totalPredictionTokens;
            uint256 yesPercentage = (yesBalance * 100e18) / totalPredictionTokens;
            
            console.log("Token Distribution:");
            console.log("  NO tokens: %d%%", noPercentage / 1e18);
            console.log("  YES tokens: %d%%", yesPercentage / 1e18);
        }

        // Check if winner is set and user can redeem
        if (winner != address(0)) {
            uint256 winnerTokenBalance = IERC20(winner).balanceOf(userAddress);
            console.log("");
            console.log("Winner is set!");
            console.log("  Winner token:", winner == noToken ? "NO" : "YES");
            console.log("  User's winner token balance:", winnerTokenBalance);
            console.log("  User can redeem:", winnerTokenBalance, "tokens for collateral");
        } else {
            console.log("");
            console.log("Winner not yet set - market is still active");
        }
    }
}

