pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PredictionToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPredictionToken.sol";

contract PredictionMarket is Ownable{

    address public yes;
    address public no;
    address public collateral;
    address public underlying;
    address public winner;


    constructor(
        address collateral_,
        address underlying_,
        string memory name_
    ) Ownable(msg.sender) {
        address side1 = address(new PredictionToken(name_));
        address side2 = address(new PredictionToken(name_));
        // no is always less
        no = side1 < side2 ? side1 : side2;
        yes = no == side1 ? side2 : side1;
        IPredictionToken(no).setSymbol("No");
        IPredictionToken(yes).setSymbol("Yes");
        collateral = collateral_;
        underlying = underlying_;
    }

    function setWinner(bool isYes) public onlyOwner {
        winner = isYes ? yes : no;
    }

    function mint(address receiver, uint256 amount) public {
        // require(
        //     USD.transferFrom(account, address(this), amount),
        //     "Payment Reverted"
        // );  
        
        IERC20(collateral).transferFrom(_msgSender(), address(this), amount);
        IPredictionToken(no).mint(receiver, amount);
        IPredictionToken(yes).mint(receiver, amount);
    }

    function redeem(address account, uint256 amount) public {
        // require(
        //     winner.transferFrom(account, address(this), amount),
        //     "Redemtion Reverted"
        // );
        // USD.transfer(account, amount);
        // withdraw from 
        IERC20(winner).transferFrom(account, address(this), amount);
        IPredictionToken(no).burn(address(this), amount);
        // withdraw collateral in amount to account as receiver
    }
}