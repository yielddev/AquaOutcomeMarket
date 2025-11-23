// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import {ITakerCallbacks} from "swap-vm/interfaces/ITakerCallbacks.sol";
import {ISwapVM} from "swap-vm/interfaces/ISwapVM.sol";
import {Aqua} from "@1inch/aqua/src/Aqua.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@1inch/solidity-utils/contracts/libraries/SafeERC20.sol";

/// @notice Helper contract for takers to execute swaps with Aqua
/// @dev Implements ITakerCallbacks to handle Aqua push during swap execution
contract TakerCallback is ITakerCallbacks {
    Aqua public immutable AQUA;
    ISwapVM public immutable swapVM;

    constructor(Aqua aqua, address swapVM_) {
        AQUA = aqua;
        swapVM = ISwapVM(swapVM_);
    }

    /// @notice Execute a swap - must be called from this contract
    /// @dev This ensures SwapVM can call the callback on this contract
    function swap(
        ISwapVM.Order calldata order,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        bytes calldata takerTraitsAndData
    ) external returns (uint256 amountIn, uint256 amountOut) {
        (amountIn, amountOut,) = swapVM.swap(
            order,
            tokenIn,
            tokenOut,
            amount,
            takerTraitsAndData
        );
    }

    /// @notice Callback called by SwapVM before transferring tokens in
    /// @dev This is where we approve Aqua and push tokens to complete the swap
    function preTransferInCallback(
        address maker,
        address /* taker */,
        address tokenIn,
        address /* tokenOut */,
        uint256 amountIn,
        uint256 /* amountOut */,
        bytes32 orderHash,
        bytes calldata /* takerData */
    ) external override {
        // Only SwapVM can call this
        require(msg.sender == address(swapVM), "Only SwapVM can call this");
        
        // Approve Aqua to spend the tokens
        // Try approve first, and if it fails (e.g., USDT), reset to 0 and try again
        // This handles tokens that require resetting approval to 0 first
        IERC20(tokenIn).approve(address(AQUA), 0);
        IERC20(tokenIn).approve(address(AQUA), amountIn);
        
        // Push tokens to Aqua to complete the swap
        // This is the ONLY appropriate use of push() - during swap execution
        AQUA.push(maker, address(swapVM), orderHash, tokenIn, amountIn);
    }

    /// @notice Callback called by SwapVM before transferring tokens out
    function preTransferOutCallback(
        address /* maker */,
        address /* taker */,
        address /* tokenIn */,
        address /* tokenOut */,
        uint256 /* amountIn */,
        uint256 /* amountOut */,
        bytes32 /* orderHash */,
        bytes calldata /* takerData */
    ) external override {
        // Only SwapVM can call this
        require(msg.sender == address(swapVM), "Only SwapVM can call this");
        // Can add custom validation here if needed
    }
}

