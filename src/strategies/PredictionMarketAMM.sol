// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

/// @custom:license-url https://github.com/1inch/swap-vm/blob/main/LICENSES/SwapVM-1.1.txt
/// @custom:copyright © 2025 Degensoft Ltd

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { OpcodesDebugCustom } from "../opcodes/OpcodesDebugCustom.sol";
import { SwapVM, ISwapVM } from "swap-vm/SwapVM.sol";
import { MakerTraitsLib } from "swap-vm/libs/MakerTraits.sol";
import { ProgramBuilder, Program } from "@1inch/swap-vm/test/utils/ProgramBuilder.sol";

import { FeeArgsBuilder, Fee } from "swap-vm/instructions/Fee.sol";
import { ControlsArgsBuilder, Controls } from "swap-vm/instructions/Controls.sol";
import { pmAmm } from "../instructions/pmAmm.sol";

contract PredictionMarketAMM is OpcodesDebugCustom {
    using SafeCast for uint256;
    using ProgramBuilder for Program;

    error ProtocolFeesExceedMakerFees(uint256 protocolFeeBps, uint256 makerFeeBps);
    error InvalidHorizon(uint256 horizon, uint256 currentTime);

    constructor(address aqua) OpcodesDebugCustom(aqua) {}

    function buildProgram(
        address maker,
        uint40 expiration,
        uint256 horizon,
        uint32 feeBpsIn,
        uint32 protocolFeeBpsIn,
        address feeReceiver,
        address makerMintingHook,
        address predictionMarket,
        address yieldVault,
        bool useBalance,
        bool shouldBorrow,
        uint64 salt
    ) external view returns (ISwapVM.Order memory) {
        require(protocolFeeBpsIn <= feeBpsIn, ProtocolFeesExceedMakerFees(protocolFeeBpsIn, feeBpsIn));
        require(horizon > block.timestamp, InvalidHorizon(horizon, block.timestamp));

        Program memory program = ProgramBuilder.init(_opcodes());
        bytes memory bytecode = bytes.concat(
            (feeBpsIn > 0) ? program.build(_flatFeeAmountInXD, FeeArgsBuilder.buildFlatFee(feeBpsIn)) : bytes(""),
            (protocolFeeBpsIn > 0) ? program.build(_aquaProtocolFeeAmountOutXD, FeeArgsBuilder.buildProtocolFee(protocolFeeBpsIn, feeReceiver)) : bytes(""),
            program.build(pmAmm._pmAmmSwap, abi.encode(horizon)),
            program.build(_deadline, ControlsArgsBuilder.buildDeadline(expiration)),
            (salt > 0) ? program.build(_salt, ControlsArgsBuilder.buildSalt(salt)) : bytes("")
        );

        bool hasPreTransferOutHook = makerMintingHook != address(0);
        bytes memory preTransferOutData = hasPreTransferOutHook 
            ? abi.encode(predictionMarket, yieldVault, useBalance, shouldBorrow)
            : bytes("");

        return MakerTraitsLib.build(MakerTraitsLib.Args({
            maker: maker,
            shouldUnwrapWeth: false,
            useAquaInsteadOfSignature: true,
            allowZeroAmountIn: false,
            receiver: address(0),
            hasPreTransferInHook: false,
            hasPostTransferInHook: false,
            hasPreTransferOutHook: hasPreTransferOutHook,
            hasPostTransferOutHook: false,
            preTransferInTarget: address(0),
            preTransferInData: "",
            postTransferInTarget: address(0),
            postTransferInData: "",
            preTransferOutTarget: makerMintingHook,
            preTransferOutData: preTransferOutData,
            postTransferOutTarget: address(0),
            postTransferOutData: "",
            program: bytecode
        }));
    }
}

