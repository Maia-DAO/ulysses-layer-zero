// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    GasParams,
    Deposit,
    DepositInput,
    DepositMultipleInput,
    DepositParams,
    DepositMultipleParams,
    SettlementParams,
    SettlementMultipleParams
} from "./BridgeAgentStructs.sol";
import {ILayerZeroReceiver} from "./ILayerZeroReceiver.sol";

/**
 * @title  Branch Bridge Agent Contract
 * @author MaiaDAO
 * @notice Contract for deployment in Branch Chains of Omnichain System, responsible for interfacing with
 *         Users and Routers acting as a middleman to access LayerZero cross-chain messaging and requesting/depositing
 *         assets in the Branch Chain's Ports.
 * @dev    Bridge Agents allow for the encapsulation of business logic as well as standardize cross-chain communication,
 *         allowing for the creation of custom Routers to perform actions in response to local / remote user requests.
 *         This contract is designed for deployment in the Branch Chains of the Ulysses Omnichain Liquidity System.
 *         The Branch Bridge Agent is responsible for sending/receiving requests to/from the LayerZero Messaging Layer
 *         for execution, as well as requests tokens clearances and tx execution to the `BranchBridgeAgentExecutor`.
 *         Remote execution is "sandboxed" within 2 different layers/nestings:
 *         - 1: Upon receiving a request from LayerZero Messaging Layer to avoid blocking future requests due to
 *              execution reversion, ensuring our app is Non-Blocking.
 *              (See https://github.com/LayerZero-Labs/solidity-examples/blob/8e62ebc886407aafc89dbd2a778e61b7c0a25ca0/contracts/lzApp/NonblockingLzApp.sol)
 *         - 2: The call to `BranchBridgeAgentExecutor` is in charge of requesting token deposits for each remote
 *              interaction as well as performing the Router calls, if any of the calls initiated by the Router lead
 *              to an invalid state change both the token deposit clearances as well as the external interactions
 *              will be reverted and caught by the `BranchBridgeAgent`.
 *
 *         **BRANCH BRIDGE AGENT SETTLEMENT FLAGs** Func IDs for calling these functions through the messaging layer
 *
 *         | ID   | DESCRIPTION                                                                                       |
 *         | ---- | ------------------------------------------------------------------------------------------------- |
 *         | 0x01 | Call to Branch without Settlement.                                                                |
 *         | 0x02 | Call to Branch with Settlement.                                                                   |
 *         | 0x03 | Call to Branch with Settlement of Multiple Tokens.                                                |
 *         | 0x04 | Call to `retrieveSettlement()`. (trigger `_fallback` for a settlement that has not been executed) |
 *         | 0x05 | Call to `_fallback()`. (reopens a deposit for asset redemption)                                   |
 *
 *         Encoding Scheme for different Root Bridge Agent Deposit Flags:
 *
 *           - ht = hToken
 *           - t = Token
 *           - A = Amount
 *           - D = Deposit
 *           - b = bytes
 *           - n = number of assets
 *
 *         | Flag   | Deposit Info                | Token Info              | DATA |
 *         | ------ | --------------------------- | ----------------------- | ---- |
 *         | 1 byte | 4-25 bytes                  | 104 or (128 * n) bytes  |      |
 *         |        |                             | hT - t - A - D          | ...  |
 *         | 0x1    | 20b(recipient) + 4b(nonce)  |          ---            | ...  |
 *         | 0x2    | 20b(recipient) + 4b(nonce)  | 20b + 20b + 32b + 32b   | ...  |
 *         | 0x3    | 1b(n) + 20b(recipient) + 4b | 32b + 32b + 32b + 32b   | ...  |
 *
 *         **Generic Contract Interaction Flow:**
 *         BridgeAgent.lzReceive() -> BridgeAgentExecutor.execute() -> Router.execute()
 *
 */
interface IBranchBridgeAgent is ILayerZeroReceiver {
    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice External function to return the Branch Chain's Local Port Address.
     * @return address of the Branch Chain's Local Port.
     */
    function localPortAddress() external view returns (address);

    /**
     * @notice External function to return the Branch Bridge Agent Executor Address.
     * @return address of the Branch Bridge Agent Executor.
     */
    function bridgeAgentExecutorAddress() external view returns (address);

    /**
     * @notice External function that returns a given deposit entry.
     *  @param depositNonce Identifier for user deposit.
     */
    function getDepositEntry(uint32 depositNonce) external view returns (Deposit memory);

