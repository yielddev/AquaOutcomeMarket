pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { PredictionMarket } from "../src/market/PredictionMarket.sol";
import { PredictionToken } from "../src/market/PredictionToken.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockCollateral is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PredictionMarketTest is Test {
    address public user = makeAddr("user");
    PredictionMarket public predictionMarket;
    PredictionToken public no;
    PredictionToken public yes;
    MockToken public underlying;
    MockCollateral public collateral;

    function setUp() public {
        collateral = new MockCollateral("Collateral", "COL");
        underlying = new MockToken("Underlying", "UND");
        predictionMarket = new PredictionMarket(address(collateral), address(underlying), "Prediction Market");
        no = PredictionToken(predictionMarket.no());
        yes = PredictionToken(predictionMarket.yes());
        vm.label(address(predictionMarket), "predictionMarket");
        vm.label(address(collateral), "collateral");
        vm.label(address(underlying), "underlying");
        vm.label(address(no), "no");
        vm.label(address(yes), "yes");
        vm.label(address(user), "user");
    }

    function test_mint() public {
        vm.prank(user);
        collateral.mint(user, 1000e6);
        vm.prank(user);
        collateral.approve(address(predictionMarket), 1000e6);
        vm.prank(user);
        predictionMarket.mint(user, 1000e6);

        assertEq(collateral.balanceOf(address(predictionMarket)), 1000e6);
        assertEq(no.balanceOf(user), 1000e6);
        assertEq(yes.balanceOf(user), 1000e6);
    }

    function test_winner_can_redeem() public {
        vm.prank(user);
        collateral.mint(user, 1000e6);

        vm.prank(user);
        collateral.approve(address(predictionMarket), 1000e6);

        vm.prank(user);
        predictionMarket.mint(user, 1000e6);


        predictionMarket.setWinner(false);

        vm.prank(user);
        yes.transfer(address(1), 1000e6);

        vm.prank(user);
        no.approve(address(predictionMarket), 1000e6);

        vm.prank(user);
        predictionMarket.redeem(user, 1000e6);

        assertEq(collateral.balanceOf(user), 1000e6);
        assertEq(no.balanceOf(address(predictionMarket)), 0);
        assertEq(yes.balanceOf(address(predictionMarket)), 0);
    }

    function test_unmint() public {
        vm.prank(user);
        collateral.mint(user, 1000e6);

        vm.prank(user);
        collateral.approve(address(predictionMarket), 1000e6);

        vm.prank(user);
        predictionMarket.mint(user, 1000e6);

        vm.startPrank(user);

        no.approve(address(predictionMarket), 500e6);
        yes.approve(address(predictionMarket), 500e6);

        predictionMarket.unmint(user, 500e6);

        vm.stopPrank();

        assertEq(collateral.balanceOf(user), 500e6);

        assertEq(no.balanceOf(address(user)), 500e6);
        assertEq(yes.balanceOf(address(user)), 500e6);

        assertEq(no.totalSupply(), 500e6);
        assertEq(yes.totalSupply(), 500e6);

        
    }

    function test_malicious_mint() public {
        // vm.prank(user);
        // collateral.mint(user, 1000e18);
        // vm.prank(user);
        // collateral.approve(address(predictionMarket), 1000e18);
        
        // vm.prank(makeAddr("malicious"));
        // vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, makeAddr("malicious")));
        // predictionMarket.mint(user, 1000e18);

        // vm.prank(user);
        // collateral.approve(makeAddr("malicious"), 1000e18);

        // vm.prank(makeAddr("malicious"));
        // predictionMarket.mint(user, 1000e18);

        // assertEq(collateral.balanceOf(address(predictionMarket)), 1000e18);
        // assertEq(no.balanceOf(user), 1000e18);
        // assertEq(yes.balanceOf(user), 1000e18); 
    }
}