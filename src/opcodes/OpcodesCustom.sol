// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { Context } from "swap-vm/libs/VM.sol";
import { Opcodes } from "swap-vm/opcodes/Opcodes.sol";
import { pmAmm } from "../instructions/pmAmm.sol";

contract OpcodesCustom is Opcodes, pmAmm {

    constructor(address aqua) Opcodes(aqua) {}

    function _opcodes() internal pure override virtual returns (function(Context memory, bytes calldata) internal[] memory result) {
        // Get base opcodes from Opcodes
        function(Context memory, bytes calldata) internal[] memory baseOpcodes = super._opcodes();
        
        // Create new array with one additional opcode
        function(Context memory, bytes calldata) internal[] memory instructions = new function(Context memory, bytes calldata) internal[](baseOpcodes.length + 1);
        
        // Copy base opcodes
        for (uint256 i = 0; i < baseOpcodes.length; i++) {
            instructions[i] = baseOpcodes[i];
        }
        
        //Add custom pmAmm swap opcode at the end
        instructions[baseOpcodes.length] = pmAmm._pmAmmSwap;
        
        return instructions;
    }
}