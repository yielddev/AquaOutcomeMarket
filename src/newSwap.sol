// SPDX-License-Identifier: LicenseRef-Degensoft-Aqua-Source-1.1
pragma solidity 0.8.30;

import { IAqua } from "@1inch/aqua/src/interfaces/IAqua.sol";
import { AquaApp } from "@1inch/aqua/src/AquaApp.sol";


contract NewSwap is AquaApp {

    struct Strategy {
        address maker;
        address token0;
        address token1;
        uint256 feeBps;
        bytes32 salt;
    }

    uint256 internal constant BPS_BASE = 10_000;

    constructor(IAqua aqua_) AquaApp(aqua_) { }

    function quoteExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {

    }

    function quoteExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {

    }

    function swapExactIn(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        bytes calldata takerData
    ) external returns (uint256 amountOut) {}

    function swapExactOut(
        Strategy calldata strategy,
        bool zeroForOne,
        uint256 amountOut,
        uint256 amountInMax,
        address to,
        bytes calldata takerData
    ) external returns (uint256 amountIn) {

    }

    function _quoteExactIn(
        Strategy calldata strategy,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {

    }

    function _quoteExactOut(
        Strategy calldata strategy,
        uint256 balanceIn,
        uint256 balanceOut,
        uint256 amountOut
    ) internal view returns (uint256 amountIn) {

    }

    function _getInAndOut(Strategy calldata strategy, bytes32 strategyHash, bool zeroForOne) private view returns (address tokenIn, address tokenOut, uint256 balanceIn, uint256 balanceOut) {}
}