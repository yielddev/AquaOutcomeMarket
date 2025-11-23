// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {PredictionMarket} from "../src/market/PredictionMarket.sol";
import {Aqua} from "@1inch/aqua/src/Aqua.sol";
import {CustomSwapVMRouter} from "../src/routers/CustomSwapVMRouter.sol";
import {MakerMintingHook} from "../src/hooks/MakerMintingHook.sol";
import {PredictionMarketAMM} from "../src/strategies/PredictionMarketAMM.sol";
import {IEthereumVaultConnector} from "euler-interfaces/IEthereumVaultConnector.sol";
import {ISwapVM} from "swap-vm/interfaces/ISwapVM.sol";
import {dynamic} from "@1inch/swap-vm/test/utils/Dynamic.sol";
import {OpcodesDebugCustom} from "../src/opcodes/OpcodesDebugCustom.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEVault} from "euler-interfaces/IEVault.sol";
import { IPredictionMarket } from "../src/market/IPredictionMarket.sol";
import "../test/lib/ArbitrumLib.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";

contract DeployFullSystem is Script, OpcodesDebugCustom {
    // Deployment addresses - will be populated during deployment
    address public aqua;
    address public swapVM;
    address public strategy;
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

        // Deploy PredictionMarketAMM strategy
        strategy = deployStrategy(aqua);

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
            70_000e6,
            30_000e6
        );
        lakersWinOrderHash = shipMakerOrder(
            aqua,
            swapVM,
            lakersWinOrder,
            IPredictionMarket(lakersWinMarket).no(),
            IPredictionMarket(lakersWinMarket).yes(),
            75_000e6,
            25_000e6
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

        // Encode orders as bytes for storage
        bytes memory f1OrderBytes = abi.encode(f1MakerOrder);
        bytes memory bitcoinUnderOrderBytes = abi.encode(bitcoinUnderOrder);
        bytes memory lakersWinOrderBytes = abi.encode(lakersWinOrder);

        // Log to console
        _logDeployment(maker, aqua, swapVM, strategy, makerMintingHook, f1Market, bitcoinUnderMarket, lakersWinMarket, f1OrderHash, bitcoinUnderOrderHash, lakersWinOrderHash, f1OrderBytes, bitcoinUnderOrderBytes, lakersWinOrderBytes);

        // Write to files
        uint256 chainId = block.chainid;
        _writeDeploymentFiles(chainId, maker, aqua, swapVM, strategy, makerMintingHook, f1Market, bitcoinUnderMarket, lakersWinMarket, f1OrderHash, bitcoinUnderOrderHash, lakersWinOrderHash, f1OrderBytes, bitcoinUnderOrderBytes, lakersWinOrderBytes);
    }

    function _logDeployment(
        address deployer,
        address aquaAddr,
        address swapVMAddr,
        address strategyAddr,
        address hookAddr,
        address f1MarketAddr,
        address bitcoinMarketAddr,
        address lakersMarketAddr,
        bytes32 f1Hash,
        bytes32 bitcoinHash,
        bytes32 lakersHash,
        bytes memory f1OrderBytes,
        bytes memory bitcoinOrderBytes,
        bytes memory lakersOrderBytes
    ) internal {
        console.log("=== Deployment Summary ===");
        console.log("Deployer:", deployer);
        console.log("Aqua:", aquaAddr);
        console.log("SwapVM:", swapVMAddr);
        console.log("Strategy (PredictionMarketAMM):", strategyAddr);
        console.log("MakerMintingHook:", hookAddr);
        console.log("F1 Market:", f1MarketAddr);
        console.log("Bitcoin Under Market:", bitcoinMarketAddr);
        console.log("Lakers Win Market:", lakersMarketAddr);
        console.log("F1 Order Hash:");
        console.logBytes32(f1Hash);
        console.log("Bitcoin Under Order Hash:");
        console.logBytes32(bitcoinHash);
        console.log("Lakers Win Order Hash:");
        console.logBytes32(lakersHash);
        console.log("F1 Order Bytes Length:", f1OrderBytes.length);
        console.log("Bitcoin Under Order Bytes Length:", bitcoinOrderBytes.length);
        console.log("Lakers Win Order Bytes Length:", lakersOrderBytes.length);
    }

    function _writeDeploymentFiles(
        uint256 chainId,
        address deployer,
        address aquaAddr,
        address swapVMAddr,
        address strategyAddr,
        address hookAddr,
        address f1MarketAddr,
        address bitcoinMarketAddr,
        address lakersMarketAddr,
        bytes32 f1Hash,
        bytes32 bitcoinHash,
        bytes32 lakersHash,
        bytes memory f1OrderBytes,
        bytes memory bitcoinOrderBytes,
        bytes memory lakersOrderBytes
    ) internal {
        // Write markdown file
        string memory mdPath = string.concat("script/json/deployment-", vm.toString(chainId), ".md");
        string memory md = _buildMarkdown(deployer, aquaAddr, swapVMAddr, strategyAddr, hookAddr, f1MarketAddr, bitcoinMarketAddr, lakersMarketAddr, f1Hash, bitcoinHash, lakersHash);
        vm.writeFile(mdPath, md);
        
        // Write JSON file
        _writeDeploymentJson(chainId, deployer, aquaAddr, swapVMAddr, strategyAddr, hookAddr, f1MarketAddr, bitcoinMarketAddr, lakersMarketAddr, f1Hash, bitcoinHash, lakersHash, f1OrderBytes, bitcoinOrderBytes, lakersOrderBytes);
    }

    function _buildMarkdown(
        address deployer,
        address aquaAddr,
        address swapVMAddr,
        address strategyAddr,
        address hookAddr,
        address f1MarketAddr,
        address bitcoinMarketAddr,
        address lakersMarketAddr,
        bytes32 f1Hash,
        bytes32 bitcoinHash,
        bytes32 lakersHash
    ) internal returns (string memory) {
        string memory md = "# Deployment Summary\n\n";
        md = string.concat(md, "## Core Contracts\n\n");
        md = string.concat(md, "- **Deployer**: `", vm.toString(deployer), "`\n");
        md = string.concat(md, "- **Aqua**: `", vm.toString(aquaAddr), "`\n");
        md = string.concat(md, "- **SwapVM**: `", vm.toString(swapVMAddr), "`\n");
        md = string.concat(md, "- **Strategy**: `", vm.toString(strategyAddr), "`\n");
        md = string.concat(md, "- **MakerMintingHook**: `", vm.toString(hookAddr), "`\n\n");
        md = string.concat(md, "## Markets\n\n");
        md = string.concat(md, "- **F1 Market**: `", vm.toString(f1MarketAddr), "`\n");
        md = string.concat(md, "- **Bitcoin Under Market**: `", vm.toString(bitcoinMarketAddr), "`\n");
        md = string.concat(md, "- **Lakers Win Market**: `", vm.toString(lakersMarketAddr), "`\n\n");
        md = string.concat(md, "## Order Hashes\n\n");
        md = string.concat(md, "- **F1 Order Hash**: `", vm.toString(f1Hash), "`\n");
        md = string.concat(md, "- **Bitcoin Under Order Hash**: `", vm.toString(bitcoinHash), "`\n");
        md = string.concat(md, "- **Lakers Win Order Hash**: `", vm.toString(lakersHash), "`\n\n");
        md = string.concat(md, "## Order Bytes\n\n");
        md = string.concat(md, "Order bytes are stored in the JSON file. Use `vm.parseJsonBytes()` to load them.\n");
        return md;
    }

    function _writeDeploymentJson(
        uint256 chainId,
        address deployer,
        address aquaAddr,
        address swapVMAddr,
        address strategyAddr,
        address hookAddr,
        address f1MarketAddr,
        address bitcoinMarketAddr,
        address lakersMarketAddr,
        bytes32 f1Hash,
        bytes32 bitcoinHash,
        bytes32 lakersHash,
        bytes memory f1OrderBytes,
        bytes memory bitcoinOrderBytes,
        bytes memory lakersOrderBytes
    ) internal {
        string memory jsonPath = string.concat("script/json/deployment-", vm.toString(chainId), ".json");
        
        // Use consistent object key for all serialization
        string memory jsonKey = "deployment";
        
        // Serialize addresses - each call returns updated JSON
        string memory json = vm.serializeAddress(jsonKey, "deployer", deployer);
        json = vm.serializeAddress(jsonKey, "aqua", aquaAddr);
        json = vm.serializeAddress(jsonKey, "swapVM", swapVMAddr);
        json = vm.serializeAddress(jsonKey, "strategy", strategyAddr);
        json = vm.serializeAddress(jsonKey, "makerMintingHook", hookAddr);
        json = vm.serializeAddress(jsonKey, "f1Market", f1MarketAddr);
        json = vm.serializeAddress(jsonKey, "bitcoinUnderMarket", bitcoinMarketAddr);
        json = vm.serializeAddress(jsonKey, "lakersWinMarket", lakersMarketAddr);
        
        // Serialize order hashes
        json = vm.serializeBytes32(jsonKey, "f1OrderHash", f1Hash);
        json = vm.serializeBytes32(jsonKey, "bitcoinUnderOrderHash", bitcoinHash);
        json = vm.serializeBytes32(jsonKey, "lakersWinOrderHash", lakersHash);
        
        // Write base JSON first (addresses + hashes)
        vm.writeJson(json, jsonPath);
        
        // Add bytes fields using writeJson with valueKey to update existing file
        string memory f1OrderJson = vm.serializeBytes(jsonKey, "f1Order", f1OrderBytes);
        vm.writeJson(f1OrderJson, jsonPath, "f1Order");
        
        string memory bitcoinOrderJson = vm.serializeBytes(jsonKey, "bitcoinUnderOrder", bitcoinOrderBytes);
        vm.writeJson(bitcoinOrderJson, jsonPath, "bitcoinUnderOrder");
        
        string memory lakersOrderJson = vm.serializeBytes(jsonKey, "lakersWinOrder", lakersOrderBytes);
        vm.writeJson(lakersOrderJson, jsonPath, "lakersWinOrder");
        
        console.log("Deployment JSON written to:", jsonPath);
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

    function deployStrategy(address aquaAddress) public returns (address) {
        PredictionMarketAMM strategyInstance = new PredictionMarketAMM(aquaAddress);
        return address(strategyInstance);
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
        // Use the PredictionMarketAMM strategy to build the order
        // Fee scale: 1e9 = 100%, so 3e6 = 0.3%
        return PredictionMarketAMM(strategy).buildProgram(
            maker,
            uint40(block.timestamp + 365 days), // expiration: 1 year from now
            horizon, // horizon: market expiry time
            3_000_000, // feeBpsIn: 0.3% (3e6 when 1e9 = 100%)
            0, // protocolFeeBpsIn: 0% (no protocol fee)
            address(0), // feeReceiver: not used when protocolFeeBpsIn is 0
            makerMintingHookAddress,
            predictionMarket,
            yieldVault,
            true, // useBalance: use maker's balance outside of vaults
            true, // shouldBorrow: allow borrowing if needed
            0 // salt: no salt needed
        );
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

