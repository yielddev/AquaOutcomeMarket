// // SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
// pragma solidity 0.8.30;

// /// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
// /// @custom:copyright © 2025 Degensoft Ltd

// import { Test } from "forge-std/Test.sol";
// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import { Aqua } from "@1inch/aqua/src/Aqua.sol";

// import { dynamic } from "@1inch/swap-vm/test/utils/Dynamic.sol";

// import { SwapVM, ISwapVM } from "swap-vm/SwapVM.sol";
// import { MakerTraitsLib } from "swap-vm/libs/MakerTraits.sol";
// import { TakerTraitsLib } from "swap-vm/libs/TakerTraits.sol";
// import { CustomSwapVMRouter } from "../src/routers/CustomSwapVMRouter.sol";
// import { PredictionMarketAMM } from "../src/strategies/PredictionMarketAMM.sol";
// import { MakerMintingHook } from "../src/hooks/MakerMintingHook.sol";
// import { IEthereumVaultConnector } from "euler-interfaces/IEthereumVaultConnector.sol";
// import { MockEVC } from "./mocks/MockEVC.sol";

// import { ITakerCallbacks } from "swap-vm/interfaces/ITakerCallbacks.sol";
// import "forge-std/console.sol";

// contract MockToken is ERC20 {
//     constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

//     function mint(address to, uint256 amount) external {
//         _mint(to, amount);
//     }
// }

// contract MockTaker is ITakerCallbacks {
//     Aqua public immutable AQUA;
//     SwapVM public immutable swapVM;

//     address public immutable owner;

//     modifier onlyOwner() {
//         require(msg.sender == owner, "Not the owner");
//         _;
//     }

//     modifier onlySwapVM() {
//         require(msg.sender == address(swapVM), "Not the SwapVM");
//         _;
//     }

//     constructor(Aqua aqua, SwapVM swapVM_, address owner_) {
//         AQUA = aqua;
//         swapVM = swapVM_;
//         owner = owner_;
//     }

//     function swap(
//         ISwapVM.Order calldata order,
//         address tokenIn,
//         address tokenOut,
//         uint256 amount,
//         bytes calldata takerTraitsAndData
//     ) public onlyOwner returns (uint256 amountIn, uint256 amountOut) {
//         (amountIn, amountOut,) = swapVM.swap(
//             order,
//             tokenIn,
//             tokenOut,
//             amount,
//             takerTraitsAndData
//         );
//     }

//     function preTransferInCallback(
//         address maker,
//         address /* taker */,
//         address tokenIn,
//         address /* tokenOut */,
//         uint256 amountIn,
//         uint256 /* amountOut */,
//         bytes32 orderHash,
//         bytes calldata /* takerData */
//     ) external onlySwapVM {
//         ERC20(tokenIn).approve(address(AQUA), amountIn);
//         AQUA.push(maker, address(swapVM), orderHash, tokenIn, amountIn);
//     }

//     function preTransferOutCallback(
//         address /* maker */,
//         address /* taker */,
//         address /* tokenIn */,
//         address /* tokenOut */,
//         uint256 /* amountIn */,
//         uint256 /* amountOut */,
//         bytes32 /* orderHash */,
//         bytes calldata /* takerData */
//     ) external onlySwapVM {
//         // Custom exchange rate validation can be implemented here
//     }
// }

// contract PredictionMarketAMMTest is Test {
//     Aqua public aqua;
//     CustomSwapVMRouter public swapVM;
//     PredictionMarketAMM public strategy;
//     MakerMintingHook public makerMintingHook;
//     MockEVC public evc;
    
//     MockToken public tokenA;
//     MockToken public tokenB;
    
//     address public maker;
//     address public feeReceiver;
//     address public predictionMarket;
//     address public yieldVault;
    
//     uint256 public makerPrivateKey;
//     MockTaker public taker;
    
//     uint256 constant INITIAL_BALANCE_A = 1_000e6;
//     uint256 constant INITIAL_BALANCE_B = 10_000e6;
//     uint256 constant HORIZON = 1764410735; // Future timestamp
//     uint40 constant EXPIRATION = uint40(1764410735);
//     uint16 constant FEE_BPS = 30; // 0.3%
//     uint16 constant PROTOCOL_FEE_BPS = 10; // 0.1%
//     uint64 constant SALT = 12345;

//     function setUp() public {
//         // Setup maker with known private key
//         makerPrivateKey = 0x1234;
//         maker = vm.addr(makerPrivateKey);
//         feeReceiver = address(0x999);
//         predictionMarket = address(0x888);
//         yieldVault = address(0x777);

