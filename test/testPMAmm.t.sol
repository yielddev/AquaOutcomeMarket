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

contract MockTaker is ITakerCallbacks {
    Aqua public immutable AQUA;
    SwapVM public immutable swapVM;

    address public immutable owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlySwapVM() {
        require(msg.sender == address(swapVM), "Not the SwapVM");
        _;
    }

    constructor(Aqua aqua, SwapVM swapVM_, address owner_) {
        AQUA = aqua;
        swapVM = swapVM_;
        owner = owner_;
    }

    function swap(
        ISwapVM.Order calldata order,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        bytes calldata takerTraitsAndData
    ) public onlyOwner returns (uint256 amountIn, uint256 amountOut) {
        (amountIn, amountOut,) = swapVM.swap(
            order,
            tokenIn,
            tokenOut,
            amount,
            takerTraitsAndData
        );
    }

    function preTransferInCallback(
        address maker,
        address /* taker */,
        address tokenIn,
        address /* tokenOut */,
        uint256 amountIn,
        uint256 /* amountOut */,
        bytes32 orderHash,
        bytes calldata /* takerData */
    ) external onlySwapVM {
        ERC20(tokenIn).approve(address(AQUA), amountIn);
        AQUA.push(maker, address(swapVM), orderHash, tokenIn, amountIn);
    }

    function preTransferOutCallback(
        address /* maker */,
        address /* taker */,
        address /* tokenIn */,
        address /* tokenOut */,
        uint256 /* amountIn */,
        uint256 /* amountOut */,
        bytes32 /* orderHash */,
        bytes calldata /* takerData */
    ) external onlySwapVM {
        // Custom exchange rate validation can be implemented here
    }
}

contract SwapVMTest is Test, OpcodesDebugCustom {
    using ProgramBuilder for Program;

    Aqua public immutable aqua = new Aqua();

    constructor() OpcodesDebugCustom(address(aqua)) {
        // Constructor body
    }

    CustomSwapVMRouter public swapVM;
    MockToken public tokenA;
    MockToken public tokenB;

    address public maker;
    uint256 public makerPrivateKey;
    MockTaker public taker;

    function setUp() public {
        // Setup maker with known private key for signing
        makerPrivateKey = 0x1234;
        maker = vm.addr(makerPrivateKey);

        // Deploy custom SwapVM router with pmAmm opcodes
        swapVM = new CustomSwapVMRouter(address(aqua), "SwapVM", "1.0.0");

        taker = new MockTaker(aqua, swapVM, address(this));

        // Deploy mock tokens
        tokenA = new MockToken("Token A", "TKA");
        tokenB = new MockToken("Token B", "TKB");

        // Setup initial balances
        tokenA.mint(maker, 1000e18);
        tokenB.mint(address(taker), 1000e18);

        // Approve SwapVM to spend tokens
        vm.prank(maker);
        tokenA.approve(address(swapVM), type(uint256).max);
    }

    function test_pmAmmSwap() public {
        Program memory p = ProgramBuilder.init(_opcodes());
        bytes memory programBytes = bytes.concat(
            p.build(pmAmm._pmAmmSwap)
        );

        ISwapVM.Order memory order = MakerTraitsLib.build(MakerTraitsLib.Args({
            maker: maker,
            shouldUnwrapWeth: false,
            useAquaInsteadOfSignature: true,
            allowZeroAmountIn: false,
            receiver: address(0),
            hasPreTransferInHook: false,
            hasPostTransferInHook: false,
            hasPreTransferOutHook: false,
            hasPostTransferOutHook: false,
            preTransferInTarget: address(0),
            preTransferInData: "",
            postTransferInTarget: address(0),
            postTransferInData: "",
            preTransferOutTarget: address(0),
            preTransferOutData: "",
            postTransferOutTarget: address(0),
            postTransferOutData: "",
            program: programBytes
        }));

        bytes32 orderHash = swapVM.hash(order);

        bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
           taker: address(taker),
            isExactIn: true,
            shouldUnwrapWeth: false,
            isStrictThresholdAmount: false,
            isFirstTransferFromTaker: false,
            useTransferFromAndAquaPush: false,
            threshold: abi.encodePacked(uint256(0e18)),
            to: address(0),
            hasPreTransferInCallback: true,
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

        vm.prank(maker);
        tokenA.approve(address(swapVM), type(uint256).max);
        tokenB.approve(address(swapVM), type(uint256).max);
        
        // Approve Aqua to pull tokens from maker (required for Aqua.pull())
        vm.prank(maker);
        tokenA.approve(address(aqua), type(uint256).max);
        vm.prank(maker);
        tokenB.approve(address(aqua), type(uint256).max);

        vm.prank(maker);
        bytes32 strategyHash = aqua.ship(
            address(swapVM),
            abi.encode(order),
            dynamic([address(tokenA), address(tokenB)]),
            dynamic([uint256(1_000e6), uint256(10_000e6)]) // 50/50 probabiltity 
        );
        assertEq(strategyHash, orderHash, "Strategy hash mismatch");

        vm.warp(block.timestamp + 7 days);

        (, uint256 amountOut) = taker.swap(
            order,
            address(tokenB),
            address(tokenA),
            5e6,
            takerData
        );

        // uint256 expectedAmountOut = (50e18 * 100e18) / (200e18 + 50e18);
        console.log("amountOut", amountOut / 1e3);

        uint256 effectivePrice = amountOut * 1e18/ 5e6;
        console.log("effectivePrice", effectivePrice);
        // assertEq(amountOut, expectedAmountOut, "Unexpected amountOut");
    }
}
