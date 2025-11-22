// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;
import "@prb/math/contracts/PRBMathUD60x18.sol"; // For sqrt, mulDiv
import "./Gaussian.sol"; // From Solstat, assuming cdf(z) and pdf(z) return int256 (scaled 1e18)
import { Context, ContextLib } from "swap-vm/libs/VM.sol";


library DynamicPmAmm {
    error DynamicPmAmmInconsistentPrices(uint256 price, uint256 priceMin, uint256 priceMax);
    error DynamicPmAmmNoConvergence();
    function computeDeltas(
        uint256 balanceA,
        uint256 balanceB,
        uint256 price,
        uint256 priceMin,
        uint256 priceMax
    ) public pure returns (uint256 d) {
        require(priceMin <= price && price <= priceMax, ConcentrateInconsistentPrices(price, priceMin, priceMax));
        int256 d = int256(y) - int256(x); // Initial guess: current delta
        uint256 scaledLSigma = L * sigma / 1e18;
        uint256 MAX_ITER = 20;
        int256 TOL = 1; // Adjust for precision, e.g., 1 wei

        for (uint256 i = 0; i < MAX_ITER; i++) {
            int256 z = d * 1e18 / int256(scaledLSigma);
            int256 Phi = Gaussian.cdf(z);
            int256 phi = Gaussian.pdf(z);
            int256 fd = d * (Phi - 1e18) / 1e18 + int256(scaledLSigma) * phi / 1e18 - int256(newX);
            int256 dfd = Phi - 1e18; // Scaled 1e18
            if (dfd == 0) revert("Division by zero");
            int256 dNew = d - fd * 1e18 / (dfd / 1e18); // Careful with scaling
            if (abs(dNew - d) < TOL) return dNew;
            d = dNew;
        }
        revert DynamicPmAmmNoConvergence();
 
    }

    function parseArgs(bytes calldata args, address tokenIn, address tokenOut) internal pure returns (uint256 deltaIn, uint256 deltaOut) {

    }
}
contract pmAmm {
    using PRBMathUD60x18 for uint256;
    using ContextLib for Context;


    function _pmAmmSwap(Context memory ctx, bytes calldata /* args */) internal pure {
        require(ctx.swap.balanceIn > 0 && ctx.swap.balanceOut > 0, XYCSwapRequiresBothBalancesNonZero(ctx.swap.balanceIn, ctx.swap.balanceOut));

        if (ctx.query.isExactIn) {
            require(ctx.swap.amountOut == 0, XYCSwapRecomputeDetected());
            // 
            ctx.swap.amountOut = ( // Floor division for tokenOut is desired behavior
                (ctx.swap.amountIn * ctx.swap.balanceOut) /
                (ctx.swap.balanceIn + ctx.swap.amountIn)
            );
        } else {
            require(ctx.swap.amountIn == 0, XYCSwapRecomputeDetected());
            ctx.swap.amountIn = Math.ceilDiv( // Ceiling division for tokenIn is desired behavior
                ctx.swap.amountOut * ctx.swap.balanceIn,
                (ctx.swap.balanceOut - ctx.swap.amountOut)
            );
        }
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



contract PmAMM {


    uint256 public immutable L; // Liquidity parameter, scaled 1e18
    uint256 public immutable T; // Expiration timestamp
    uint256 public x; // NO reserve, unscaled (wei)
    uint256 public y; // YES reserve, unscaled (wei)
    // Assume token contracts and liquidity provision omitted for brevity

    constructor(uint256 _L, uint256 _T, uint256 _initialX, uint256 _initialY) {
        L = _L.mul(1e18); // Scale if needed
        T = _T;
        x = _initialX;
        y = _initialY;
        require(checkInvariant() == 0, "Invalid initial reserves");
    }

    function getSigma() internal view returns (uint256) {
        require(block.timestamp < T, "Expired");
        uint256 remaining = T - block.timestamp;
        return remaining.sqrt(); // PRBMath sqrt assumes unscaled; scale if time units need adjustment
    }

    function checkInvariant() internal view returns (int256) {
        uint256 sigma = getSigma();
        int256 delta = int256(y) - int256(x); // Handle signs carefully
        int256 scaledDelta = delta * 1e18 / int256(sigma * L / 1e18); // Adjust scaling
        int256 phi = Gaussian.pdf(scaledDelta);
        int256 Phi = Gaussian.cdf(scaledDelta);
        return delta * Phi / 1e18 + int256(L * sigma / 1e18) * phi / 1e18 - int256(y);
    }



    // Swap: add amountIn to x (buy YES with NO), get amountOut from y
    function swapBuyYes(uint256 amountIn) external returns (uint256 amountOut) {
        // Transfer tokens omitted
        //uint256 newX = x + amountIn;
        uint256 sigma = getSigma(); // time scale factor
        int256 newDelta = solveDelta(x + amountIn, sigma);
        uint256 newY = newX + uint256(newDelta); // Assume positive
        amountOut = y - newY;
        x = newX;
        y = newY;
        require(checkInvariant() == 0, "Invariant mismatch");
    }

    // Similar for buyNo (symmetric but solve for new delta with newY)
    // ...

    function abs(int256 a) internal pure returns (int256) {
        return a >= 0 ? a : -a;
    }
}