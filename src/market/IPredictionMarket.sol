pragma solidity 0.8.30;

interface IPredictionMarket {
    function mint(address receiver, uint256 amount) external;
    function redeem(address account, uint256 amount) external;
    function no() external view returns (address);
    function yes() external view returns (address);
    function collateral() external view returns (address);
    function underlying() external view returns (address);
    function winner() external view returns (address);
}