    /*///////////////////////////////////////////////////////////////
                    USER AND BRANCH ROUTER FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to perform a call to the Root Omnichain Router without token deposit.
     *  @param gasRefundee Address to return excess gas deposited in `msg.value` to.
     *  @param params enconded parameters to execute on the root chain router.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @dev DEPOSIT ID: 1 (Call without deposit)
     */
    function callOut(address payable gasRefundee, bytes calldata params, GasParams calldata gasParams)
        external
        payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset.
     *  @param depositOwnerAndGasRefundee Deposit owner and address to return excess gas deposited in `msg.value` to.
     *  @param params enconded parameters to execute on the root chain router.
     *  @param depositParams additional token deposit parameters.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @dev DEPOSIT ID: 2 (Call with single deposit)
     */
    function callOutAndBridge(
        address payable depositOwnerAndGasRefundee,
        bytes calldata params,
        DepositInput memory depositParams,
        GasParams calldata gasParams
    ) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing two or more assets.
     *  @param depositOwnerAndGasRefundee Deposit owner and address to return excess gas deposited in `msg.value` to.
     *  @param params enconded parameters to execute on the root chain router.
     *  @param depositParams additional token deposit parameters.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @dev DEPOSIT ID: 3 (Call with multiple deposit)
     */
    function callOutAndBridgeMultiple(
        address payable depositOwnerAndGasRefundee,
        bytes calldata params,
        DepositMultipleInput memory depositParams,
        GasParams calldata gasParams
    ) external payable;

