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
import {IPredictionMarket} from "../src/market/IPredictionMarket.sol";
import "../test/lib/ArbitrumLib.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

contract DeployMissing is Script, OpcodesDebugCustom {
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
    }

    function run() public {
        // Get private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address maker = vm.addr(deployerPrivateKey);

        // Get chain ID
        uint256 chainId = block.chainid;
        
        // Try to load existing deployment data
        string memory deploymentFile = string.concat("script/json/deployment-", vm.toString(chainId), ".json");
        bool hasExistingDeployment = false;
        
        try vm.readFile(deploymentFile) returns (string memory deploymentJson) {
            hasExistingDeployment = true;
            console.log("Found existing deployment file, loading addresses...");
            
            // Load existing addresses (will be zero if not found)
            aqua = vm.parseJsonAddress(deploymentJson, ".aqua");
            swapVM = vm.parseJsonAddress(deploymentJson, ".swapVM");
            makerMintingHook = vm.parseJsonAddress(deploymentJson, ".makerMintingHook");
            f1Market = vm.parseJsonAddress(deploymentJson, ".f1Market");
            bitcoinUnderMarket = vm.parseJsonAddress(deploymentJson, ".bitcoinUnderMarket");
            lakersWinMarket = vm.parseJsonAddress(deploymentJson, ".lakersWinMarket");
            
            // Load existing order hashes
            try vm.parseJsonBytes32(deploymentJson, ".f1OrderHash") returns (bytes32 hash) {
                f1OrderHash = hash;
            } catch {}
            try vm.parseJsonBytes32(deploymentJson, ".bitcoinUnderOrderHash") returns (bytes32 hash) {
                bitcoinUnderOrderHash = hash;
            } catch {}
            try vm.parseJsonBytes32(deploymentJson, ".lakersWinOrderHash") returns (bytes32 hash) {
                lakersWinOrderHash = hash;
            } catch {}
        } catch {
            console.log("No existing deployment file found, will deploy everything");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Configuration
        address usdc = ArbitrumLib.USDC;
        address yieldVault = ArbitrumLib.EVC_USDC_VAULT;

        // Deploy Aqua if not already deployed
        if (aqua == address(0)) {
            console.log("Deploying Aqua...");
            Aqua aquaInstance = new Aqua();
            aqua = address(aquaInstance);
            console.log("Aqua deployed at:", aqua);
        } else {
            console.log("Aqua already deployed at:", aqua);
        }

        // Deploy SwapVM if not already deployed
        if (swapVM == address(0)) {
            console.log("Deploying SwapVM...");
            swapVM = deploySwapVM(aqua);
            console.log("SwapVM deployed at:", swapVM);
        } else {
            console.log("SwapVM already deployed at:", swapVM);
        }

        // Deploy MakerMintingHook if not already deployed
        if (makerMintingHook == address(0)) {
            console.log("Deploying MakerMintingHook...");
            makerMintingHook = deployMakerMintingHook(ArbitrumLib.EVC, swapVM);
            console.log("MakerMintingHook deployed at:", makerMintingHook);
        } else {
            console.log("MakerMintingHook already deployed at:", makerMintingHook);
        }

        // Deploy prediction markets if not already deployed
        if (f1Market == address(0)) {
            console.log("Deploying F1 Market...");
            f1Market = deployPredictionMarket("Verstappin Wins Las Vegas GP", usdc);
            console.log("F1 Market deployed at:", f1Market);
        } else {
            console.log("F1 Market already deployed at:", f1Market);
        }

        if (bitcoinUnderMarket == address(0)) {
            console.log("Deploying Bitcoin Under Market...");
            bitcoinUnderMarket = deployPredictionMarket("Bitcoin Under 80k by 11/29", usdc);
            console.log("Bitcoin Under Market deployed at:", bitcoinUnderMarket);
        } else {
            console.log("Bitcoin Under Market already deployed at:", bitcoinUnderMarket);
        }

        if (lakersWinMarket == address(0)) {
            console.log("Deploying Lakers Win Market...");
            lakersWinMarket = deployPredictionMarket("Lakers Win NBA Championship", usdc);
            console.log("Lakers Win Market deployed at:", lakersWinMarket);
        } else {
            console.log("Lakers Win Market already deployed at:", lakersWinMarket);
        }

        // Create and ship orders only for markets that exist and don't have orders yet
        if (f1Market != address(0) && f1OrderHash == bytes32(0)) {
            console.log("Creating and shipping F1 order...");
            ISwapVM.Order memory f1MakerOrder = getMakerOrder(
                maker,
                f1Market,
                makerMintingHook,
                yieldVault,
                block.timestamp + 1 days
            );
            f1OrderHash = shipMakerOrder(
                aqua,
                swapVM,
                f1MakerOrder,
                IPredictionMarket(f1Market).no(),
                IPredictionMarket(f1Market).yes(),
                10_000e6,
                10_000e6
            );
            console.log("F1 Order Hash:");
            console.logBytes32(f1OrderHash);
        } else if (f1OrderHash != bytes32(0)) {
            console.log("F1 order already shipped:");
            console.logBytes32(f1OrderHash);
        }

        if (bitcoinUnderMarket != address(0) && bitcoinUnderOrderHash == bytes32(0)) {
            console.log("Creating and shipping Bitcoin Under order...");
            ISwapVM.Order memory bitcoinUnderOrder = getMakerOrder(
                maker,
                bitcoinUnderMarket,
                makerMintingHook,
                yieldVault,
                block.timestamp + 7 days
            );
            bitcoinUnderOrderHash = shipMakerOrder(
                aqua,
                swapVM,
                bitcoinUnderOrder,
                IPredictionMarket(bitcoinUnderMarket).no(),
                IPredictionMarket(bitcoinUnderMarket).yes(),
                10_000e6,
                10_000e6
            );
            console.log("Bitcoin Under Order Hash:");
            console.logBytes32(bitcoinUnderOrderHash);
        } else if (bitcoinUnderOrderHash != bytes32(0)) {
            console.log("Bitcoin Under order already shipped:");
            console.logBytes32(bitcoinUnderOrderHash);
        }

        if (lakersWinMarket != address(0) && lakersWinOrderHash == bytes32(0)) {
            console.log("Creating and shipping Lakers Win order...");
            ISwapVM.Order memory lakersWinOrder = getMakerOrder(
                maker,
                lakersWinMarket,
                makerMintingHook,
                yieldVault,
                block.timestamp + 32 weeks
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
            console.log("Lakers Win Order Hash:");
            console.logBytes32(lakersWinOrderHash);
        } else if (lakersWinOrderHash != bytes32(0)) {
            console.log("Lakers Win order already shipped:");
            console.logBytes32(lakersWinOrderHash);
        }

        vm.stopBroadcast();

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Aqua:", aqua);
        console.log("SwapVM:", swapVM);
        console.log("MakerMintingHook:", makerMintingHook);
        console.log("F1 Market:", f1Market);
        console.log("Bitcoin Under Market:", bitcoinUnderMarket);
        console.log("Lakers Win Market:", lakersWinMarket);
        if (f1OrderHash != bytes32(0)) {
            console.log("F1 Order Hash:");
            console.logBytes32(f1OrderHash);
        }
        if (bitcoinUnderOrderHash != bytes32(0)) {
            console.log("Bitcoin Under Order Hash:");
            console.logBytes32(bitcoinUnderOrderHash);
        }
        if (lakersWinOrderHash != bytes32(0)) {
            console.log("Lakers Win Order Hash:");
            console.logBytes32(lakersWinOrderHash);
        }

        // Write deployment data to JSON file
        writeDeploymentJson();
    }

    function writeDeploymentJson() internal {
        string memory json = "deployment";
        
        // Serialize contract addresses (only if non-zero)
        if (aqua != address(0)) {
            json = vm.serializeAddress(json, "aqua", aqua);
        }
        if (swapVM != address(0)) {
            json = vm.serializeAddress(json, "swapVM", swapVM);
        }
        if (makerMintingHook != address(0)) {
            json = vm.serializeAddress(json, "makerMintingHook", makerMintingHook);
        }
        if (f1Market != address(0)) {
            json = vm.serializeAddress(json, "f1Market", f1Market);
        }
        if (bitcoinUnderMarket != address(0)) {
            json = vm.serializeAddress(json, "bitcoinUnderMarket", bitcoinUnderMarket);
        }
        if (lakersWinMarket != address(0)) {
            json = vm.serializeAddress(json, "lakersWinMarket", lakersWinMarket);
        }
        
        // Serialize order hashes (only if non-zero)
        if (f1OrderHash != bytes32(0)) {
            json = vm.serializeBytes32(json, "f1OrderHash", f1OrderHash);
        }
        if (bitcoinUnderOrderHash != bytes32(0)) {
            json = vm.serializeBytes32(json, "bitcoinUnderOrderHash", bitcoinUnderOrderHash);
        }
        if (lakersWinOrderHash != bytes32(0)) {
            json = vm.serializeBytes32(json, "lakersWinOrderHash", lakersWinOrderHash);
        }
        
        // Add chain ID, block number, and timestamp
        json = vm.serializeUint(json, "chainId", block.chainid);
        json = vm.serializeUint(json, "blockNumber", block.number);
        json = vm.serializeUint(json, "timestamp", block.timestamp);
        json = vm.serializeAddress(json, "deployer", msg.sender);
        
        // Create timestamped directory name to avoid overwriting previous deployments
        string memory timestamp = vm.toString(block.timestamp);
        string memory chainIdStr = vm.toString(block.chainid);
        
        // Ensure base directory exists
        vm.createDir("script/json", true);
        
        // Create timestamped directory (recursive = true to create parent dirs if needed)
        string memory timestampedDirPath = string.concat(
            "script/json/",
            chainIdStr,
            "-",
            timestamp
        );
        vm.createDir(timestampedDirPath, true);
        
        // Write to timestamped directory in script/json
        string memory timestampedDir = string.concat(
            timestampedDirPath,
            "/deployment.json"
        );
        vm.writeJson(json, timestampedDir);
        
        // Also write to the standard location for easy access (latest deployment)
        string memory standardFilename = string.concat(
            "script/json/deployment-",
            chainIdStr,
            ".json"
        );
        vm.writeJson(json, standardFilename);
        
        console.log("Deployment data written to:", timestampedDir);
        console.log("Latest deployment also written to:", standardFilename);
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

