// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "./lib/ArbitrumLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

/// @notice Base test contract that forks Arbitrum One
/// @dev Inherit from this contract to run tests against a forked Arbitrum network
abstract contract ArbitrumBaseTest is Test {
    /// @notice The block number to fork from (can be overridden)
    uint256 public forkBlockNumber;

    /// @notice The RPC URL for Arbitrum One (can be set via environment variable)
    string public arbitrumRpcUrl;

    /// @notice Setup function that forks Arbitrum One
    /// @dev Override this if you need custom setup, but call super.setUp() first
    function setUp() public virtual {
        // Get RPC URL from environment variable or use default
        arbitrumRpcUrl = vm.envOr("ARBITRUM_ONE_RPC_URL", string("https://arb1.arbitrum.io/rpc"));
        
        // Get fork block number from environment variable or use latest
        forkBlockNumber = vm.envOr("ARBITRUM_FORK_BLOCK", uint256(0));
        
        // Create fork - if forkBlockNumber is 0, fork from latest block
        if (forkBlockNumber == 0) {
            vm.createSelectFork(arbitrumRpcUrl);
        } else {
            vm.createSelectFork(arbitrumRpcUrl, forkBlockNumber);
        }
        
        // Log fork information
        console.log("Forked Arbitrum One at block:", block.number);
        console.log("Chain ID:", block.chainid);
    }

    function _dealUSDC(address account, uint256 amount) public {
        vm.prank(ArbitrumLib.USDC_WHALE);
        IERC20(ArbitrumLib.USDC).transfer(account, amount);
    }

    /// @notice Helper to create a new fork at a specific block
    /// @param blockNumber The block number to fork from
    function forkAt(uint256 blockNumber) public {
        vm.createSelectFork(arbitrumRpcUrl, blockNumber);
        forkBlockNumber = blockNumber;
        console.log("Forked Arbitrum One at block:", blockNumber);
    }

    /// @notice Helper to roll the fork to a specific block
    /// @param blockNumber The block number to roll to
    function rollFork(uint256 blockNumber) public {
        vm.rollFork(blockNumber);
        forkBlockNumber = blockNumber;
        console.log("Rolled fork to block:", blockNumber);
    }
}

