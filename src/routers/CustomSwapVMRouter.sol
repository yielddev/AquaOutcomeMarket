// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Context } from "swap-vm/libs/VM.sol";
import { Simulator } from "swap-vm/libs/Simulator.sol";
import { SwapVM } from "swap-vm/SwapVM.sol";
import { OpcodesCustom } from "../opcodes/OpcodesCustom.sol";

contract CustomSwapVMRouter is Simulator, SwapVM, OpcodesCustom {
    constructor(address aqua, string memory name, string memory version) SwapVM(aqua, name, version) OpcodesCustom(aqua) { }

    function _instructions() internal pure override returns (function(Context memory, bytes calldata) internal[] memory result) {
        return _opcodes();
    }
}

