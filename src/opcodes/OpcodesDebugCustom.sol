// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Context } from "@1inch/swap-vm/libs/VM.sol";
import { Opcodes } from "@1inch/swap-vm/opcodes/Opcodes.sol";
import { Debug } from "@1inch/swap-vm/instructions/Debug.sol";
import { OpcodesCustom } from "./OpcodesCustom.sol";

contract OpcodesDebugCustom is OpcodesCustom, Debug {

    constructor(address aqua) OpcodesCustom(aqua) {}

    function _opcodes() internal pure override(OpcodesCustom) returns (function(Context memory, bytes calldata) internal[] memory) {
        // Get opcodes from OpcodesCustom (which includes pmAmm)
        function(Context memory, bytes calldata) internal[] memory customOpcodes = OpcodesCustom._opcodes();
        // Inject debug opcodes using the method from Debug
        return _injectDebugOpcodes(customOpcodes);
    }
}