pragma solidity 0.8.30;

interface IPredictionToken {
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function symbol() external view returns (string memory);
    function setSymbol(string memory symbol) external;
}