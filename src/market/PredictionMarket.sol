pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PredictionToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPredictionToken.sol";

contract PredictionMarket is Ownable{
    error PredictionMarketWinnerNotSet();
    error PredictionMarketWinnerAlreadySet();
    error PredictionMarketWinnerSet();

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
        require(isYes ? yes != address(0) : no != address(0), PredictionMarketWinnerNotSet());
        require(winner == address(0), PredictionMarketWinnerAlreadySet());
        winner = isYes ? yes : no;
    }

    function mint(address receiver, uint256 amount) public {
        
        IERC20(collateral).transferFrom(_msgSender(), address(this), amount);

        IPredictionToken(no).mint(receiver, amount);
        IPredictionToken(yes).mint(receiver, amount);
    }

    function redeem(address account, uint256 amount) public {
        require(winner != address(0), PredictionMarketWinnerNotSet());
        IERC20(winner).transferFrom(_msgSender(), address(this), amount);
        IPredictionToken(no).burn(address(this), amount);
        IERC20(collateral).transfer(account, amount);
        // withdraw collateral in amount to account as receiver
    }

    function unmint(address receiver, uint256 amount) public {
        require(winner == address(0), PredictionMarketWinnerSet());
        IERC20(no).transferFrom(_msgSender(), address(this), amount);
        IERC20(yes).transferFrom(_msgSender(), address(this), amount);
        IPredictionToken(no).burn(address(this), amount);
        IPredictionToken(yes).burn(address(this), amount);
        IERC20(collateral).transfer(receiver, amount);

    }
}