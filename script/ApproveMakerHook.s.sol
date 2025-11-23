// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MakerMintingHook} from "../src/hooks/MakerMintingHook.sol";
import {IPredictionMarket} from "../src/market/IPredictionMarket.sol";
import {IEthereumVaultConnector} from "euler-interfaces/IEthereumVaultConnector.sol";
import "../test/lib/ArbitrumLib.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

/// @notice Script for maker to approve MakerMintingHook to transfer collateral
/// @dev This is required for the hook to mint prediction tokens during swaps
/// Usage:
///   Required: DEPLOYMENT_JSON_PATH (e.g., "script/json/deployment-31337.json")
///   Required: PRIVATE_KEY (maker's private key)
///   Optional: MARKET_ADDRESS (if not provided, will approve for all markets in JSON)
///   forge script script/ApproveMakerHook.s.sol:ApproveMakerHook --rpc-url <rpc_url> --broadcast
contract ApproveMakerHook is Script {
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
        
        // Read addresses from JSON
        address makerMintingHook = json.readAddress(".makerMintingHook");
        address aqua = json.readAddress(".aqua");
        address f1Market = json.readAddress(".f1Market");
        address bitcoinUnderMarket = json.readAddress(".bitcoinUnderMarket");
        address lakersWinMarket = json.readAddress(".lakersWinMarket");
        
        // Get EVC address (Arbitrum)
        address evc = ArbitrumLib.EVC;
        
        // Get maker's private key
        uint256 makerPrivateKey = vm.envUint("PRIVATE_KEY");
        address maker = vm.addr(makerPrivateKey);
        
        vm.startBroadcast(makerPrivateKey);
        
        console.log("=== Maker Hook Approval ===");
        console.log("Maker:", maker);
        console.log("MakerMintingHook:", makerMintingHook);
        console.log("Aqua:", aqua);
        console.log("EVC:", evc);
        
        // Get collateral address (USDC)
        address collateral = ArbitrumLib.USDC;
        
        // Check current allowance
        uint256 currentAllowance = IERC20(collateral).allowance(maker, makerMintingHook);
        console.log("Current allowance:", currentAllowance);
        
        // Approve MakerMintingHook to transfer collateral
        if (currentAllowance < type(uint256).max) {
            IERC20(collateral).approve(makerMintingHook, type(uint256).max);
            console.log("Approved MakerMintingHook to transfer collateral");
            
            // Verify approval
            uint256 newAllowance = IERC20(collateral).allowance(maker, makerMintingHook);
            console.log("New allowance:", newAllowance);
            require(newAllowance == type(uint256).max, "Approval failed");
        } else {
            console.log("Hook already has maximum allowance");
        }
        
        // Log market addresses for reference
        console.log("=== Market Addresses ===");
        console.log("F1 Market:", f1Market);
        console.log("Bitcoin Under Market:", bitcoinUnderMarket);
        console.log("Lakers Win Market:", lakersWinMarket);
        
        // Verify collateral matches for all markets
        address f1Collateral = IPredictionMarket(f1Market).collateral();
        address bitcoinCollateral = IPredictionMarket(bitcoinUnderMarket).collateral();
        address lakersCollateral = IPredictionMarket(lakersWinMarket).collateral();
        
        console.log("=== Collateral Addresses ===");
        console.log("F1 Market Collateral:", f1Collateral);
        console.log("Bitcoin Under Market Collateral:", bitcoinCollateral);
        console.log("Lakers Win Market Collateral:", lakersCollateral);
        
        require(f1Collateral == collateral, "F1 market collateral mismatch");
        require(bitcoinCollateral == collateral, "Bitcoin market collateral mismatch");
        require(lakersCollateral == collateral, "Lakers market collateral mismatch");
        
        // Approve MakerMintingHook as EVC operator
        // This allows the hook to operate on behalf of the maker in the EVC system
        // (e.g., withdraw from vaults, borrow from vaults)
        console.log("=== Setting EVC Operator ===");
        
        // Check current operator status
        bool isOperatorBefore = IEthereumVaultConnector(payable(evc)).isAccountOperatorAuthorized(maker, makerMintingHook);
        console.log("Is operator before:", isOperatorBefore);
        
        if (!isOperatorBefore) {
            IEthereumVaultConnector(payable(evc)).setAccountOperator(maker, makerMintingHook, true);
            console.log("Set MakerMintingHook as EVC operator for maker");
            
            // Verify operator status
            bool isOperatorAfter = IEthereumVaultConnector(payable(evc)).isAccountOperatorAuthorized(maker, makerMintingHook);
            console.log("Is operator after:", isOperatorAfter);
            require(isOperatorAfter, "Failed to set EVC operator");
        } else {
            console.log("Hook already authorized as EVC operator");
        }
        
        // Approve Aqua for prediction tokens (NO and YES tokens) for all markets
        // This is needed because MakerMintingHook mints tokens to the maker,
        // and then Aqua needs to pull them during swaps
        console.log("=== Approving Aqua for Prediction Tokens ===");
        
        // Approve for F1 Market
        address f1No = IPredictionMarket(f1Market).no();
        address f1Yes = IPredictionMarket(f1Market).yes();
        _approveTokenForAqua(f1No, aqua, maker, "F1 Market NO token");
        _approveTokenForAqua(f1Yes, aqua, maker, "F1 Market YES token");
        
        // Approve for Bitcoin Under Market
        address bitcoinNo = IPredictionMarket(bitcoinUnderMarket).no();
        address bitcoinYes = IPredictionMarket(bitcoinUnderMarket).yes();
        _approveTokenForAqua(bitcoinNo, aqua, maker, "Bitcoin Under Market NO token");
        _approveTokenForAqua(bitcoinYes, aqua, maker, "Bitcoin Under Market YES token");
        
        // Approve for Lakers Win Market
        address lakersNo = IPredictionMarket(lakersWinMarket).no();
        address lakersYes = IPredictionMarket(lakersWinMarket).yes();
        _approveTokenForAqua(lakersNo, aqua, maker, "Lakers Win Market NO token");
        _approveTokenForAqua(lakersYes, aqua, maker, "Lakers Win Market YES token");
        
        vm.stopBroadcast();
        
        console.log("=== Approval Completed Successfully ===");
        console.log("MakerMintingHook can now:");
        console.log("  1. Transfer collateral from maker");
        console.log("  2. Operate on maker's behalf in EVC (withdraw/borrow from vaults)");
        console.log("Aqua can now:");
        console.log("  1. Pull prediction tokens (NO/YES) from maker during swaps");
    }
    
    /// @notice Helper function to approve Aqua for a token
    function _approveTokenForAqua(
        address token,
        address aqua,
        address maker,
        string memory tokenName
    ) internal {
        uint256 currentAllowance = IERC20(token).allowance(maker, aqua);
        console.log(string.concat(tokenName, " current Aqua allowance:"), currentAllowance);
        
        if (currentAllowance < type(uint256).max) {
            IERC20(token).approve(aqua, type(uint256).max);
            console.log(string.concat("Approved Aqua for ", tokenName));
            
            // Verify approval
            uint256 newAllowance = IERC20(token).allowance(maker, aqua);
            console.log(string.concat(tokenName, " new Aqua allowance:"), newAllowance);
            require(newAllowance == type(uint256).max, string.concat("Failed to approve Aqua for ", tokenName));
        } else {
            console.log(string.concat(tokenName, " already has maximum Aqua allowance"));
        }
    }
}

