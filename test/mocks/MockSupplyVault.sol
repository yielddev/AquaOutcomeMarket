// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IEVault } from "euler-interfaces/IEVault.sol";

/// @notice Mock Supply Vault that implements IEVault for testing
contract MockSupplyVault is IEVault {
    ERC20 private _asset;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public assets;
    uint256 public totalShares;
    uint256 public totalAssets_;
    mapping(address => uint256) public debt;
    uint256 public totalDebt;
    address public evc;
    
    // Import MockEVC interface to get current account
    function getCurrentAccount() internal view returns (address) {
        if (evc == address(0)) return address(0);
        // Call MockEVC to get current onBehalfOfAccount
        (bool success, bytes memory result) = evc.staticcall(abi.encodeWithSignature("currentOnBehalfOfAccount()"));
        if (success && result.length == 32) {
            return abi.decode(result, (address));
        }
        return address(0);
    }

    constructor(address __asset) {
        _asset = ERC20(__asset);
    }

    function setEVC(address _evc) external {
        evc = _evc;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return shares[account];
    }

    function convertToAssets(uint256 sharesAmount) external view override returns (uint256) {
        if (totalShares == 0) return 0;
        return (sharesAmount * totalAssets_) / totalShares;
    }

    function convertToShares(uint256 assetsAmount) external view override returns (uint256) {
        if (totalAssets_ == 0) return assetsAmount;
        return (assetsAmount * totalShares) / totalAssets_;
    }

    function deposit(uint256 amount, address receiver) external override returns (uint256) {
        _asset.transferFrom(msg.sender, address(this), amount);
        uint256 sharesToMint = totalShares == 0 ? amount : (amount * totalShares) / totalAssets_;
        shares[receiver] += sharesToMint;
        assets[receiver] += amount;
        totalShares += sharesToMint;
        totalAssets_ += amount;
        return sharesToMint;
    }

    function withdraw(uint256 amount, address receiver, address owner) external override returns (uint256) {
        uint256 sharesToBurn = totalShares == 0 ? amount : (amount * totalShares) / totalAssets_;
        require(shares[owner] >= sharesToBurn, "Insufficient shares");
        shares[owner] -= sharesToBurn;
        assets[owner] -= amount;
        totalShares -= sharesToBurn;
        totalAssets_ -= amount;
        _asset.transfer(receiver, amount);
        return sharesToBurn;
    }

    function maxWithdraw(address owner) external view override returns (uint256) {
        return assets[owner];
    }

    // Stub implementations for other required functions
    function asset() external view override returns (address) {
        return address(_asset);
    }
    function borrow(uint256 amount, address receiver) external override returns (uint256) {
        require(msg.sender == address(evc), "Only EVC");
        require(totalAssets_ >= amount, "Insufficient liquidity");
        // In EVC, debt is tracked for the account (onBehalfOfAccount), not the receiver
        address account = getCurrentAccount();
        require(account != address(0), "No account in EVC context");
        debt[account] += amount;
        totalDebt += amount;
        totalAssets_ -= amount;
        _asset.transfer(receiver, amount);
        return amount;
    }
    function repay(uint256 amount, address receiver) external override returns (uint256) {
        require(msg.sender == address(evc), "Only EVC");
        address account = getCurrentAccount();
        require(account != address(0), "No account in EVC context");
        require(debt[account] >= amount, "Insufficient debt");
        _asset.transferFrom(msg.sender, address(this), amount);
        debt[account] -= amount;
        totalDebt -= amount;
        totalAssets_ += amount;
        return amount;
    }
    function debtOf(address account) external view override returns (uint256) {
        return debt[account];
    }
    function totalAssets() external view override returns (uint256) {
        return totalAssets_;
    }
    function totalBorrows() external view override returns (uint256) {
        return totalDebt;
    }
    function checkAccountStatus(address, address[] memory) external pure override returns (bytes4) {
        return bytes4(0);
    }
    function checkVaultStatus() external pure override returns (bytes4) {
        return bytes4(0);
    }
    function approve(address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }
    function transfer(address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }
    function transferFrom(address, address, uint256) external pure override returns (bool) {
        revert("Not implemented");
    }
    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }
    function totalSupply() external view override returns (uint256) {
        return totalShares;
    }
    function name() external pure override returns (string memory) {
        return "MockSupplyVault";
    }
    function symbol() external pure override returns (string memory) {
        return "MSV";
    }
    function decimals() external pure override returns (uint8) {
        return 18;
    }
    function mint(uint256, address) external pure override returns (uint256) {
        revert("Not implemented");
    }
    function redeem(uint256, address, address) external pure override returns (uint256) {
        revert("Not implemented");
    }
    function maxDeposit(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    function maxMint(address) external pure override returns (uint256) {
        return type(uint256).max;
    }
    function maxRedeem(address) external pure override returns (uint256) {
        return 0;
    }
    function previewDeposit(uint256) external pure override returns (uint256) {
        return 0;
    }
    function previewMint(uint256) external pure override returns (uint256) {
        return 0;
    }
    function previewRedeem(uint256) external pure override returns (uint256) {
        return 0;
    }
    function previewWithdraw(uint256) external pure override returns (uint256) {
        return 0;
    }
    function skim(uint256, address) external pure override returns (uint256) {
        revert("Not implemented");
    }
    function touch() external pure override {}
    function transferFromMax(address, address) external pure override returns (bool) {
        revert("Not implemented");
    }
    function disableController() external pure override {}
    function enableBalanceForwarder() external pure override {}
    function disableBalanceForwarder() external pure override {}
    function balanceForwarderEnabled(address) external pure override returns (bool) {
        return false;
    }
    function flashLoan(uint256, bytes memory) external pure override {
        revert("Not implemented");
    }
    function liquidate(address, address, uint256, uint256) external pure override {
        revert("Not implemented");
    }
    function pullDebt(uint256, address) external pure override {
        revert("Not implemented");
    }
    function repayWithShares(uint256, address) external pure override returns (uint256, uint256) {
        revert("Not implemented");
    }
    function checkLiquidation(address, address, address) external pure override returns (uint256, uint256) {
        revert("Not implemented");
    }
    function viewDelegate() external payable override {}
    function accumulatedFees() external pure override returns (uint256) {
        return 0;
    }
    function accumulatedFeesAssets() external pure override returns (uint256) {
        return 0;
    }
    function balanceTrackerAddress() external pure override returns (address) {
        return address(0);
    }
    function caps() external pure override returns (uint16, uint16) {
        return (0, 0);
    }
    function cash() external view override returns (uint256) {
        return totalAssets_;
    }
    function configFlags() external pure override returns (uint32) {
        return 0;
    }
    function convertFees() external pure override {}
    function creator() external pure override returns (address) {
        return address(0);
    }
    function dToken() external pure override returns (address) {
        return address(0);
    }
    function debtOfExact(address) external pure override returns (uint256) {
        return 0;
    }
    function feeReceiver() external pure override returns (address) {
        return address(0);
    }
    function governorAdmin() external pure override returns (address) {
        return address(0);
    }
    function hookConfig() external pure override returns (address, uint32) {
        return (address(0), 0);
    }
    function initialize(address) external pure override {
        revert("Already initialized");
    }
    function interestAccumulator() external pure override returns (uint256) {
        return 1e18;
    }
    function interestFee() external pure override returns (uint16) {
        return 0;
    }
    function interestRate() external pure override returns (uint256) {
        return 0;
    }
    function interestRateModel() external pure override returns (address) {
        return address(0);
    }
    function liquidationCoolOffTime() external pure override returns (uint16) {
        return 0;
    }
    function maxLiquidationDiscount() external pure override returns (uint16) {
        return 0;
    }
    function oracle() external pure override returns (address) {
        return address(0);
    }
    function permit2Address() external pure override returns (address) {
        return address(0);
    }
    function protocolConfigAddress() external pure override returns (address) {
        return address(0);
    }
    function protocolFeeReceiver() external pure override returns (address) {
        return address(0);
    }
    function protocolFeeShare() external pure override returns (uint256) {
        return 0;
    }
    function setCaps(uint16, uint16) external pure override {
        revert("Not implemented");
    }
    function setConfigFlags(uint32) external pure override {
        revert("Not implemented");
    }
    function setFeeReceiver(address) external pure override {
        revert("Not implemented");
    }
    function setGovernorAdmin(address) external pure override {
        revert("Not implemented");
    }
    function setHookConfig(address, uint32) external pure override {
        revert("Not implemented");
    }
    function setInterestFee(uint16) external pure override {
        revert("Not implemented");
    }
    function setInterestRateModel(address) external pure override {
        revert("Not implemented");
    }
    function setLTV(address, uint16, uint16, uint32) external pure override {
        revert("Not implemented");
    }
    function setLiquidationCoolOffTime(uint16) external pure override {
        revert("Not implemented");
    }
    function setMaxLiquidationDiscount(uint16) external pure override {
        revert("Not implemented");
    }
    function totalBorrowsExact() external view override returns (uint256) {
        return totalDebt;
    }
    function unitOfAccount() external pure override returns (address) {
        return address(0);
    }
    function EVC() external view override returns (address) {
        return evc;
    }
    function LTVBorrow(address) external pure override returns (uint16) {
        return 0;
    }
    function LTVFull(address) external pure override returns (uint16, uint16, uint16, uint48, uint32) {
        return (0, 0, 0, 0, 0);
    }
    function LTVLiquidation(address) external pure override returns (uint16) {
        return 0;
    }
    function LTVList() external pure override returns (address[] memory) {
        return new address[](0);
    }
    function MODULE_BALANCE_FORWARDER() external pure override returns (address) {
        return address(0);
    }
    function MODULE_BORROWING() external pure override returns (address) {
        return address(0);
    }
    function MODULE_GOVERNANCE() external pure override returns (address) {
        return address(0);
    }
    function MODULE_INITIALIZE() external pure override returns (address) {
        return address(0);
    }
    function MODULE_LIQUIDATION() external pure override returns (address) {
        return address(0);
    }
    function MODULE_RISKMANAGER() external pure override returns (address) {
        return address(0);
    }
    function MODULE_TOKEN() external pure override returns (address) {
        return address(0);
    }
    function MODULE_VAULT() external pure override returns (address) {
        return address(0);
    }
    function accountLiquidity(address, bool) external pure override returns (uint256, uint256) {
        return (0, 0);
    }
    function accountLiquidityFull(address, bool) external pure override returns (address[] memory, uint256[] memory, uint256) {
        return (new address[](0), new uint256[](0), 0);
    }
}

