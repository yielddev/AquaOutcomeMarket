pragma solidity 0.8.30;
import "@prb/math/contracts/PRBMathSD59x18.sol";
import "@prb/math/contracts/PRBMathUD60x18.sol";
import { Gaussian as GaussianCDF } from "solgauss/Gaussian.sol"; // CDF from cairoeth/solgauss
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
    function pdf(int256 z) internal pure returns (int256) {
        int256 zSquared = z.mul(z);
        int256 exponent = zSquared.div(-2e18); // Scaled to 1e18
        int256 expVal = PRBMathSD59x18.exp(exponent);
        int256 twoPi = PRBMathSD59x18.mul(PRBMathSD59x18.fromInt(2), PRBMathSD59x18.pi());
        int256 denominator = PRBMathSD59x18.sqrt(twoPi);
        return expVal.div(denominator);
    }
    function _pmAmmSwap(Context memory ctx, bytes calldata args) internal view {
        require(ctx.swap.balanceIn > 0 && ctx.swap.balanceOut > 0, pmmAMMSwapRequiresBothBalancesNonZero(ctx.swap.balanceIn, ctx.swap.balanceOut));

        uint256 T = abi.decode(args, (uint256));
        require(T > block.timestamp, pmmAMMSwapMarketExpired());

        bool isInNo = ctx.query.tokenIn < ctx.query.tokenOut;
        uint256 lSigma;
        {
            // Scoped for sigma
            uint256 time_year = PRBMathUD60x18.div(PRBMathUD60x18.fromUint(T - block.timestamp), PRBMathUD60x18.fromUint(31536000));
            uint256 sigma = PRBMathUD60x18.sqrt(time_year);
        require(sigma > 0, pmmAMMSwapMarketExpired());
            lSigma = L.mul(sigma).div(MATH_SCALE);
        }

        uint256 scaledBalanceIn = ctx.swap.balanceIn * SCALE_FACTOR;
        uint256 scaledBalanceOut = ctx.swap.balanceOut * SCALE_FACTOR;

        int256 k;
        {
            // Scoped for k
        int256 current_x = isInNo ? int256(scaledBalanceIn) : int256(scaledBalanceOut);
        int256 current_y = isInNo ? int256(scaledBalanceOut) : int256(scaledBalanceIn);
        int256 current_delta = current_y - current_x;
        int256 current_z = current_delta.div(int256(lSigma));
            // Use new CDF library: cdf(x, mu, sigma) where mu=0, sigma=1 for standard normal
            // Convert uint256 result to int256 (CDF returns [0, 1e18] range)
            uint256 cdfResult = GaussianCDF.cdf(current_z, 0, 1e18);
            int256 cdfInt = int256(cdfResult);
            k = current_delta.mul(cdfInt) + int256(lSigma).mul(pdf(current_z)) - current_y;
        }

        if (ctx.query.isExactIn) {
            _handleExactIn(ctx, isInNo, lSigma, scaledBalanceIn, scaledBalanceOut, k);
        } else {
            _handleExactOut(ctx, isInNo, lSigma, scaledBalanceIn, scaledBalanceOut, k);
        }
    }

    function _handleExactIn(Context memory ctx, bool isInNo, uint256 lSigma, uint256 scaledBalanceIn, uint256 scaledBalanceOut, int256 k) internal pure {
            uint256 scaledAmountIn = ctx.swap.amountIn * SCALE_FACTOR;
        uint256 newBalance = scaledBalanceIn + scaledAmountIn;
        int256 delta = isInNo ? solveKnownX(newBalance, lSigma, k) : solveKnownY(newBalance, lSigma, k);
        int256 signedNewOther = isInNo ? int256(newBalance) + delta : int256(newBalance) - delta;
        if (signedNewOther < 0) {
            if (isInNo) revert pmmAMMSwapNegativeY(signedNewOther);
            revert pmmAMMSwapNegativeX(signedNewOther);
        }
        ctx.swap.amountOut = (scaledBalanceOut - uint256(signedNewOther)) / SCALE_FACTOR;
    }

    function _handleExactOut(Context memory ctx, bool isInNo, uint256 lSigma, uint256 scaledBalanceIn, uint256 scaledBalanceOut, int256 k) internal pure {
            uint256 scaledAmountOut = ctx.swap.amountOut * SCALE_FACTOR;
        uint256 newBalance = scaledBalanceOut - scaledAmountOut;
        int256 delta = isInNo ? solveKnownY(newBalance, lSigma, k) : solveKnownX(newBalance, lSigma, k);
        int256 signedNewOther = isInNo ? int256(newBalance) - delta : int256(newBalance) + delta;
        if (signedNewOther < 0) {
            if (isInNo) revert pmmAMMSwapNegativeX(signedNewOther);
            revert pmmAMMSwapNegativeY(signedNewOther);
        }
        ctx.swap.amountIn = (uint256(signedNewOther) - scaledBalanceIn) / SCALE_FACTOR;
    }
    
    function solveKnownX(uint256 knownX, uint256 lSigma, int256 k) internal pure returns (int256) {
        int256 guess = -int256(knownX) / 2; // better initial guess for convergence
        uint256 maxIter = 10;
        int256 tol = int256(MATH_SCALE / 1e6); // Precision

        for (uint256 i = 0; i < maxIter; i++) {
            int256 z = guess.div(int256(lSigma));
            uint256 cdfResult = GaussianCDF.cdf(z, 0, 1e18);
            int256 Phi = int256(cdfResult);
            int256 phi = pdf(z);
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
            uint256 cdfResult = GaussianCDF.cdf(z, 0, 1e18);
            int256 Phi = int256(cdfResult);
            int256 phi = pdf(z);
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