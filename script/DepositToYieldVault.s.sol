// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVault} from "euler-interfaces/IEVault.sol";
import "../test/lib/ArbitrumLib.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

/// @notice Script for maker to deposit USDC into the yield vault via EVC
/// @dev This provides liquidity for the maker's orders
/// Usage:
///   Required: DEPLOYMENT_JSON_PATH (e.g., "script/json/deployment-31337.json")
///   Required: PRIVATE_KEY (maker's private key)
///   Required: AMOUNT (amount of USDC to deposit in wei, e.g., 10000000000 for 10,000 USDC)
///   Optional: YIELD_VAULT (default: ArbitrumLib.EVC_USDC_VAULT)
///   forge script script/DepositToYieldVault.s.sol:DepositToYieldVault --rpc-url <rpc_url> --broadcast
contract DepositToYieldVault is Script {
    using stdJson for string;

    function run() public {
        // Get deployment JSON path from environment
        string memory jsonPath = vm.envString("DEPLOYMENT_JSON_PATH");
        
        // Read the JSON file content
        string memory json;
        try vm.readFile(jsonPath) returns (string memory fileContent) {
            json = fileContent;
        } catch {
            // If file not found, try prepending "script/" to the path
            string memory altPath = string.concat("script/", jsonPath);
            json = vm.readFile(altPath);
        }
        
        // Get maker's private key
        uint256 makerPrivateKey = vm.envUint("PRIVATE_KEY");
        address maker = vm.addr(makerPrivateKey);
        
        // Get amount to deposit
        uint256 amount = vm.envUint("AMOUNT");
        
        // Get yield vault address (default to EVC_USDC_VAULT)
        address yieldVault = ArbitrumLib.EVC_USDC_VAULT;
        try vm.envAddress("YIELD_VAULT") returns (address vault) {
            yieldVault = vault;
        } catch {}
        
        // Get USDC address
        address usdc = ArbitrumLib.USDC;
        
        vm.startBroadcast(makerPrivateKey);
        
        console.log("=== Deposit to Yield Vault ===");
        console.log("Maker:", maker);
        console.log("USDC:", usdc);
        console.log("Yield Vault:", yieldVault);
        console.log("Amount to deposit:", amount);
        
        // Check maker's USDC balance
        uint256 usdcBalance = IERC20(usdc).balanceOf(maker);
        console.log("Maker USDC balance:", usdcBalance);
        require(usdcBalance >= amount, "Insufficient USDC balance");
        
        // Check current vault balance
        uint256 vaultBalanceBefore = IEVault(yieldVault).balanceOf(maker);
        console.log("Vault balance before:", vaultBalanceBefore);
        
        // Approve vault to spend USDC
        uint256 currentAllowance = IERC20(usdc).allowance(maker, yieldVault);
        console.log("Current vault allowance:", currentAllowance);
        
        if (currentAllowance < amount) {
            IERC20(usdc).approve(yieldVault, type(uint256).max);
            console.log("Approved vault to spend USDC");
        }
        
        // Deposit USDC into vault
        console.log("=== Depositing to Vault ===");
        IEVault(yieldVault).deposit(amount, maker);
        console.log("Deposited", amount, "USDC into vault");
        
        // Check vault balance after deposit
        uint256 vaultBalanceAfter = IEVault(yieldVault).balanceOf(maker);
        console.log("Vault balance after:", vaultBalanceAfter);
        console.log("Vault shares received:", vaultBalanceAfter - vaultBalanceBefore);
        
        // Check remaining USDC balance
        uint256 usdcBalanceAfter = IERC20(usdc).balanceOf(maker);
        console.log("Remaining USDC balance:", usdcBalanceAfter);
        console.log("USDC spent:", usdcBalance - usdcBalanceAfter);
        
        vm.stopBroadcast();
        
        console.log("=== Deposit Completed Successfully ===");
        console.log("Maker can now use vault balance for orders");
    }
}

