// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {ISwapVM} from "swap-vm/interfaces/ISwapVM.sol";
import {CustomSwapVMRouter} from "../src/routers/CustomSwapVMRouter.sol";
import {Aqua} from "@1inch/aqua/src/Aqua.sol";
import {TakerTraitsLib} from "swap-vm/libs/TakerTraits.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TakerCallback} from "./TakerCallback.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

/// @notice Script for takers to execute swaps on prediction markets
/// @dev Reads order data from deployment JSON file
/// Usage:
///   Required: DEPLOYMENT_JSON_PATH (e.g., "script/json/deployment-31337.json")
///   Required: ORDER_KEY (one of: "f1Order", "bitcoinUnderOrder", "lakersWinOrder")
///   Required: TOKEN_IN, TOKEN_OUT, AMOUNT_IN
///   Required: TAKER_PRIVATE_KEY
///   Optional: CHAIN_ID (default: reads from JSON or uses block.chainid)
///   forge script script/ExecuteTakerSwap.s.sol:ExecuteTakerSwap --rpc-url <rpc_url> --broadcast
contract ExecuteTakerSwap is Script {
    using stdJson for string;

    function run() public {
        // Get deployment JSON path from environment
        string memory jsonPath = vm.envString("DEPLOYMENT_JSON_PATH");
        
        // Read the JSON file content first - try the path as-is, then with script/ prefix
        string memory json;
        try vm.readFile(jsonPath) returns (string memory fileContent) {
            json = fileContent;
        } catch {
            // If file not found, try prepending "script/" to the path
            string memory altPath = string.concat("script/", jsonPath);
            json = vm.readFile(altPath);
        }
        
        // Get which order to use (f1Order, bitcoinUnderOrder, or lakersWinOrder)
        string memory orderKey = vm.envString("ORDER_KEY");
        
        // Read order bytes from JSON - the structure is nested: .{orderKey}.{orderKey}
        bytes memory orderBytes = json.readBytes(string.concat(".", orderKey, ".", orderKey));
        
        // Decode the order struct from bytes
        ISwapVM.Order memory order = abi.decode(orderBytes, (ISwapVM.Order));
        
        // Read addresses from JSON
        address swapVMAddress = json.readAddress(".swapVM");
        address aquaAddress = json.readAddress(".aqua");
        
        // Get swap parameters from environment
        address tokenIn = vm.envAddress("TOKEN_IN");
        address tokenOut = vm.envAddress("TOKEN_OUT");
        uint256 amountIn = vm.envUint("AMOUNT_IN");
        
        // Compute order hash
        bytes32 orderHash = ISwapVM(swapVMAddress).hash(order);
        
        console.log("=== Taker Swap Configuration ===");
        console.log("Order Key:", orderKey);
        console.log("SwapVM:", swapVMAddress);
        console.log("Aqua:", aquaAddress);
        console.log("Maker:", order.maker);
        console.log("Token In:", tokenIn);
        console.log("Token Out:", tokenOut);
        console.log("Amount In:", amountIn);
        console.log("Order Hash:");
        console.logBytes32(orderHash);
        
        _executeSwap(order, orderHash, swapVMAddress, aquaAddress, tokenIn, tokenOut, amountIn);
    }

    function _executeSwap(
        ISwapVM.Order memory order,
        bytes32 orderHash,
        address swapVMAddress,
        address aquaAddress,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {
        uint256 takerPrivateKey = vm.envUint("TAKER_PRIVATE_KEY");
        address taker = vm.addr(takerPrivateKey);
        
        vm.startBroadcast(takerPrivateKey);

        console.log("=== Taker Swap Execution ===");
        console.log("Taker:", taker);

        // Deploy TakerCallback contract that implements ITakerCallbacks
        TakerCallback takerCallback = new TakerCallback(Aqua(aquaAddress), swapVMAddress);
        address callbackAddr = address(takerCallback);
        console.log("TakerCallback deployed at:", callbackAddr);

        // Build taker data with callback enabled
        bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
            taker: callbackAddr, // Use callback contract as taker
            isExactIn: true,
            shouldUnwrapWeth: false,
            isStrictThresholdAmount: false,
            isFirstTransferFromTaker: false,
            useTransferFromAndAquaPush: false, // Use callback instead
            threshold: abi.encodePacked(uint256(1)),
            to: taker, // Send output tokens to the actual taker address
            hasPreTransferInCallback: true, // Enable callback
            hasPreTransferOutCallback: false,
            preTransferInHookData: "",
            postTransferInHookData: "",
            preTransferOutHookData: "",
            postTransferOutHookData: "",
            preTransferInCallbackData: "",
            preTransferOutCallbackData: "",
            instructionsArgs: "",
            signature: ""
        }));

        // Check balances before swap
        uint256 tokenInBalanceBefore = IERC20(tokenIn).balanceOf(taker);
        uint256 tokenOutBalanceBefore = IERC20(tokenOut).balanceOf(taker);
        
        console.log("=== Pre-Swap Balances ===");
        console.log("Token In Balance:", tokenInBalanceBefore);
        console.log("Token Out Balance:", tokenOutBalanceBefore);
        
        require(tokenInBalanceBefore >= amountIn, "Insufficient tokenIn balance");

        // Get quote before executing swap
        console.log("=== Getting Quote ===");
        (uint256 quotedAmountIn, uint256 quotedAmountOut, bytes32 quotedOrderHash) = 
            ISwapVM(swapVMAddress).quote(order, tokenIn, tokenOut, amountIn, takerData);
        
        console.log("=== Quote Results ===");
        console.log("Quoted Amount In:", quotedAmountIn);
        console.log("Quoted Amount Out:", quotedAmountOut);
        console.log("Quoted Order Hash:");
        console.logBytes32(quotedOrderHash);
        if (quotedAmountIn > 0) {
            console.log("Price (amountOut/amountIn):", (quotedAmountOut * 1e18) / quotedAmountIn);
        }
        require(quotedAmountOut > 0, "Quote returned zero amountOut");

        // Transfer tokens to callback contract
        // Use transfer() since we're transferring from ourselves (no approval needed)
        IERC20(tokenIn).transfer(callbackAddr, amountIn);
        console.log("Transferred", amountIn, "tokenIn to TakerCallback");

        // Execute swap through TakerCallback contract
        // This ensures SwapVM can call preTransferInCallback on the callback contract
        console.log("=== Executing Swap ===");
        (uint256 actualAmountIn, uint256 actualAmountOut) = 
            takerCallback.swap(
                order,
                tokenIn,
                tokenOut,
                amountIn,
                takerData
            );
        
        console.log("=== Swap Results ===");
        console.log("Actual Amount In:", actualAmountIn);
        console.log("Actual Amount Out:", actualAmountOut);
        
        // Check balances after swap
        uint256 tokenInBalanceAfter = IERC20(tokenIn).balanceOf(taker);
        uint256 tokenOutBalanceAfter = IERC20(tokenOut).balanceOf(taker);
        
        console.log("=== Post-Swap Balances ===");
        console.log("Token In Balance:", tokenInBalanceAfter);
        console.log("Token Out Balance:", tokenOutBalanceAfter);
        console.log("Token In Spent:", tokenInBalanceBefore - tokenInBalanceAfter);
        console.log("Token Out Received:", tokenOutBalanceAfter - tokenOutBalanceBefore);
        
        // Check maker's balances
        (uint256 balanceIn, uint256 balanceOut) = Aqua(aquaAddress).safeBalances(
            order.maker, 
            swapVMAddress, 
            orderHash, 
            tokenIn, 
            tokenOut
        );
        
        console.log("=== Maker's Aqua Balances ===");
        console.log("Balance In:", balanceIn);
        console.log("Balance Out:", balanceOut);
        
        vm.stopBroadcast();
        console.log("=== Swap Completed Successfully ===");
    }
}
