// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {PredictionMarket} from "../src/market/PredictionMarket.sol";
import {Aqua} from "@1inch/aqua/src/Aqua.sol";
import {CustomSwapVMRouter} from "../src/routers/CustomSwapVMRouter.sol";
import {MakerMintingHook} from "../src/hooks/MakerMintingHook.sol";
import {IEthereumVaultConnector} from "euler-interfaces/IEthereumVaultConnector.sol";
import {ISwapVM} from "swap-vm/interfaces/ISwapVM.sol";
import {Program, ProgramBuilder} from "@1inch/swap-vm/test/utils/ProgramBuilder.sol";
import {Fee, FeeArgsBuilder} from "swap-vm/instructions/Fee.sol";
import {MakerTraitsLib} from "swap-vm/libs/MakerTraits.sol";
import {dynamic} from "@1inch/swap-vm/test/utils/Dynamic.sol";
import {pmAmm} from "../src/instructions/pmAmm.sol";
import {OpcodesDebugCustom} from "../src/opcodes/OpcodesDebugCustom.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVault} from "euler-interfaces/IEVault.sol";
import { IPredictionMarket } from "../src/market/IPredictionMarket.sol";
import "../test/lib/ArbitrumLib.sol";
import "forge-std/console.sol";

contract DeployFullSystem is Script, OpcodesDebugCustom {
    using ProgramBuilder for Program;

    // Deployment addresses - will be populated during deployment
    address public aqua;
    address public swapVM;
    address public makerMintingHook;
    address public f1Market;
    address public bitcoinUnderMarket;
    address public lakersWinMarket;
    bytes32 public f1OrderHash;
    bytes32 public bitcoinUnderOrderHash;
    bytes32 public lakersWinOrderHash;

    constructor() OpcodesDebugCustom(address(new Aqua())) {
        // Constructor creates Aqua for OpcodesDebugCustom initialization
        // The actual deployment Aqua will be created in run()
    }

    function run() public {
        // Get private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address maker = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Configuration - update these addresses as needed
        address usdc = ArbitrumLib.USDC;
        address yieldVault = ArbitrumLib.EVC_USDC_VAULT;

        // Deploy Aqua (this is the actual deployment instance)
        Aqua aquaInstance = new Aqua();
        aqua = address(aquaInstance);

        // Deploy SwapVM
        swapVM = deploySwapVM(aqua);

        // Deploy MakerMintingHook
        makerMintingHook = deployMakerMintingHook(ArbitrumLib.EVC, swapVM);

        // Deploy 3 prediction markets
        f1Market = deployPredictionMarket("Verstappin Wins Las Vegas GP", usdc);
        bitcoinUnderMarket = deployPredictionMarket("Bitcoin Under 80k by 11/29", usdc);
        lakersWinMarket = deployPredictionMarket("Lakers Win NBA Championship", usdc);

        // Create 3 maker orders with euler aware hook
        ISwapVM.Order memory f1MakerOrder = getMakerOrder(
            maker,
            f1Market,
            makerMintingHook,
            yieldVault,
            block.timestamp + 1 days
        );
        ISwapVM.Order memory bitcoinUnderOrder = getMakerOrder(
            maker,
            bitcoinUnderMarket,
            makerMintingHook,
            yieldVault,
            block.timestamp + 7 days
        );
        ISwapVM.Order memory lakersWinOrder = getMakerOrder(
            maker,
            lakersWinMarket,
            makerMintingHook,
            yieldVault,
            block.timestamp + 32 weeks
        );

        // Ship 3 orders
        f1OrderHash = shipMakerOrder(aqua, swapVM, f1MakerOrder, IPredictionMarket(f1Market).no(), IPredictionMarket(f1Market).yes(), 10_000e6, 10_000e6);
        bitcoinUnderOrderHash = shipMakerOrder(
            aqua,
            swapVM,
            bitcoinUnderOrder,
            IPredictionMarket(bitcoinUnderMarket).no(),
            IPredictionMarket(bitcoinUnderMarket).yes(),
            10_000e6,
            10_000e6
        );
        lakersWinOrderHash = shipMakerOrder(
            aqua,
            swapVM,
            lakersWinOrder,
            IPredictionMarket(lakersWinMarket).no(),
            IPredictionMarket(lakersWinMarket).yes(),
            10_000e6,
            10_000e6
        );

        // Note: In production, ensure the maker address has sufficient USDC balance
        // and has approved the yield vault. The following is for testing purposes.
        // Uncomment and modify as needed for your deployment:
        /*
        vm.startPrank(maker);
        IERC20(usdc).approve(yieldVault, 10_000e6);
        IEVault(yieldVault).deposit(10000e6, maker);
        vm.stopPrank();
        */

        vm.stopBroadcast();

        // Log deployment addresses
        console.log("=== Deployment Summary ===");
        console.log("Aqua:", aqua);
        console.log("SwapVM:", swapVM);
        console.log("MakerMintingHook:", makerMintingHook);
        console.log("F1 Market:", f1Market);
        console.log("Bitcoin Under Market:", bitcoinUnderMarket);
        console.log("Lakers Win Market:", lakersWinMarket);
        console.log("F1 Order Hash:");
        console.logBytes32(f1OrderHash);
        console.log("Bitcoin Under Order Hash:");
        console.logBytes32(bitcoinUnderOrderHash);
        console.log("Lakers Win Order Hash:");
        console.logBytes32(lakersWinOrderHash);
    }

    function deployPredictionMarket(string memory name, address usdc) public returns (address) {
        PredictionMarket predictionMarket = new PredictionMarket(usdc, usdc, name);
        return address(predictionMarket);
    }

    function deploySwapVM(address aquaAddress) public returns (address) {
        CustomSwapVMRouter swapVMInstance = new CustomSwapVMRouter(
            aquaAddress,
            "Aqua Outcome Market",
            "0.0.1"
        );
        return address(swapVMInstance);
    }

    function deployMakerMintingHook(address evc, address swapVMAddress)
        public
        returns (address)
    {
        MakerMintingHook makerMintingHookInstance = new MakerMintingHook(
            IEthereumVaultConnector(payable(evc)),
            swapVMAddress
        );
        return address(makerMintingHookInstance);
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

    function shipMakerOrder(
        address aquaAddress,
        address swapVMAddress,
        ISwapVM.Order memory order,
        address tokenA,
        address tokenB,
        uint256 balanceA,
        uint256 balanceB
    ) public returns (bytes32) {
        bytes32 orderHash = ISwapVM(swapVMAddress).hash(order);

        // Ship must be called by the maker (msg.sender in Aqua.ship is the maker)
        // Since we're broadcasting with the maker's private key, msg.sender will be the maker
        bytes32 strategyHash = Aqua(aquaAddress).ship(
            swapVMAddress,
            abi.encode(order),
            dynamic([tokenA, tokenB]),
            dynamic([balanceA, balanceB])
        );
        return strategyHash;
    }
}

