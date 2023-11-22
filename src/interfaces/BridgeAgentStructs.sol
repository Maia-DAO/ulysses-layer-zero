// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*///////////////////////////////////////////////////////////////
                            STRUCTS
//////////////////////////////////////////////////////////////*/

/// @notice Struct for storing the gas parameters for a cross-chain call.
/// @param gasLimit gas units allocated for a cross-chain call execution.
/// @param remoteBranchExecutionGas native token amount to request for destiantion branch usage.
struct GasParams {
    uint256 gasLimit;
    uint256 remoteBranchExecutionGas;
}

/// @notice Struct for storing information about a deposit in a Branch Bridge Agent's state.
/// @param status status of the deposit. Has 3 states - ready, done, retrieve.
/// @param isSigned indicates if the deposit has been signed allowing Virtual Account usage.
/// @param owner owner of the deposit.
/// @param hTokens array of local hTokens addresses.
/// @param tokens array of underlying token addresses.
/// @param amounts array of total deposited amounts.
/// @param deposits array of underlying token deposited amounts.
struct Deposit {
    uint8 status;
    uint88 isSigned;
    address owner;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

/// @notice Struct for inputting deposit information into a Branch Bridge Agent.
/// @param hToken local hToken address.
/// @param token underlying token address.
/// @param amount total amount to deposit.
/// @param deposit underlying token amount to deposit.
struct DepositInput {
    address hToken;
    address token;
    uint256 amount;
    uint256 deposit;
}

/// @notice Struct for inputting multiple asset deposit information into a Branch Bridge Agent.
/// @param hTokens array of local hTokens addresses.
/// @param tokens array of underlying token addresses.
/// @param amounts array of total amounts to deposit.
/// @param deposits array of underlying token amounts to deposit.
struct DepositMultipleInput {
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

/// @notice Struct for encoding deposit information in a cross-chain message.
/// @param depositNonce deposit nonce.
/// @param hToken local hToken address.
/// @param token underlying token address.
/// @param amount total amount to deposit.
/// @param deposit underlying token amount to deposit.
struct DepositParams {
    uint32 depositNonce;
    address hToken;
    address token;
    uint256 amount;
    uint256 deposit;
}

/// @notice Struct for encoding multiple asset deposit information in a cross-chain message.
/// @param numberOfAssets number of assets to deposit.
/// @param depositNonce deposit nonce.
/// @param hTokens array of local hTokens addresses.
/// @param tokens array of underlying token addresses.
/// @param amounts array of total amounts to deposit.
/// @param deposits array of underlying token amounts to deposit.
struct DepositMultipleParams {
    uint8 numberOfAssets;
    uint32 depositNonce;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

/// @notice Struct for storing information about a settlement in a Root Bridge Agent's state.
/// @param dstChainId destination chain for interaction.
/// @param status status of the settlement.
/// @param owner owner of the settlement.
/// @param recipient recipient of the settlement.
/// @param hTokens array of global hTokens addresses.
/// @param tokens array of underlying token addresses.
/// @param amounts array of total settled amounts.
/// @param deposits array of underlying token settled amounts.
struct Settlement {
    uint16 dstChainId;
    uint80 status;
    address owner;
    address recipient;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}

/// @notice Struct for inputting token settlement information into a Root Bridge Agent.
/// @param globalAddress global hToken address.
/// @param amount total amount to settle.
/// @param deposit underlying token amount to settle.
struct SettlementInput {
    address globalAddress;
    uint256 amount;
    uint256 deposit;
}

/// @notice Struct for inputting multiple asset settlement information into a Root Bridge Agent.
/// @param globalAddresses array of global hTokens addresses.
/// @param amounts array of total amounts to settle.
/// @param deposits array of underlying token amounts to settle.

struct SettlementMultipleInput {
    address[] globalAddresses;
    uint256[] amounts;
    uint256[] deposits;
}

/// @notice Struct for encoding settlement information in a cross-chain message.
/// @param settlementNonce settlement nonce.
/// @param recipient recipient of the settlement.
/// @param hToken destination local hToken address.
/// @param token destination underlying token address.
/// @param amount total amount to settle.
/// @param deposit underlying token amount to settle.
struct SettlementParams {
    uint32 settlementNonce;
    address recipient;
    address hToken;
    address token;
    uint256 amount;
    uint256 deposit;
}

/// @notice Struct for encoding multiple asset settlement information in a cross-chain message.
/// @param numberOfAssets number of assets to settle.
/// @param recipient recipient of the settlement.
/// @param settlementNonce settlement nonce.
/// @param hTokens array of destination local hTokens addresses.
/// @param tokens array of destination underlying token addresses.
/// @param amounts array of total amounts to settle.
/// @param deposits array of underlying token amounts to settle.
struct SettlementMultipleParams {
    uint8 numberOfAssets;
    address recipient;
    uint32 settlementNonce;
    address[] hTokens;
    address[] tokens;
    uint256[] amounts;
    uint256[] deposits;
}
