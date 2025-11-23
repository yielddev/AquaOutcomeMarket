// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {ISwapVM} from "swap-vm/interfaces/ISwapVM.sol";
import {CustomSwapVMRouter} from "../src/routers/CustomSwapVMRouter.sol";
import {Aqua} from "@1inch/aqua/src/Aqua.sol";
import {TakerTraitsLib} from "swap-vm/libs/TakerTraits.sol";
import {MakerTraitsLib} from "swap-vm/libs/MakerTraits.sol";
import {Program, ProgramBuilder} from "@1inch/swap-vm/test/utils/ProgramBuilder.sol";
import {Fee, FeeArgsBuilder} from "swap-vm/instructions/Fee.sol";
import {pmAmm} from "../src/instructions/pmAmm.sol";
import {OpcodesDebugCustom} from "../src/opcodes/OpcodesDebugCustom.sol";
import {IPredictionMarket} from "../src/market/IPredictionMarket.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

contract ExecuteSwap is Script, OpcodesDebugCustom {
    using ProgramBuilder for Program;

    constructor() OpcodesDebugCustom(address(new Aqua())) {
        // Constructor creates Aqua for OpcodesDebugCustom initialization
    }

    function run() public {
        // Get private key from environment variable
        uint256 takerPrivateKey = vm.envUint("PRIVATE_KEY");
        address taker = vm.addr(takerPrivateKey);

        // Get chain ID
        uint256 chainId = block.chainid;
        
        // Try to load deployment data (optional)
        address swapVMAddress;
        address aquaAddress;
        address makerMintingHook;
        bytes32 orderHash;
        address marketAddress;
        address maker;
        
        try vm.readFile(string.concat("./deployments/deployment-", vm.toString(chainId), ".json")) returns (string memory deploymentJson) {
            // Load from deployment JSON
            swapVMAddress = vm.parseJsonAddress(deploymentJson, ".swapVM");
            aquaAddress = vm.parseJsonAddress(deploymentJson, ".aqua");
            makerMintingHook = vm.parseJsonAddress(deploymentJson, ".makerMintingHook");
            
            // Try to get order hash from JSON, but allow override via env var
            try vm.envBytes32("ORDER_HASH") returns (bytes32 envOrderHash) {
                orderHash = envOrderHash;
            } catch {
                orderHash = vm.parseJsonBytes32(deploymentJson, ".f1OrderHash");
            }
            
            // Try to get market from JSON, but allow override via env var
            try vm.envAddress("MARKET_ADDRESS") returns (address envMarket) {
                marketAddress = envMarket;
            } catch {
                marketAddress = vm.parseJsonAddress(deploymentJson, ".f1Market");
            }
            
            // Try to get maker from JSON, but allow override via env var
            try vm.envAddress("MAKER_ADDRESS") returns (address envMaker) {
                maker = envMaker;
            } catch {
                maker = vm.parseJsonAddress(deploymentJson, ".deployer");
            }
        } catch {
            // If no deployment JSON, require all addresses from env vars
            swapVMAddress = vm.envAddress("SWAPVM_ADDRESS");
            aquaAddress = vm.envAddress("AQUA_ADDRESS");
            makerMintingHook = vm.envAddress("MAKER_MINTING_HOOK_ADDRESS");
            orderHash = vm.envBytes32("ORDER_HASH");
            marketAddress = vm.envAddress("MARKET_ADDRESS");
            maker = vm.envAddress("MAKER_ADDRESS");
        }
        
        // Get swap parameters from environment variables (required)
        address tokenIn = vm.envAddress("TOKEN_IN");
        address tokenOut = vm.envAddress("TOKEN_OUT");
        uint256 amountIn = vm.envUint("AMOUNT_IN");
        
        // Get yield vault address (default from ArbitrumLib)
        address yieldVault;
        try vm.envAddress("YIELD_VAULT") returns (address envVault) {
            yieldVault = envVault;
        } catch {
            // Default to EVC USDC vault on Arbitrum
            yieldVault = 0x0a1eCC5Fe8C9be3C809844fcBe615B46A869b899;
        }
        
        // Get horizon (expiry timestamp) - default to 1 day from now
        uint256 horizon = block.timestamp + 1 days;
        try vm.envUint("HORIZON") returns (uint256 envHorizon) {
            horizon = envHorizon;
        } catch {}

        vm.startBroadcast(takerPrivateKey);

        // Reconstruct the maker order
        ISwapVM.Order memory order = getMakerOrder(
            maker,
            marketAddress,
            makerMintingHook,
            yieldVault,
            horizon
        );

        // Verify order hash matches
        bytes32 computedOrderHash = ISwapVM(swapVMAddress).hash(order);
        require(computedOrderHash == orderHash, "Order hash mismatch");

        // Build taker data
        bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
            taker: taker,
            isExactIn: true,
            shouldUnwrapWeth: false,
            isStrictThresholdAmount: false,
            isFirstTransferFromTaker: false,
            useTransferFromAndAquaPush: true,
            threshold: "", // min tokenOut to receive
            to: address(0), // 0 = taker
            hasPreTransferInCallback: false,
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

        // Get quote before executing swap
        console.log("=== Getting Quote ===");
        console.log("Order Hash:");
        console.logBytes32(orderHash);
        console.log("Token In:", tokenIn);
        console.log("Token Out:", tokenOut);
        console.log("Amount In:", amountIn);
        
        (uint256 quotedAmountIn, uint256 quotedAmountOut, bytes32 quotedOrderHash) = 
            ISwapVM(swapVMAddress).quote(order, tokenIn, tokenOut, amountIn, takerData);
        
        console.log("=== Quote Results ===");
        console.log("Quoted Amount In:", quotedAmountIn);
        console.log("Quoted Amount Out:", quotedAmountOut);
        console.log("Quoted Order Hash:");
        console.logBytes32(quotedOrderHash);
        console.log("Price (amountOut/amountIn):", (quotedAmountOut * 1e18) / quotedAmountIn);
        
        // Check token balances before swap
        uint256 balanceInBefore = IERC20(tokenIn).balanceOf(taker);
        uint256 balanceOutBefore = IERC20(tokenOut).balanceOf(taker);
        
        console.log("=== Pre-Swap Balances ===");
        console.log("Taker Token In Balance:", balanceInBefore);
        console.log("Taker Token Out Balance:", balanceOutBefore);
        
        // Ensure taker has approved tokens
        IERC20(tokenIn).approve(aquaAddress, type(uint256).max);
        IERC20(tokenIn).approve(swapVMAddress, type(uint256).max);
        IERC20(tokenOut).approve(swapVMAddress, type(uint256).max);
        
        // Execute swap
        console.log("=== Executing Swap ===");
        (uint256 actualAmountIn, uint256 actualAmountOut, bytes32 swapOrderHash) = 
            ISwapVM(swapVMAddress).swap(order, tokenIn, tokenOut, amountIn, takerData);
        
        console.log("=== Swap Results ===");
        console.log("Actual Amount In:", actualAmountIn);
        console.log("Actual Amount Out:", actualAmountOut);
        console.log("Swap Order Hash:");
        console.logBytes32(swapOrderHash);
        
        // Check token balances after swap
        uint256 balanceInAfter = IERC20(tokenIn).balanceOf(taker);
        uint256 balanceOutAfter = IERC20(tokenOut).balanceOf(taker);
        
        console.log("=== Post-Swap Balances ===");
        console.log("Taker Token In Balance:", balanceInAfter);
        console.log("Taker Token Out Balance:", balanceOutAfter);
        console.log("Token In Spent:", balanceInBefore - balanceInAfter);
        console.log("Token Out Received:", balanceOutAfter - balanceOutBefore);
        
        // Verify amounts match
        require(actualAmountIn == quotedAmountIn, "Amount in mismatch between quote and swap");
        require(actualAmountOut == quotedAmountOut, "Amount out mismatch between quote and swap");
        
        vm.stopBroadcast();
        
        console.log("=== Swap Completed Successfully ===");
    }

    function getMakerOrder(
        address maker,
        address predictionMarket,
        address makerMintingHookAddress,
        address yieldVault,
        uint256 horizon
    ) public view returns (ISwapVM.Order memory) {
        Program memory p = ProgramBuilder.init(_opcodes());
        bytes memory programBytes = bytes.concat(
            p.build(Fee._flatFeeAmountInXD, FeeArgsBuilder.buildFlatFee(uint32(3e6))),
            p.build(pmAmm._pmAmmSwap, abi.encode(horizon))
        );
        ISwapVM.Order memory order = MakerTraitsLib.build(
            MakerTraitsLib.Args({
                maker: maker,
                shouldUnwrapWeth: false,
                useAquaInsteadOfSignature: true,
                allowZeroAmountIn: false,
                receiver: address(0),
                hasPreTransferInHook: false,
                hasPostTransferInHook: false,
                hasPreTransferOutHook: true,
                hasPostTransferOutHook: false,
                preTransferInTarget: address(0),
                preTransferInData: "",
                postTransferInTarget: address(0),
                postTransferInData: "",
                preTransferOutTarget: makerMintingHookAddress,
                preTransferOutData: abi.encode(
                    address(predictionMarket),
                    address(yieldVault),
                    true,
                    true
                ),
                postTransferOutTarget: address(0),
                postTransferOutData: "",
                program: programBytes
            })
        );
        return order;
    }
}

