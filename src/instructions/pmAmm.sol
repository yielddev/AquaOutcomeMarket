pragma solidity 0.8.30;
import "@prb/math/contracts/PRBMathSD59x18.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";
import "solstat/Gaussian.sol"; // From Solstat, assuming cdf(z) and pdf(z) return int256 (scaled 1e18)
import { Context, ContextLib } from "swap-vm/libs/VM.sol";

contract pmAmm {
    using PRBMathSD59x18 for int256;
    using PRBMathUD60x18 for uint256;
    using ContextLib for Context;
    uint256 internal constant L = 2500 * 1e18; // scaled to internal math precision (1e18)
    uint256 internal constant MATH_SCALE = 1e18;
    uint256 internal constant TOKEN_DECIMALS = 1e6; // for 6-decimal tokens
    uint256 internal constant SCALE_FACTOR = MATH_SCALE / TOKEN_DECIMALS; // 1e12
    error pmmAMMSwapRequiresBothBalancesNonZero(uint256 balanceIn, uint256 balanceOut);
    error pmmAMMSwapNegativeY(int256 y);
    error pmmAMMSwapNegativeX(int256 x);
    error pmmAMMSwapNoConvergence();
    error pmmAMMSwapMarketExpired();

    function _pmAmmSwap(Context memory ctx, bytes calldata /* args */) internal view {
        require(ctx.swap.balanceIn > 0 && ctx.swap.balanceOut > 0, pmmAMMSwapRequiresBothBalancesNonZero(ctx.swap.balanceIn, ctx.swap.balanceOut));
        uint256 T = 1764410735; // time stamp next week
        require(T > block.timestamp, pmmAMMSwapMarketExpired());
        // No is the token with the lower index
        bool isInNo = ctx.query.tokenIn < ctx.query.tokenOut ? true : false;
        uint256 time_diff = T - block.timestamp;
        uint256 year_secs = 31536000;
        uint256 time_year = PRBMathUD60x18.div(PRBMathUD60x18.fromUint(time_diff), PRBMathUD60x18.fromUint(year_secs));
        uint256 sigma = PRBMathUD60x18.sqrt(time_year); // sqrt(time/year) in fixed-point format, already scaled
        require(sigma > 0, pmmAMMSwapMarketExpired());
        uint256 lSigma = L.mul(sigma).div(MATH_SCALE);
        // Scale balances to internal precision
        uint256 scaledBalanceIn = ctx.swap.balanceIn * SCALE_FACTOR;
        uint256 scaledBalanceOut = ctx.swap.balanceOut * SCALE_FACTOR;
        // Compute current k with scaled values
        int256 current_x = isInNo ? int256(scaledBalanceIn) : int256(scaledBalanceOut);
        int256 current_y = isInNo ? int256(scaledBalanceOut) : int256(scaledBalanceIn);
        int256 current_delta = current_y - current_x;
        int256 current_z = current_delta.div(int256(lSigma));
        int256 current_Phi = Gaussian.cdf(current_z);
        int256 current_phi = Gaussian.pdf(current_z);
        int256 k = current_delta.mul(current_Phi) + int256(lSigma).mul(current_phi) - current_y;
        bool isExactIn = ctx.query.isExactIn;

        if (isExactIn) {
            uint256 scaledAmountIn = ctx.swap.amountIn * SCALE_FACTOR;
            uint256 newBalanceIn = scaledBalanceIn + scaledAmountIn;
            uint256 scaledAmountOut;
            if (isInNo) {
                // Adding to x, known newX, solve f(delta) = delta*(Phi-1) + lSigma*phi - newX = k
                int256 delta = solveKnownX(newBalanceIn, lSigma, k);
                int256 signedNewY = int256(newBalanceIn) + delta;
                require(signedNewY >= 0, pmmAMMSwapNegativeY(signedNewY));
                scaledAmountOut = scaledBalanceOut - uint256(signedNewY);
            } else {
                // Adding to y, known newY, solve f(delta) = delta*Phi + lSigma*phi - newY = k
                int256 delta = solveKnownY(newBalanceIn, lSigma, k);
                int256 signedNewX = int256(newBalanceIn) - delta;
                require(signedNewX >= 0, pmmAMMSwapNegativeX(signedNewX));
                scaledAmountOut = scaledBalanceOut - uint256(signedNewX);
            }
            ctx.swap.amountOut = scaledAmountOut / SCALE_FACTOR;
        } else { // exact outSwap
            uint256 scaledAmountOut = ctx.swap.amountOut * SCALE_FACTOR;
            uint256 newBalanceOut = scaledBalanceOut - scaledAmountOut;
            uint256 scaledAmountIn;
            if (isInNo) {
                // Subtracting from y, known newY, solve f(delta) = delta*Phi + lSigma*phi - newY = k
                int256 delta = solveKnownY(newBalanceOut, lSigma, k);
                int256 signedNewX = int256(newBalanceOut) - delta;
                require(signedNewX >= 0, pmmAMMSwapNegativeX(signedNewX));
                scaledAmountIn = uint256(signedNewX) - scaledBalanceIn;
            } else {
                // Subtracting from x, known newX, solve f(delta) = delta*(Phi-1) + lSigma*phi - newX = k
                int256 delta = solveKnownX(newBalanceOut, lSigma, k);
                int256 signedNewY = int256(newBalanceOut) + delta;
                require(signedNewY >= 0, pmmAMMSwapNegativeY(signedNewY));
                scaledAmountIn = uint256(signedNewY) - scaledBalanceIn;
            }
            ctx.swap.amountIn = scaledAmountIn / SCALE_FACTOR;
        }
    }
    
    function solveKnownX(uint256 knownX, uint256 lSigma, int256 k) internal pure returns (int256) {
        int256 guess = -int256(knownX) / 2; // better initial guess for convergence
        uint256 maxIter = 10;
        int256 tol = int256(MATH_SCALE / 1e6); // Precision

        for (uint256 i = 0; i < maxIter; i++) {
            int256 z = guess.div(int256(lSigma));
            int256 Phi = Gaussian.cdf(z);
            int256 phi = Gaussian.pdf(z);
            int256 f = guess.mul(Phi) - guess + int256(lSigma).mul(phi) - int256(knownX) - k;
            int256 df = Phi - int256(MATH_SCALE);
            if (df == 0) df = 1; // Rare edge
            int256 step = f.div(df);
            guess -= step;
            if (abs(step) < tol) return guess;
        }
        revert pmmAMMSwapNoConvergence();
    }

    function solveKnownY(uint256 knownY, uint256 lSigma, int256 k) internal pure returns (int256) {
        int256 guess = -int256(knownY) / 2;
        uint256 maxIter = 10;
        int256 tol = int256(MATH_SCALE / 1e6);

        for (uint256 i = 0; i < maxIter; i++) {
            int256 z = guess.div(int256(lSigma));
            int256 Phi = Gaussian.cdf(z);
            int256 phi = Gaussian.pdf(z);
            int256 f = guess.mul(Phi) + int256(lSigma).mul(phi) - int256(knownY) - k;
            int256 df = Phi;
            if (df == 0) df = 1;
            int256 step = f.div(df);
            guess -= step;
            if (abs(step) < tol) return guess;
        }
        revert pmmAMMSwapNoConvergence();
    }

    function abs(int256 a) internal pure returns (int256) {
        return a >= 0 ? a : -a;
    }   

}