pragma solidity 0.8.30;
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PredictionToken is ERC20, Ownable {
    string private symbol_;
    constructor(string memory name_) ERC20(name_, "") Ownable(msg.sender) {
    }

    function symbol() public view override returns (string memory) {
        return symbol_;
    }

    function setSymbol(string memory symbol_) public onlyOwner {
        symbol_ = symbol_;
    }

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}