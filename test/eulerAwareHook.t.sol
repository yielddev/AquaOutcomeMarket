// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Aqua } from "@1inch/aqua/src/Aqua.sol";

import { dynamic } from "@1inch/swap-vm/test/utils/Dynamic.sol";

import { SwapVM, ISwapVM } from "swap-vm/SwapVM.sol";
import { MakerTraitsLib } from "swap-vm/libs/MakerTraits.sol";
import { TakerTraitsLib } from "swap-vm/libs/TakerTraits.sol";
import { OpcodesDebugCustom } from "../src/opcodes/OpcodesDebugCustom.sol";
import { OpcodesCustom } from "../src/opcodes/OpcodesCustom.sol";
import { CustomSwapVMRouter } from "../src/routers/CustomSwapVMRouter.sol";
import { MakerMintingHook } from "../src/hooks/MakerMintingHook.sol";
import { PredictionMarket } from "../src/market/PredictionMarket.sol";
import { PredictionToken } from "../src/market/PredictionToken.sol";
import { IEthereumVaultConnector, IEVC } from "euler-interfaces/IEthereumVaultConnector.sol";
import { IEVault } from "euler-interfaces/IEVault.sol";

import { ITakerCallbacks } from "swap-vm/interfaces/ITakerCallbacks.sol";
import { Program, ProgramBuilder } from "@1inch/swap-vm/test/utils/ProgramBuilder.sol";
import { pmAmm } from "../src/instructions/pmAmm.sol";
import "forge-std/console.sol";

import { MockToken } from "./mocks/MockToken.sol";
import { MockCollateral } from "./mocks/MockCollateral.sol";
import { MockWETH } from "./mocks/MockWETH.sol";
import { MockEVC } from "./mocks/MockEVC.sol";
import { MockSupplyVault } from "./mocks/MockSupplyVault.sol";
import { MockBorrowVault } from "./mocks/MockBorrowVault.sol";

contract PredictionMarketTestBase is Test {
    PredictionMarket public predictionMarket;
    PredictionToken public no;
    PredictionToken public yes;
    MockToken public underlying;
    MockCollateral public collateral;

    function setUp() public virtual {
        collateral = new MockCollateral("Collateral", "COL");
        underlying = new MockToken("Underlying", "UND");
        predictionMarket = new PredictionMarket(address(collateral), address(underlying), "Prediction Market");
        no = PredictionToken(predictionMarket.no());
        yes = PredictionToken(predictionMarket.yes());
    }
}

