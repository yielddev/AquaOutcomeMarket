// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;
import { PredictionMarket } from "../src/market/PredictionMarket.sol";
import { Aqua } from "@1inch/aqua/src/Aqua.sol";
import { CustomSwapVMRouter } from "../src/routers/CustomSwapVMRouter.sol";
import { MakerMintingHook } from "../src/hooks/MakerMintingHook.sol";
import { IEthereumVaultConnector } from "euler-interfaces/IEthereumVaultConnector.sol";
import { ISwapVM } from "swap-vm/interfaces/ISwapVM.sol";
import { Program, ProgramBuilder} from "@1inch/swap-vm/test/utils/ProgramBuilder.sol";
import { Fee, FeeArgsBuilder } from "swap-vm/instructions/Fee.sol";
import { MakerTraitsLib } from "swap-vm/libs/MakerTraits.sol";
import { dynamic } from "@1inch/swap-vm/test/utils/Dynamic.sol";
import { pmAmm } from "../src/instructions/pmAmm.sol";
import "./ArbitrumBaseTest.t.sol";
import { OpcodesDebugCustom } from "../src/opcodes/OpcodesDebugCustom.sol";

contract FullSim is ArbitrumBaseTest, OpcodesDebugCustom {
    using ProgramBuilder for Program;

    constructor() OpcodesDebugCustom(address(new Aqua())) {
        // Constructor body
    }
    
    function setUp() public override {
        super.setUp();
        address usdc = ArbitrumLib.USDC;
        address yieldVault = ArbitrumLib.EVC_USDC_VAULT;
        address maker = ArbitrumLib.USER;

        // Deploy 3 prediction markets
        address f1Market = deployPredictionMarket("Verstappin Wins Las Vegas GP", address(usdc));
        address bitcoinUnder = deployPredictionMarket("Bitcoin Under 80k by 11/29", address(usdc));
        address lakersWin = deployPredictionMarket("Lakers Win NBA Championship", address(usdc));

        // deploy swapVM
        address swapVM = deploySwapVM();

        // create 3 maker order with euler aware hook
        address makerMintingHook = deployMakerMintingHook(ArbitrumLib.EVC, swapVM);


        ISwapVM.Order memory f1MakerOrder = getMakerOrder(maker, f1Market, makerMintingHook, yieldVault, block.timestamp + 1 days);
        ISwapVM.Order memory bitcoinUnderOrder = getMakerOrder(maker, bitcoinUnder, makerMintingHook, yieldVault, block.timestamp + 7 days);
        ISwapVM.Order memory lakersWinOrder = getMakerOrder(maker, lakersWin, makerMintingHook, yieldVault, block.timestamp + 32 weeks);

        // ship 3 orders 

        bytes32 f1Hash = shipMakerOrder(swapVM, f1MakerOrder, address(usdc), address(usdc), 10_000e6, 10_000e6);
        bytes32 bitcoinUnderHash = shipMakerOrder(swapVM, bitcoinUnderOrder, address(usdc), address(usdc), 10_000e6, 10_000e6);
        bytes32 lakersWinHash = shipMakerOrder(swapVM, lakersWinOrder, address(usdc), address(usdc), 10_000e6, 10_000e6);

    }

    function deployPredictionMarket(string memory name, address usdc) public returns (address) {
        PredictionMarket predictionMarket = new PredictionMarket(address(usdc), address(usdc), name);
        return address(predictionMarket);
    }

    function deploySwapVM() public returns (address) {
        Aqua aqua = new Aqua();
        CustomSwapVMRouter swapVM = new CustomSwapVMRouter(address(aqua), "Aqua Outcome Market", "0.0.1");
        return address(swapVM);
    }

    function deployMakerMintingHook(address evc, address swapVM) public returns (address) {
        MakerMintingHook makerMintingHook = new MakerMintingHook(IEthereumVaultConnector(payable(evc)), swapVM);
    }

    function getMakerOrder(address maker, address predictionMarket, address makerMintingHook, address yieldVault, uint256 horizon)
        public 
        returns 
        (ISwapVM.Order memory) 
    {
            Program memory p = ProgramBuilder.init(_opcodes());
            bytes memory programBytes = bytes.concat(
                p.build(Fee._flatFeeAmountInXD, FeeArgsBuilder.buildFlatFee(uint32(3e6))),
                p.build(pmAmm._pmAmmSwap, abi.encode(horizon))
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
                preTransferOutData: abi.encode(address(predictionMarket), address(yieldVault), true, true),
                postTransferOutTarget: address(0),
                postTransferOutData: "",
                program: programBytes
            }));
        return order;
    }

    function shipMakerOrder(
        address swapVM,
        ISwapVM.Order memory order,
        address tokenA,
        address tokenB,
        uint256 balanceA,
        uint256 balanceB
    ) public returns (bytes32) {
        bytes32 orderHash = ISwapVM(swapVM).hash(order);

        bytes32 strategyHash = Aqua(swapVM).ship(
            address(swapVM),
            abi.encode(order),
            dynamic([address(tokenA), address(tokenB)]),
            dynamic([balanceA, balanceB])
        );
        return strategyHash;
    }

}