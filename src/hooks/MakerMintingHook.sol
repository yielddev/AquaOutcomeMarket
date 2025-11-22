pragma solidity 0.8.30;

import { IMakerHooks } from "swap-vm/interfaces/IMakerHooks.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPredictionMarket } from "../market/IPredictionMarket.sol";

contract MakerMintingHook is IMakerHooks {
    function preTransferIn(
        address maker,
        address taker,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes32 orderHash,
        bytes calldata makerData,
        bytes calldata takerData
    ) external {
    }

    /// @dev Maker dynamically handle tokenIn after tokens being transferred
    function postTransferIn(
        address maker,
        address taker,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes32 orderHash,
        bytes calldata makerData,
        bytes calldata takerData
    ) external override {
    }

    /// @dev Maker can dymically prepare tokenOut before tokens being transfered
    function preTransferOut(
        address maker,
        address taker,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes32 orderHash,
        bytes calldata makerData,
        bytes calldata takerData
    ) external {
        address predictionMarket = abi.decode(makerData, (address));
        if (amountOut > 0) {
            uint256 balance = IERC20(tokenOut).balanceOf(maker);
            uint256 needed = amountOut > balance ? amountOut - balance : 0;
            if (needed > 0) {
                IERC20(IPredictionMarket(predictionMarket).collateral()).transferFrom(maker, address(this), needed);
                IERC20(IPredictionMarket(predictionMarket).collateral()).approve(predictionMarket, needed);
                IPredictionMarket(predictionMarket).mint(maker, needed);
            }
        }
    }

    function postTransferOut(
        address maker,
        address taker,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        bytes32 orderHash,
        bytes calldata makerData,
        bytes calldata takerData
    ) external {
    }

}