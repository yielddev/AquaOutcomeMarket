pragma solidity 0.8.30;

import { IMakerHooks } from "swap-vm/interfaces/IMakerHooks.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPredictionMarket } from "../market/IPredictionMarket.sol";
import { IEVault } from "euler-interfaces/IEVault.sol";
import { EVCUtil } from "evc/utils/EVCUtil.sol";
import { IEthereumVaultConnector } from "euler-interfaces/IEthereumVaultConnector.sol";

contract MakerMintingHook is EVCUtil, IMakerHooks {
    address public immutable swapVM;
    error MakerMintingHook__InvalidSender();
    constructor(IEthereumVaultConnector _evc, address _swapVM) EVCUtil(address(_evc)) {
        swapVM = _swapVM;
    }
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
        require(msg.sender == swapVM, MakerMintingHook__InvalidSender());
        (address predictionMarket, address vault, bool useBalance, bool canBorrow) = abi.decode(makerData, (address, address, bool, bool));
        // vault
        // use balance bool

        if (amountOut > 0) {
            uint256 balance = IERC20(tokenOut).balanceOf(maker);
            uint256 needed = amountOut > balance ? amountOut - balance : 0;
            if (needed > 0) {
                uint256 avail;
                uint256 convert = needed;
                IERC20 money = IERC20(IPredictionMarket(predictionMarket).collateral());

                if (useBalance) {
                    avail = money.balanceOf(maker);
                    IERC20(money).transferFrom(maker, address(this), avail);
                    needed = avail > needed ? 0: needed - avail;
                }

                if (needed > 0) {
                    avail = IEVault(vault).balanceOf(maker);
                    avail = avail == 0 ? 0 : IEVault(vault).convertToAssets(avail);
                    if (avail > 0) {
                        avail = needed < avail ? needed : avail;
                        evc.call(vault, maker, 0, abi.encodeCall(
                            IEVault.withdraw, (avail, address(this), maker)));
                        needed -= avail;
                    }
                    if (needed > 0 && canBorrow) {
                        evc.enableController(maker, vault);
                        evc.call(vault, maker, 0, abi.encodeCall(
                            IEVault.borrow, (needed, address(this))));
                    }
                }

                IERC20(money).approve(predictionMarket, convert);
                IPredictionMarket(predictionMarket).mint(maker, convert);
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