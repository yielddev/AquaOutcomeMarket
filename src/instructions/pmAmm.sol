// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;
import "@prb/math/contracts/PRBMathSD59x18.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";
import "solstat/Gaussian.sol"; // From Solstat, assuming cdf(z) and pdf(z) return int256 (scaled 1e18)
import { Context, ContextLib } from "swap-vm/libs/VM.sol";

contract pmAmm {
    using PRBMathSD59x18 for int256;
    using PRBMathUD60x18 for uint256;
    using ContextLib for Context;
    uint256 internal constant L = 2500; // scle to 1e18
    uint256 internal constant SCALE = 1e18;
    error pmmAMMSwapRequiresBothBalancesNonZero(uint256 balanceIn, uint256 balanceOut);
    error pmmAMMSwapNegativeY(int256 y);
    error pmmAMMSwapNegativeX(int256 x);
    error pmmAMMSwapNoConvergence();

    function _pmAmmSwap(Context memory ctx, bytes calldata /* args */) internal view {
        require(ctx.swap.balanceIn > 0 && ctx.swap.balanceOut > 0, pmmAMMSwapRequiresBothBalancesNonZero(ctx.swap.balanceIn, ctx.swap.balanceOut));
        uint256 T = 1764410735; // time stamp next week
        // No is the token with the lower index
        bool isInNo = ctx.query.tokenIn < ctx.query.tokenOut ? true : false;
        uint256 sigma = (T - block.timestamp).sqrt().mul(SCALE).div(SCALE.sqrt()); // Adjust units if T-t not in seconds; scaled
        bool isExactIn = ctx.query.isExactIn;

        if (isExactIn) {
            uint256 newBalanceIn = ctx.swap.balanceIn + ctx.swap.amountIn;
            uint256 amountOut;
            if (isInNo) {
                // Adding to x, known newX, solve f(delta) = delta*(Phi-1) + lSigma*phi - newX = 0
                int256 delta = solveKnownX(newBalanceIn, L, sigma);
                int256 signedNewY = int256(newBalanceIn) + delta;
                require(signedNewY >= 0, pmmAMMSwapNegativeY(signedNewY));
                amountOut = ctx.swap.balanceOut - uint256(signedNewY);
            } else {
                // Adding to y, known newY, solve f(delta) = delta*Phi + lSigma*phi - newY = 0
                int256 delta = solveKnownY(newBalanceIn, L, sigma);
                int256 signedNewX = int256(newBalanceIn) - delta;
                require(signedNewX >= 0, pmmAMMSwapNegativeX(signedNewX));
                amountOut = ctx.swap.balanceOut - uint256(signedNewX);
            }
            ctx.swap.amountOut = amountOut;
        } else { // exact outSwap
            uint256 newBalanceOut = ctx.swap.balanceOut - ctx.swap.amountOut;
            uint256 amountIn;
            if (isInNo) {
                // Subtracting from y, known newY, solve f(delta) = delta*Phi + lSigma*phi - newY = 0
                int256 delta = solveKnownY(newBalanceOut, L, sigma);
                int256 signedNewX = int256(newBalanceOut) - delta;
                require(signedNewX >= 0, pmmAMMSwapNegativeX(signedNewX));
                amountIn = uint256(signedNewX) - ctx.swap.balanceIn;
            } else {
                // Subtracting from x, known newX, solve f(delta) = delta*(Phi-1) + lSigma*phi - newX = 0
                int256 delta = solveKnownX(newBalanceOut, L, sigma);
                int256 signedNewY = int256(newBalanceOut) + delta;
                require(signedNewY >= 0, pmmAMMSwapNegativeY(signedNewY));
                amountIn = uint256(signedNewY) - ctx.swap.balanceIn;
            }
            ctx.swap.amountIn = amountIn;
        }
    }
    
     function solveKnownX(uint256 knownX, uint256 L_, uint256 sigma) internal pure returns (int256) {
        uint256 lSigma = L_.mul(sigma / SCALE) / SCALE; // Assume L, sigma scaled
        int256 guess = 0; // Or current delta estimate
        uint256 maxIter = 20;
        int256 tol = int256(SCALE / 1e12); // Precision

        for (uint256 i = 0; i < maxIter; i++) {
            int256 z = guess.div(int256(lSigma));
            int256 Phi = Gaussian.cdf(z);
            int256 phi = Gaussian.pdf(z);
            int256 f = guess.mul(Phi - int256(SCALE)) / int256(SCALE) + int256(lSigma).mul(phi) / int256(SCALE) - int256(knownX);
            int256 df = Phi - int256(SCALE);
            if (df == 0) df = 1; // Rare edge
            int256 step = f.mul(int256(SCALE)) / df;
            guess -= step;
            if (abs(step) < tol) return guess;
        }
        revert pmmAMMSwapNoConvergence();
    }

    function solveKnownY(uint256 knownY, uint256 L_, uint256 sigma) internal pure returns (int256) {
        uint256 lSigma = L_.mul(sigma / SCALE) / SCALE;
        int256 guess = 0;
        uint256 maxIter = 20;
        int256 tol = int256(SCALE / 1e12);

        for (uint256 i = 0; i < maxIter; i++) {
            int256 z = guess.div(int256(lSigma));
            int256 Phi = Gaussian.cdf(z);
            int256 phi = Gaussian.pdf(z);
            int256 f = guess.mul(Phi) / int256(SCALE) + int256(lSigma).mul(phi) / int256(SCALE) - int256(knownY);
            int256 df = Phi;
            if (df == 0) df = 1;
            int256 step = f.mul(int256(SCALE)) / df;
            guess -= step;
            if (abs(step) < tol) return guess;
        }
        revert pmmAMMSwapNoConvergence();
    }

    function abs(int256 a) internal pure returns (int256) {
        return a >= 0 ? a : -a;
    }   

}