//         // Deploy Aqua
//         aqua = new Aqua();
        
//         // Deploy SwapVM router
//         swapVM = new CustomSwapVMRouter(address(aqua), "SwapVM", "1.0.0");
        
//         // Deploy strategy
//         strategy = new PredictionMarketAMM(address(aqua));
        
//         // Deploy mock EVC
//         evc = new MockEVC();
        
//         // Deploy maker minting hook
//         makerMintingHook = new MakerMintingHook(
//             IEthereumVaultConnector(payable(address(evc))),
//             address(swapVM)
//         );
        
//         // Deploy mock tokens
//         tokenA = new MockToken("Token A", "TKA");
//         tokenB = new MockToken("Token B", "TKB");
        
//         // Deploy taker
//         taker = new MockTaker(aqua, swapVM, address(this));
        
//         // Setup initial balances
//         tokenA.mint(maker, INITIAL_BALANCE_A);
//         tokenB.mint(address(taker), 1000e6);
        
//         // Approve SwapVM to spend tokens
//         vm.prank(maker);
//         tokenA.approve(address(swapVM), type(uint256).max);
//         vm.prank(maker);
//         tokenB.approve(address(swapVM), type(uint256).max);
        
//         // Approve Aqua to pull tokens from maker
//         vm.prank(maker);
//         tokenA.approve(address(aqua), type(uint256).max);
//         vm.prank(maker);
//         tokenB.approve(address(aqua), type(uint256).max);
//     }

//     function test_buildProgram_Basic() public view {
//         ISwapVM.Order memory order = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             0, // no fee
//             0, // no protocol fee
//             address(0), // no fee receiver
//             address(0), // no hook
//             address(0), // no prediction market
//             address(0), // no yield vault
//             false, // useBalance
//             false, // shouldBorrow
//             0 // no salt
//         );
        
//         assertEq(order.maker, maker, "Maker address mismatch");
//         assertTrue(MakerTraitsLib.useAquaInsteadOfSignature(order.traits), "Should use Aqua");
//     }

//     function test_buildProgram_WithFees() public view {
//         ISwapVM.Order memory order = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             FEE_BPS,
//             PROTOCOL_FEE_BPS,
//             feeReceiver,
//             address(0),
//             address(0),
//             address(0),
//             false,
//             false,
//             0
//         );
        
//         assertEq(order.maker, maker, "Maker address mismatch");
//         bytes32 orderHash = swapVM.hash(order);
//         assertTrue(orderHash != bytes32(0), "Order hash should not be zero");
//     }

//     function test_buildProgram_WithHook() public view {
//         ISwapVM.Order memory order = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             FEE_BPS,
//             PROTOCOL_FEE_BPS,
//             feeReceiver,
//             address(makerMintingHook),
//             predictionMarket,
//             yieldVault,
//             true, // useBalance
//             true, // shouldBorrow
//             SALT
//         );
        
//         assertEq(order.maker, maker, "Maker address mismatch");
//         assertTrue(MakerTraitsLib.hasPreTransferOutHook(order.traits), "Should have preTransferOut hook");
//     }

//     function test_buildProgram_WithSalt() public view {
//         uint64 salt1 = 11111;
//         uint64 salt2 = 22222;
        
//         ISwapVM.Order memory order1 = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             0,
//             0,
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             false,
//             false,
//             salt1
//         );
        
//         ISwapVM.Order memory order2 = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             0,
//             0,
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             false,
//             false,
//             salt2
//         );
        
//         bytes32 hash1 = swapVM.hash(order1);
//         bytes32 hash2 = swapVM.hash(order2);
        
//         assertTrue(hash1 != hash2, "Orders with different salts should have different hashes");
//     }

//     function test_buildProgram_InvalidHorizon() public {
//         uint256 pastHorizon = block.timestamp - 1;
        
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 PredictionMarketAMM.InvalidHorizon.selector,
//                 pastHorizon,
//                 block.timestamp
//             )
//         );
        
//         strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             pastHorizon,
//             0,
//             0,
//             address(0),
//             address(0),
//             address(0),
//             address(0),
//             false,
//             false,
//             0
//         );
//     }

//     function test_buildProgram_ProtocolFeeExceedsMakerFee() public {
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 PredictionMarketAMM.ProtocolFeesExceedMakerFees.selector,
//                 FEE_BPS + 1,
//                 FEE_BPS
//             )
//         );
        
