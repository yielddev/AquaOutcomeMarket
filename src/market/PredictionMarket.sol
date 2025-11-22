// pragma solidity 0.8.30;

// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import "./PredictionToken.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";

// contract Prediction is Ownable{

//     address public yes;
//     address public no;
//     address public collateral;
//     address public underlying;
//     address public winner;


//     constructor(
//         address collateral_,
//         address underlying_,
//         string memory name_
//     ) {
//         address side1 = address(new PredictionToken(name_));
//         address side2 = address(new PredictionToken(name_));
//         // no is always less
//         no = side1 < side2 ? side1 : side2;
//         yes = no == side1 ? side2 : side1;
//         no.setSymbol("No");
//         yes.setSymbol("Yes");
//         collateral = collateral_;
//         underlying = underlying_;
//     }

//     function setWinner(bool winningSide) public onlyOwner {
//         if (winningSide) {
//             winner = side1;
//         } else {
//             winner = side2;
//         }

//     }

//     function mint(address account, address receiver, uint256 amount) public {
//         require(
//             USD.transferFrom(account, address(this), amount),
//             "Payment Reverted"
//         );  
//         IERC20(collateral).transferFrom(account, address(this), amount);
//         IPredictionToken(no).mint(receiver, amount);
//         IPredictionToken(yes).mint(receiver, amount);
//     }

//     function redeem(address account, uint256 amount) public {
//         // require(
//         //     winner.transferFrom(account, address(this), amount),
//         //     "Redemtion Reverted"
//         // );
//         // USD.transfer(account, amount);
//     }
// }