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
import { IEthereumVaultConnector } from "euler-interfaces/IEthereumVaultConnector.sol";

import { ITakerCallbacks } from "swap-vm/interfaces/ITakerCallbacks.sol";
import { Program, ProgramBuilder } from "@1inch/swap-vm/test/utils/ProgramBuilder.sol";
import { pmAmm } from "../src/instructions/pmAmm.sol";
import "forge-std/console.sol";
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockCollateral is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
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
contract HooksTest is PredictionMarketTestBase, OpcodesDebugCustom {
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
    address public lendingVault;

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

        // Setup initial balances
        // Mint collateral to maker for the hook to use
        collateral.mint(maker, 1000e6);

        // Approve SwapVM to spend tokens
        vm.prank(maker);
        tokenA.approve(address(swapVM), type(uint256).max);
        
        // Approve Aqua to pull tokens from maker (required for Aqua.pull())
        vm.prank(maker);
        tokenA.approve(address(aqua), type(uint256).max);
        vm.prank(maker);
        tokenB.approve(address(aqua), type(uint256).max);

        lendingVault = address(2);
        
        makerMintingHook = new MakerMintingHook(IEthereumVaultConnector(payable(address(1))), address(swapVM)); // TODO: Set actual EVC address
        
        // Approve hook contract to transfer collateral from maker (required for preTransferOut hook)
        vm.prank(maker);
        collateral.approve(address(makerMintingHook), type(uint256).max);

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
    }

    function test_Hooks() public {
        Program memory p = ProgramBuilder.init(_opcodes());

        bytes memory programBytes = bytes.concat(
            p.build(pmAmm._pmAmmSwap, abi.encode(1764410735))
            // p.build(Extruction._extruction, abi.encode(address(predictionMarket), abi.encodeWithSelector(PredictionMarket.mint.selector, maker, 1000e6)))
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
            preTransferOutData: abi.encode(address(predictionMarket), address(lendingVault), true, false),
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
        console.log("balanceIn", balanceIn/1e18);
        console.log("balanceOut", balanceOut/1e18);
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
        assertApproxEqAbs(realBalance, 0, 1); // back in equilibrium (allow 1 wei rounding error from CDF precision)
    }

}