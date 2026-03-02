// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2023 Kiln <contact@kiln.fi>
//
// ██╗  ██╗██╗██╗     ███╗   ██╗
// ██║ ██╔╝██║██║     ████╗  ██║
// █████╔╝ ██║██║     ██╔██╗ ██║
// ██╔═██╗ ██║██║     ██║╚██╗██║
// ██║  ██╗██║███████╗██║ ╚████║
// ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═══╝
//
pragma solidity 0.8.17;

/// @title Global Oracle Holder Interface
/// @author mortimr @ Kiln
/// @notice Contract holding and exposing a global oracle address.
///         The global oracle member is allowed to vote on all the vOracleAggregators.
///         To prevent the global oracle member from voting, you can set the global oracle
///         member ejection status to true AND have 5+ oracle members in the vOracleAggregator.
interface IGlobalOracleHolder {
    /// @notice Emitted when the global oracle has been changed
    /// @param globalOracle The new global oracle address
    event SetGlobalOracle(address globalOracle);

    /// @notice Retrieve the global oracle address
    /// @return The global oracle address
    function globalOracle() external view returns (address);

    /// @notice Set the global oracle value
    /// @param newGlobalOracle The new address for the global oracle
    function setGlobalOracle(address newGlobalOracle) external;
}