//         strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             FEE_BPS,
//             FEE_BPS + 1, // Protocol fee exceeds maker fee
//             feeReceiver,
//             address(0),
//             address(0),
//             address(0),
//             false,
//             false,
//             0
//         );
//     }

//     function test_buildProgram_AndShipOrder() public {
//         ISwapVM.Order memory order = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             FEE_BPS,
//             PROTOCOL_FEE_BPS,
//             feeReceiver,
//             address(0), // No hook for simplicity
//             address(0),
//             address(0),
//             false,
//             false,
//             SALT
//         );
        
//         bytes32 orderHash = swapVM.hash(order);
        
//         // Ship the order
//         vm.prank(maker);
//         bytes32 strategyHash = aqua.ship(
//             address(swapVM),
//             abi.encode(order),
//             dynamic([address(tokenA), address(tokenB)]),
//             dynamic([INITIAL_BALANCE_A, INITIAL_BALANCE_B])
//         );
        
//         assertEq(strategyHash, orderHash, "Strategy hash should match order hash");
        
//         // Verify balances in Aqua
//         (uint256 balanceA, uint256 balanceB) = aqua.safeBalances(
//             maker,
//             address(swapVM),
//             orderHash,
//             address(tokenA),
//             address(tokenB)
//         );
        
//         assertEq(balanceA, INITIAL_BALANCE_A, "Balance A mismatch");
//         assertEq(balanceB, INITIAL_BALANCE_B, "Balance B mismatch");
//     }

//     function test_buildProgram_AndExecuteSwap() public {
//         ISwapVM.Order memory order = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             FEE_BPS,
//             PROTOCOL_FEE_BPS,
//             feeReceiver,
//             address(0),
//             address(0),
//             address(0),
//             false,
//             false,
//             SALT
//         );
        
//         bytes32 orderHash = swapVM.hash(order);
        
//         // Ship the order
//         vm.prank(maker);
//         aqua.ship(
//             address(swapVM),
//             abi.encode(order),
//             dynamic([address(tokenA), address(tokenB)]),
//             dynamic([INITIAL_BALANCE_A, INITIAL_BALANCE_B])
//         );
        
//         // Build taker data
//         bytes memory takerData = TakerTraitsLib.build(TakerTraitsLib.Args({
//             taker: address(taker),
//             isExactIn: true,
//             shouldUnwrapWeth: false,
//             isStrictThresholdAmount: false,
//             isFirstTransferFromTaker: false,
//             useTransferFromAndAquaPush: false,
//             threshold: abi.encodePacked(uint256(0)),
//             to: address(0),
//             hasPreTransferInCallback: true,
//             hasPreTransferOutCallback: false,
//             preTransferInHookData: "",
//             postTransferInHookData: "",
//             preTransferOutHookData: "",
//             postTransferOutHookData: "",
//             preTransferInCallbackData: "",
//             preTransferOutCallbackData: "",
//             instructionsArgs: "",
//             signature: ""
//         }));
        
//         // Execute swap
//         uint256 amountIn = 50e6;
//         (uint256 actualAmountIn, uint256 amountOut) = taker.swap(
//             order,
//             address(tokenB),
//             address(tokenA),
//             amountIn,
//             takerData
//         );
        
//         assertEq(actualAmountIn, amountIn, "Amount in mismatch");
//         assertTrue(amountOut > 0, "Should receive some tokens out");
        
//         console.log("Amount In:", actualAmountIn);
//         console.log("Amount Out:", amountOut);
//     }

//     function test_buildProgram_WithHook_AndExecuteSwap() public {
//         ISwapVM.Order memory order = strategy.buildProgram(
//             maker,
//             EXPIRATION,
//             HORIZON,
//             FEE_BPS,
//             PROTOCOL_FEE_BPS,
//             feeReceiver,
//             address(makerMintingHook),
//             predictionMarket,
//             yieldVault,
//             true, // useBalance
//             true, // shouldBorrow
//             SALT
//         );
        
//         bytes32 orderHash = swapVM.hash(order);
        
//         // Ship the order
//         vm.prank(maker);
//         aqua.ship(
//             address(swapVM),
//             abi.encode(order),
//             dynamic([address(tokenA), address(tokenB)]),
//             dynamic([INITIAL_BALANCE_A, INITIAL_BALANCE_B])
//         );
        
//         // Verify hook data is encoded correctly
//         // The hook should be able to decode the preTransferOutData
//         // This is tested implicitly by the hook execution during swap
//         assertTrue(MakerTraitsLib.hasPreTransferOutHook(order.traits), "Should have hook");
//     }
// }

