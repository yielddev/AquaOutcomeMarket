// SPDX-License-Identifier: LicenseRef-Degensoft-SwapVM-1.1
pragma solidity 0.8.30;

import { IEthereumVaultConnector, IEVC } from "euler-interfaces/IEthereumVaultConnector.sol";

/// @notice Mock EVC that implements basic functionality for testing
contract MockEVC is IEthereumVaultConnector {
    mapping(address => mapping(address => bool)) public controllers;
    mapping(address => mapping(address => bool)) public collaterals;
    
    // Store current onBehalfOfAccount for vaults to query
    address public currentOnBehalfOfAccount;

    function call(address targetContract, address onBehalfOfAccount, uint256 value, bytes memory data)
        external
        payable
        override
        returns (bytes memory result)
    {
        address previousAccount = currentOnBehalfOfAccount;
        currentOnBehalfOfAccount = onBehalfOfAccount;
        (bool success, bytes memory returndata) = targetContract.call{value: value}(data);
        currentOnBehalfOfAccount = previousAccount;
        require(success, "EVC call failed");
        return returndata;
    }

    function enableController(address account, address vault) external payable override {
        controllers[account][vault] = true;
    }

    function disableController(address account) external payable override {
        // Clear all controllers for account
    }

    function enableCollateral(address account, address vault) external payable override {
        collaterals[account][vault] = true;
    }

    function disableCollateral(address account, address vault) external payable override {
        collaterals[account][vault] = false;
    }

    function isControllerEnabled(address account, address vault) external view override returns (bool) {
        return controllers[account][vault];
    }

    function isCollateralEnabled(address account, address vault) external view override returns (bool) {
        return collaterals[account][vault];
    }

    function getCurrentOnBehalfOfAccount(address controllerToCheck)
        external
        view
        override
        returns (address onBehalfOfAccount, bool controllerEnabled)
    {
        return (msg.sender, controllers[msg.sender][controllerToCheck]);
    }

    function getAccountOwner(address account) external pure override returns (address) {
        return account;
    }

    function getAddressPrefix(address account) external pure override returns (bytes19) {
        return bytes19(uint152(uint160(account) >> 8));
    }

    function haveCommonOwner(address account, address otherAccount) external pure override returns (bool) {
        return (uint160(account) >> 8) == (uint160(otherAccount) >> 8);
    }

    function isAccountOperatorAuthorized(address account, address operator) external pure override returns (bool) {
        return false;
    }

    function getOperator(bytes19 addressPrefix, address operator) external pure override returns (uint256) {
        return 0;
    }

    function getRawExecutionContext() external pure override returns (uint256) {
        return 0;
    }

    function areChecksDeferred() external pure override returns (bool) {
        return false;
    }

    function areChecksInProgress() external pure override returns (bool) {
        return false;
    }

    function isAccountStatusCheckDeferred(address account) external pure override returns (bool) {
        return false;
    }

    function isVaultStatusCheckDeferred(address vault) external pure override returns (bool) {
        return false;
    }

    function isControlCollateralInProgress() external pure override returns (bool) {
        return false;
    }

    function isSimulationInProgress() external pure override returns (bool) {
        return false;
    }

    function isOperatorAuthenticated() external pure override returns (bool) {
        return false;
    }

    function isLockdownMode(bytes19 addressPrefix) external pure override returns (bool) {
        return false;
    }

    function isPermitDisabledMode(bytes19 addressPrefix) external pure override returns (bool) {
        return false;
    }

    function getCollaterals(address account) external pure override returns (address[] memory) {
        return new address[](0);
    }

    function getControllers(address account) external pure override returns (address[] memory) {
        return new address[](0);
    }

    function getLastAccountStatusCheckTimestamp(address account) external pure override returns (uint256) {
        return 0;
    }

    function getNonce(bytes19 addressPrefix, uint256 nonceNamespace) external pure override returns (uint256) {
        return 0;
    }

    function name() external pure override returns (string memory) {
        return "MockEVC";
    }

    // Stub implementations for other required functions
    function batch(IEVC.BatchItem[] memory) external payable override {}
    function batchRevert(IEVC.BatchItem[] memory) external payable override {}
    function batchSimulation(IEVC.BatchItem[] memory)
        external
        payable
        override
        returns (
            IEVC.BatchItemResult[] memory,
            IEVC.StatusCheckResult[] memory,
            IEVC.StatusCheckResult[] memory
        )
    {
        revert("Not implemented");
    }
    function controlCollateral(address, address, uint256, bytes memory) external payable override returns (bytes memory) {
        revert("Not implemented");
    }
    function forgiveAccountStatusCheck(address) external payable override {}
    function forgiveVaultStatusCheck() external payable override {}
    function permit(address, address, uint256, uint256, uint256, uint256, bytes memory, bytes memory) external payable override {}
    function reorderCollaterals(address, uint8, uint8) external payable override {}
    function requireAccountAndVaultStatusCheck(address) external payable override {}
    function requireAccountStatusCheck(address) external payable override {}
    function requireVaultStatusCheck() external payable override {}
    function setAccountOperator(address, address, bool) external payable override {}
    function setLockdownMode(bytes19, bool) external payable override {}
    function setNonce(bytes19, uint256, uint256) external payable override {}
    function setOperator(bytes19, address, uint256) external payable override {}
    function setPermitDisabledMode(bytes19, bool) external payable override {}

    receive() external payable {}
}