    /**
     * @notice Perform a call to the Root Omnichain Router without token deposit with msg.sender information.
     *  @dev msg.sender is gasRefundee in signed calls.
     *  @param params enconded parameters to execute on the root chain router.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @dev DEPOSIT ID: 4 (Call without deposit and verified sender)
     */
    function callOutSigned(bytes calldata params, GasParams calldata gasParams) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while depositing a single asset msg.sender.
     *  @dev msg.sender is depositOwnerAndGasRefundee in signed calls.
     *  @param params enconded parameters to execute on the root chain router.
     *  @param depositParams additional token deposit parameters.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @param hasFallbackToggled flag to indicate if the fallback function was toggled.
     *  @dev DEPOSIT ID: 5 (Call with single deposit and verified sender)
     */
    function callOutSignedAndBridge(
        bytes calldata params,
        DepositInput memory depositParams,
        GasParams calldata gasParams,
        bool hasFallbackToggled
    ) external payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Router while
     *         depositing two or more assets with msg.sender.
     *  @dev msg.sender is depositOwnerAndGasRefundee in signed calls.
     *  @param params enconded parameters to execute on the root chain router.
     *  @param depositParams additional token deposit parameters.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @param hasFallbackToggled flag to indicate if the fallback function was toggled.
     *  @dev DEPOSIT ID: 6 (Call with multiple deposit and verified sender)
     */
    function callOutSignedAndBridgeMultiple(
        bytes calldata params,
        DepositMultipleInput memory depositParams,
        GasParams calldata gasParams,
        bool hasFallbackToggled
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                    DEPOSIT EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to perform a call to the Root Omnichain Environment
     *         retrying a failed non-signed deposit that hasn't been executed yet.
     *  @param owner address of the deposit owner.
     *  @param depositNonce Identifier for user deposit.
     *  @param params parameters to execute on the root chain router.
     *  @param gasParams gas parameters for the cross-chain call.
     */
    function retryDeposit(address owner, uint32 depositNonce, bytes calldata params, GasParams calldata gasParams)
        external
        payable;

    /**
     * @notice Function to perform a call to the Root Omnichain Environment
     *         retrying a failed signed deposit that hasn't been executed yet.
     *  @param depositNonce Identifier for user deposit.
     *  @param params parameters to execute on the root chain router.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @param hasFallbackToggled flag to indicate if the fallback function was toggled.
     */
    function retryDepositSigned(
        uint32 depositNonce,
        bytes calldata params,
        GasParams calldata gasParams,
        bool hasFallbackToggled
    ) external payable;

    /**
     * @notice External function to request tokens back to branch chain after failing omnichain environment interaction.
     *  @param depositNonce Identifier for user deposit to retrieve.
     *  @param gasParams gas parameters for the cross-chain call.
     *  @dev DEPOSIT ID: 8
     */
    function retrieveDeposit(uint32 depositNonce, GasParams calldata gasParams) external payable;

    /**
     * @notice External function to retry a failed Deposit entry on this branch chain.
     *  @param depositNonce Identifier for user deposit.
     *  @param recipient address to receive the redeemed tokens.
     */
    function redeemDeposit(uint32 depositNonce, address recipient) external;

    /**
     * @notice External function to retry a failed Deposit entry on this branch chain.
     *  @param depositNonce Identifier for user deposit.
     *  @param recipient address to receive the redeemed tokens.
     *  @param localTokenAddress address of the local token to redeem.
     */
    function redeemDeposit(uint32 depositNonce, address recipient, address localTokenAddress) external;

    /*///////////////////////////////////////////////////////////////
                    SETTLEMENT EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice External function to retry a failed Settlement entry on the root chain.
     *  @param settlementNonce Identifier for user settlement.
     *  @param params parameters to execute on the root chain router.
     *  @param gasParams gas parameters for the cross-chain call to root chain and for the settlement to branch.
     *  @param hasFallbackToggled flag to indicate if the fallback function should be toggled.
     *  @dev DEPOSIT ID: 7
     */
    function retrySettlement(
        uint32 settlementNonce,
        bytes calldata params,
        GasParams[2] calldata gasParams,
        bool hasFallbackToggled
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to request balance clearance from a Port to a given user.
     *  @param recipient token receiver.
     *  @param hToken  local hToken addresse to clear balance for.
     *  @param token  native / underlying token addresse to clear balance for.
     *  @param amount amounts of token to clear balance for.
     *  @param deposit amount of native / underlying tokens to clear balance for.
     */
    function bridgeIn(address recipient, address hToken, address token, uint256 amount, uint256 deposit) external;

    /**
     * @notice Function to request balance clearance from a Port to a given address.
     *  @param recipient token receiver.
     *  @param sParams encode packed multiple settlement info.
     */
    function bridgeInMultiple(address recipient, SettlementMultipleParams calldata sParams) external;

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when a deposit is successfully and fully redeemed.
    /// @param depositNonce Identifier for user deposit.
    /// @param recipient address to receive the redeemed tokens.
    event RedeemDeposit(uint256 indexed depositNonce, address indexed recipient);

    /// @notice Event emitted when a single token is redeemed from a deposit and there are other tokens left to redeem.
    /// @param depositNonce Identifier for user deposit.
    /// @param recipient address to receive the redeemed tokens.
    /// @param localTokenAddress address of the local token to redeem.
    event RedeemDeposit(uint256 indexed depositNonce, address indexed recipient, address indexed localTokenAddress);

    /// @notice Event emitted when a settlement nonce is executed successfully.
    /// @param nonce Identifier for user settlement.
    event LogExecute(uint256 indexed nonce);

    /// @notice Event emitted when fallback is received for a failed deposit nonce.
    /// @param nonce Identifier for user deposit.
    event LogFallback(uint256 indexed nonce);

    /// @notice Event emitted after a message is sent to the Layer Zero Endpoint.
    /// @param gasLimit gas limit for the cross-chain call.
    /// @param remoteBranchExecutionGas native gas tokens to be sent to the remote branch.
    event LogGasParams(uint256 indexed gasLimit, uint256 indexed remoteBranchExecutionGas);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when the provided Root Bridge Agent Address is invalid.
    error InvalidRootBridgeAgentAddress();
    /// @notice Error emitted when the provided Branch Port Address is invalid.
    error InvalidBranchPortAddress();
    /// @notice Error emitted when the provided Layer Zero Endpoint Address is invalid.
    error InvalidEndpointAddress();

    /// @notice Error emitted when the Branch Bridge Agent does not recognize the action flag.
    error UnknownFlag();
    /// @notice Error emitted when a settlement nonce fails to execute and does not have fallback enabled.
    error ExecutionFailure();

    /// @notice Error emitted when a Layer Zero remote caller in not recognized as the Root Bridge Agent.
    error LayerZeroUnauthorizedCaller();
    /// @notice Error emitted when the caller is not the local Layer Zero Endpoint contract.
    error LayerZeroUnauthorizedEndpoint();

    /// @notice Error emitted when the settlement nonce has already been executed.
    error AlreadyExecutedTransaction();

    /// @notice Error emitted when the local hToken address is zero.
    error InvalidLocalAddress();
    /// @notice Error emitted when the deposit information is not valid.
    error InvalidInput();

    /// @notice Error emitted when the the wrong retryDeposit function for a deposit type (Signed or Unsigned).
    error WrongDepositType();
    /// @notice Error emitted when caller is not the deposit owner.
    error NotDepositOwner();
    /// @notice Error emitted when the action of deposit nonce is not retryabable.
    error DepositRetryUnavailableUseCallout();
    /// @notice Error emitted when the deposit nonce is not in a redeemable state.
    error DepositRedeemUnavailable();
    /// @notice Error emitted when the deposit nonce is not in a retryable state.
    error DepositAlreadyRetrieved();

    /// @notice Error emitted when the caller is not the Branch Bridge Agent's Router
    error UnrecognizedRouter();
    /// @notice Error emitted when the caller is not the Branch Bridge Agent's Executors
    error UnrecognizedBridgeAgentExecutor();
}