contract EulerAwareHookTest is PredictionMarketTestBase, OpcodesDebugCustom {
    using ProgramBuilder for Program;

    Aqua public immutable aqua = new Aqua();

    constructor() OpcodesDebugCustom(address(new Aqua())) {
        // Constructor body
    }

    CustomSwapVMRouter public swapVM;
    MockToken public tokenA;
    MockToken public tokenB;

    address public maker;
    uint256 public makerPrivateKey;
    address public taker = makeAddr("taker");

    MakerMintingHook public makerMintingHook;
    MockEVC public evc;
    MockSupplyVault public supplyVault;
    MockBorrowVault public borrowVault;
    MockSupplyVault public collateralVault; // Vault where maker deposits WETH as collateral to borrow against
    MockWETH public weth; // WETH used as collateral in collateralVault

    function setUp() public override {
        super.setUp();
        // Setup maker with known private key for signing
        makerPrivateKey = 0x1234;
        maker = vm.addr(makerPrivateKey);

        // Deploy custom SwapVM router with pmAmm opcodes
        swapVM = new CustomSwapVMRouter(address(aqua), "SwapVM", "1.0.0");

        // Deploy mock tokens
        tokenA = MockToken(address(no));
        tokenB = MockToken(address(yes));

        // Deploy mock EVC and vaults
        evc = new MockEVC();
        supplyVault = new MockSupplyVault(address(collateral));
        supplyVault.setEVC(address(evc)); // Enable borrowing from supplyVault
        borrowVault = new MockBorrowVault(address(collateral));
        borrowVault.setEVC(address(evc));
        
        // Deploy WETH and collateral vault that uses WETH
        weth = new MockWETH();
        collateralVault = new MockSupplyVault(address(weth)); // Collateral vault uses WETH, not prediction market collateral

        // Setup initial balances
        // Mint collateral to maker for the hook to use
        collateral.mint(maker, 1000e6);
        // Mint collateral to supply vault for withdrawals
        collateral.mint(address(supplyVault), 5000e6);

        // Approve SwapVM to spend tokens
        vm.prank(maker);
        tokenA.approve(address(swapVM), type(uint256).max);
        
        // Approve Aqua to pull tokens from maker (required for Aqua.pull())
        vm.prank(maker);
        tokenA.approve(address(aqua), type(uint256).max);
        vm.prank(maker);
        tokenB.approve(address(aqua), type(uint256).max);

        // Deploy hook with mock EVC
        makerMintingHook = new MakerMintingHook(IEthereumVaultConnector(payable(address(evc))), address(swapVM));
            
        vm.prank(maker);
        evc.setAccountOperator(maker, address(makerMintingHook), true);
        
        // Approve hook contract to transfer collateral from maker (required for preTransferOut hook)
        vm.prank(maker);
        collateral.approve(address(makerMintingHook), type(uint256).max);

        // Approve EVC to call vaults on behalf of maker
        vm.prank(maker);
        collateral.approve(address(evc), type(uint256).max);

        // Setup supply vault: maker deposits collateral
        vm.prank(maker);
        collateral.approve(address(supplyVault), type(uint256).max);
        vm.prank(maker);
        supplyVault.deposit(500e6, maker);

        vm.label(address(makerMintingHook), "makerMintingHook");
        vm.label(address(predictionMarket), "predictionMarket");
        vm.label(address(collateral), "collateral");
        vm.label(address(underlying), "underlying");
        vm.label(address(no), "no");
        vm.label(address(yes), "yes");
        vm.label(address(tokenA), "tokenA");
        vm.label(address(tokenB), "tokenB");
        vm.label(address(swapVM), "swapVM");
        vm.label(address(aqua), "aqua");
        vm.label(address(maker), "maker");
        vm.label(address(taker), "taker");
        vm.label(address(evc), "evc");
        vm.label(address(supplyVault), "supplyVault");
        vm.label(address(borrowVault), "borrowVault");
        vm.label(address(collateralVault), "collateralVault");
        vm.label(address(weth), "weth");
    }

    function test_HooksWithSupplyVault() public {
        Program memory p = ProgramBuilder.init(_opcodes());

        bytes memory programBytes = bytes.concat(
            p.build(pmAmm._pmAmmSwap, abi.encode(1764410735))
        );

        ISwapVM.Order memory order = MakerTraitsLib.build(MakerTraitsLib.Args({
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
            preTransferOutTarget: address(makerMintingHook),
            preTransferOutData: abi.encode(address(predictionMarket), address(supplyVault), true, false),
            postTransferOutTarget: address(0),
            postTransferOutData: "",
            program: programBytes
        }));
        bytes32 orderHash = swapVM.hash(order);

        // virtual balance of 10k each side
        // confirm not actual balances
        assertEq(tokenA.balanceOf(maker), 0);
        assertEq(tokenB.balanceOf(maker), 0);
        vm.prank(maker);
        bytes32 strategyHash = aqua.ship(
            address(swapVM),
            abi.encode(order),
            dynamic([address(tokenA), address(tokenB)]),
            dynamic([uint256(10_000e6), uint256(10_000e6)]) // 50/50 probabiltity 
        );
        assertEq(strategyHash, orderHash, "Strategy hash mismatch");

        // === Create TakerData with Hook Data ===
        bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
            taker: taker,
            isExactIn: true,
            shouldUnwrapWeth: false,
            isStrictThresholdAmount: false,
            isFirstTransferFromTaker: false,
            useTransferFromAndAquaPush: true,
            threshold: "", // min TokenA to receive
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

        // === Execute Swap ===
        // Mint collateral to taker and mint prediction tokens through the market
        collateral.mint(taker, 1000e6);
        vm.prank(taker);
        collateral.approve(address(predictionMarket), 1000e6);
        vm.prank(taker);
        predictionMarket.mint(taker, 1000e6);
        
        // Taker needs to approve tokens for the swap
        vm.prank(taker);
        tokenB.approve(address(aqua), type(uint256).max);
        vm.prank(taker);
        tokenB.approve(address(swapVM), type(uint256).max);
        vm.prank(taker);
        tokenA.approve(address(swapVM), type(uint256).max);
        
        vm.prank(taker);
        (uint256 amountIn, uint256 amountOut,) = swapVM.swap(
            order,
            address(tokenB), // tokenIn
            address(tokenA), // tokenOut
            50e6,           // amount of tokenB to spend
            takerData
        );
        (uint256 balanceIn, uint256 balanceOut) = aqua.safeBalances(maker, address(swapVM), orderHash, address(tokenB), address(tokenA));
        console.log("balanceIn", balanceIn/1e6);
        console.log("balanceOut", balanceOut/1e6);
        assertEq(balanceIn, 10_050e6);
        // real balance 
        uint256 takerBalance = tokenA.balanceOf(taker);
        assertEq(tokenA.balanceOf(taker), 1000e6+amountOut);
        assertEq(tokenB.balanceOf(maker), amountIn+amountOut);

        // swap in reverse against existing balance
        vm.prank(taker);
        (amountIn, amountOut,) = swapVM.swap(
            order,
            address(tokenA), // tokenIn
            address(tokenB), // tokenOut
            amountIn+amountOut,           // previous inventory
            takerData
        );

        // check real balances
        uint256 realBalance = tokenB.balanceOf(maker);
        assertEq(realBalance, 0); // back in equilibrium
    }

    function test_HooksWithdrawFromVault() public {
        Program memory p = ProgramBuilder.init(_opcodes());

        bytes memory programBytes = bytes.concat(
            p.build(pmAmm._pmAmmSwap, abi.encode(1764410735))
        );

        ISwapVM.Order memory order = MakerTraitsLib.build(MakerTraitsLib.Args({
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
            preTransferOutTarget: address(makerMintingHook),
            preTransferOutData: abi.encode(address(predictionMarket), address(supplyVault), false, false),
            postTransferOutTarget: address(0),
            postTransferOutData: "",
            program: programBytes
        }));
        bytes32 orderHash = swapVM.hash(order);

        // Record initial vault balance (maker has 500e6 deposited)
        uint256 initialVaultShares = supplyVault.balanceOf(maker);
        uint256 initialVaultAssets = supplyVault.convertToAssets(initialVaultShares);
        console.log("Initial vault shares", initialVaultShares/1e6);
        console.log("Initial vault assets", initialVaultAssets/1e6);

        vm.prank(maker);
        bytes32 strategyHash = aqua.ship(
            address(swapVM),
            abi.encode(order),
            dynamic([address(tokenA), address(tokenB)]),
            dynamic([uint256(10_000e6), uint256(10_000e6)])
        );
        assertEq(strategyHash, orderHash, "Strategy hash mismatch");

        bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
            taker: taker,
            isExactIn: true,
            shouldUnwrapWeth: false,
            isStrictThresholdAmount: false,
            isFirstTransferFromTaker: false,
            useTransferFromAndAquaPush: true,
            threshold: "",
            to: address(0),
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

        // Setup taker
        collateral.mint(taker, 1000e6);
        vm.prank(taker);
        collateral.approve(address(predictionMarket), 1000e6);
        vm.prank(taker);
        predictionMarket.mint(taker, 1000e6);
        
        vm.prank(taker);
        tokenB.approve(address(aqua), type(uint256).max);
        vm.prank(taker);
        tokenB.approve(address(swapVM), type(uint256).max);
        vm.prank(taker);
        tokenA.approve(address(swapVM), type(uint256).max);
        
        // Execute swap that will trigger withdrawal from vault
        vm.prank(taker);
        (uint256 amountIn, uint256 amountOut,) = swapVM.swap(
            order,
            address(tokenB),
            address(tokenA),
            50e6,
            takerData
        );

        // Verify withdrawal occurred - vault balance should have decreased
        uint256 finalVaultShares = supplyVault.balanceOf(maker);
        uint256 finalVaultAssets = supplyVault.convertToAssets(finalVaultShares);
        console.log("Final vault shares", finalVaultShares/1e6);
        console.log("Final vault assets", finalVaultAssets/1e6);
        console.log("Amount out", amountOut/1e6);
        
        assertLt(finalVaultShares, initialVaultShares, "Vault shares should have decreased");
        assertLt(finalVaultAssets, initialVaultAssets, "Vault assets should have decreased");
        
        // Verify no borrow occurred (since canBorrow is false)
        uint256 debt = borrowVault.debtOf(maker);
        assertEq(debt, 0, "No borrow should have occurred");
    }

    function test_HooksWithPartialVaultAndBorrow() public {
        Program memory p = ProgramBuilder.init(_opcodes());

        bytes memory programBytes = bytes.concat(
            p.build(pmAmm._pmAmmSwap, abi.encode(1764410735))
        );

        // Setup: Maker has partial funds in supplyVault (200e6) but needs more
        // Maker also has WETH in collateralVault that can be used as collateral to borrow
        
        // First, reduce maker's supplyVault balance to partial amount
        vm.prank(maker);
        supplyVault.withdraw(300e6, maker, maker); // Withdraw 300e6, leaving 200e6
        
        // Mint WETH to maker and deposit it in collateralVault as collateral
        weth.mint(maker, 1000e18); // Mint 1000 WETH (using 18 decimals like real WETH)
        vm.prank(maker);
        weth.approve(address(collateralVault), type(uint256).max);
        vm.prank(maker);
        collateralVault.deposit(1000e18, maker); // Deposit 1000 WETH as collateral
        
        // Enable collateral in EVC (maker's WETH in collateralVault can be used to borrow)
        vm.prank(maker);
        evc.enableCollateral(maker, address(collateralVault));
        
        // Fund supplyVault so it has liquidity to lend (in prediction market collateral token)
        // We need to deposit into the vault, not just mint to the address
        collateral.mint(address(this), 20000e6);
        collateral.approve(address(supplyVault), 20000e6);
        supplyVault.deposit(20000e6, address(this)); // Deposit as a separate account to provide liquidity

        ISwapVM.Order memory order = MakerTraitsLib.build(MakerTraitsLib.Args({
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
            preTransferOutTarget: address(makerMintingHook),
            preTransferOutData: abi.encode(address(predictionMarket), address(supplyVault), false, true), // useBalance=false, canBorrow=true
            postTransferOutTarget: address(0),
            postTransferOutData: "",
            program: programBytes
        }));
        bytes32 orderHash = swapVM.hash(order);

        // Record initial balances
        uint256 initialSupplyVaultShares = supplyVault.balanceOf(maker);
        uint256 initialSupplyVaultAssets = supplyVault.convertToAssets(initialSupplyVaultShares);
        uint256 initialCollateralVaultShares = collateralVault.balanceOf(maker);
        uint256 initialCollateralVaultAssets = collateralVault.convertToAssets(initialCollateralVaultShares);
        uint256 initialDebt = supplyVault.debtOf(maker);
        
        console.log("Initial supplyVault shares", initialSupplyVaultShares/1e6);
        console.log("Initial supplyVault assets", initialSupplyVaultAssets/1e6);
        console.log("Initial collateralVault shares", initialCollateralVaultShares/1e6);
        console.log("Initial collateralVault assets", initialCollateralVaultAssets/1e6);
        console.log("Initial debt", initialDebt/1e6);

        vm.prank(maker);
        bytes32 strategyHash = aqua.ship(
            address(swapVM),
            abi.encode(order),
            dynamic([address(tokenA), address(tokenB)]),
            dynamic([uint256(10_000e6), uint256(10_000e6)])
        );
        assertEq(strategyHash, orderHash, "Strategy hash mismatch");

        bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
            taker: taker,
            isExactIn: true,
            shouldUnwrapWeth: false,
            isStrictThresholdAmount: false,
            isFirstTransferFromTaker: false,
            useTransferFromAndAquaPush: true,
            threshold: "",
            to: address(0),
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

        // Setup taker
        collateral.mint(taker, 1000e6);
        vm.prank(taker);
        collateral.approve(address(predictionMarket), 1000e6);
        vm.prank(taker);
        predictionMarket.mint(taker, 1000e6);
        
        vm.prank(taker);
        tokenB.approve(address(aqua), type(uint256).max);
        vm.prank(taker);
        tokenB.approve(address(swapVM), type(uint256).max);
        vm.prank(taker);
        tokenA.approve(address(swapVM), type(uint256).max);
        
        // Execute swap that will trigger partial withdrawal + borrow
        // Use a larger swap amount to require more than what's available in supplyVault (200e6)
        vm.prank(taker);
        (uint256 amountIn, uint256 amountOut,) = swapVM.swap(
            order,
            address(tokenB),
            address(tokenA),
            500e6, // Larger swap to require more than 200e6 available in vault
            takerData
        );

        // Verify results
        uint256 finalSupplyVaultShares = supplyVault.balanceOf(maker);
        uint256 finalSupplyVaultAssets = supplyVault.convertToAssets(finalSupplyVaultShares);
        uint256 finalDebt = supplyVault.debtOf(maker);
        uint256 finalCollateralVaultShares = collateralVault.balanceOf(maker);
        uint256 finalCollateralVaultAssets = collateralVault.convertToAssets(finalCollateralVaultShares);
        
        console.log("Final supplyVault shares", finalSupplyVaultShares/1e6);
        console.log("Final supplyVault assets", finalSupplyVaultAssets/1e6);
        console.log("Final debt", finalDebt/1e6);
        console.log("Final collateralVault shares", finalCollateralVaultShares/1e6);
        console.log("Final collateralVault assets", finalCollateralVaultAssets/1e6);
        console.log("Amount out needed", amountOut/1e6);
        
        // Verify supplyVault was partially withdrawn (should be 0 or very small)
        assertLt(finalSupplyVaultShares, initialSupplyVaultShares, "Supply vault shares should have decreased");
        
        // Verify borrow occurred (debt should be > 0)
        assertGt(finalDebt, 0, "Borrow should have occurred");
        
        // Verify collateral vault balance unchanged (collateral is still there, just used as backing)
        assertEq(finalCollateralVaultShares, initialCollateralVaultShares, "Collateral vault shares should remain unchanged");
        
        // Verify the total obtained (withdrawn + borrowed) covers the needed amount
        uint256 withdrawn = initialSupplyVaultAssets - finalSupplyVaultAssets;
        uint256 borrowed = finalDebt - initialDebt;
        uint256 totalObtained = withdrawn + borrowed;
        console.log("Withdrawn from supplyVault", withdrawn/1e6);
        console.log("Borrowed from supplyVault", borrowed/1e6);
        console.log("Total obtained", totalObtained/1e6);
        
        // The total obtained should be approximately equal to amountOut (allowing for small rounding)
        assertGe(totalObtained, amountOut * 95 / 100, "Total obtained should cover most of the needed amount");
    }
}
