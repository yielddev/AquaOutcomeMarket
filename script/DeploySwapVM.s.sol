// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {Aqua} from "@1inch/aqua/src/Aqua.sol";
import {CustomSwapVMRouter} from "../src/routers/CustomSwapVMRouter.sol";
import "forge-std/console.sol";

contract DeploySwapVM is Script {
    function run() public {
        // Get private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DeploySwapVM Debug Script ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Aqua
        console.log("Deploying Aqua...");
        Aqua aquaInstance = new Aqua();
        address aquaAddress = address(aquaInstance);
        console.log("Aqua deployed at:", aquaAddress);
        console.log("");

        // Deploy SwapVM
        console.log("Deploying SwapVM...");
        console.log("  - Aqua address:", aquaAddress);
        console.log("  - Name: Aqua Outcome Market");
        console.log("  - Version: 0.0.1");
        console.log("  - Deployer balance:", deployer.balance);
        console.log("  - Gas price:", tx.gasprice);
        
        uint256 gasBefore = gasleft();
        CustomSwapVMRouter swapVMInstance = new CustomSwapVMRouter(
            aquaAddress,
            "Aqua Outcome Market",
            "0.0.1"
        );
        uint256 gasUsed = gasBefore - gasleft();
        address swapVMAddress = address(swapVMInstance);
        console.log("SwapVM deployed at:", swapVMAddress);
        console.log("Gas used:", gasUsed);
        console.log("Contract code size:", swapVMAddress.code.length);
        
        // Verify deployment
        require(swapVMAddress.code.length > 0, "SwapVM deployment failed - no code");
        console.log("SwapVM deployment verified");
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("=== Deployment Summary ===");
        console.log("Aqua:", aquaAddress);
        console.log("SwapVM:", swapVMAddress);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
    }
}

