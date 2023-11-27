// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GasParams} from "./IBranchBridgeAgent.sol";

import {IRootRouter} from "./IRootRouter.sol";

/**
 * @title  Core Root Router Contract
 * @author MaiaDAO
 * @notice Core Root Router implementation for deployment in the Root Chain.
 *         This contract is allows users to permissionlessly add new tokens
 *         or Bridge Agents to the system. As well as executes key governance
 *         enabled system functions (i.e. `addBridgeAgentFactory`).
 * @dev    Func IDs for calling these functions through messaging layer:
 *
 *         **CROSS-CHAIN MESSAGING FUNCIDs**
 *
 *         | FUNC ID | FUNC NAME                      |
 *         | ------- | ------------------------------ |
 *         | 0x01    | addGlobalToken                 |
 *         | 0x02    | addLocalToken                  |
 *         | 0x03    | setLocalToken                  |
 *         | 0x04    | syncBranchBridgeAgent          |
 */
interface ICoreRootRouter is IRootRouter {
    /*///////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Root Chain Layer Zero Identifier.
    function rootChainId() external view returns (uint256);

    /// @notice Address for Local Port Address where funds deposited from this chain are kept
    ///         managed and supplied to different Port Strategies.
    function rootPortAddress() external view returns (address);

    /// @notice Bridge Agent to manage remote execution and cross-chain assets.
    function bridgeAgentAddress() external view returns (address payable);

    /// @notice Bridge Agent Executor Address.
    function bridgeAgentExecutorAddress() external view returns (address);

    /// @notice ERC20 hToken Root Factory Address.
    function hTokenFactoryAddress() external view returns (address);

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT MANAGEMENT FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new Chain (Branch Bridge Agent and respective Router) to a Root Bridge Agent.
     * @param _branchBridgeAgentFactory Address of the branch Bridge Agent Factory.
     * @param _newBranchRouter Address of the new branch router.
     * @param _refundee Address of the excess gas receiver.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function addBranchToBridgeAgent(
        address _rootBridgeAgent,
        address _branchBridgeAgentFactory,
        address _newBranchRouter,
        address _refundee,
        uint16 _dstChainId,
        GasParams[2] calldata _gParams
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                GOVERNANCE / ADMIN EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or Remove a Branch Bridge Agent Factory.
     * @param _rootBridgeAgentFactory Address of the root Bridge Agent Factory.
     * @param _branchBridgeAgentFactory Address of the branch Bridge Agent Factory.
     * @param _refundee Receiver of any leftover execution gas upon reaching the destination network.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function toggleBranchBridgeAgentFactory(
        address _rootBridgeAgentFactory,
        address _branchBridgeAgentFactory,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable;

    /**
     * @notice Add or Remove a Strategy Token.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _minimumReservesRatio Minimum Branch Port reserves ratio for the underlying token.
     * @dev Must be between 7000 and 9999 (70% and 99.99%). Can be any value if the token is being de-activated.
     * @param _refundee Receiver of any leftover execution gas upon reaching destination network.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function toggleStrategyToken(
        address _underlyingToken,
        uint256 _minimumReservesRatio,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable;

    /**
     * @notice Update an active Strategy Token's minimum reserves ratio.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _minimumReservesRatio Minimum Branch Port reserves ratio for the underlying token.
     * @param _refundee Receiver of any leftover execution gas upon reaching destination network.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */

    function updateStrategyToken(
        address _underlyingToken,
        uint256 _minimumReservesRatio,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable;

    /**
     * @notice Add or Remove a Port Strategy.
     * @param _portStrategy Address of the Port Strategy to be added for use in Branch strategies.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _dailyManagementLimit Daily management limit of the given token for the Port Strategy.
     * @param _reserveRatioManagementLimit Total reserves management limit of the given token for the Port Strategy.
     * @param _refundee Receiver of any leftover execution gas upon reaching destination network.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function togglePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable;

    /**
     * @notice Update a Port Strategy.
     * @param _portStrategy Address of the Port Strategy to be added for use in Branch strategies.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _dailyManagementLimit Daily management limit of the given token for the Port Strategy.
     * @param _reserveRatioManagementLimit Total reserves management limit of the given token for the Port Strategy.
     * @param _refundee Receiver of any leftover execution gas upon reaching destination network.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */

    function updatePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable;

    /**
     * @notice Set the Core Branch Router and Bridge Agent.
     * @param _refundee Receiver of any leftover execution gas upon reaching destination network.
     * @param _coreBranchRouter Address of the Core Branch Router.
     * @param _coreBranchBridgeAgent Address of the Core Branch Bridge Agent.
     * @param _dstChainId Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function setCoreBranch(
        address _refundee,
        address _coreBranchRouter,
        address _coreBranchBridgeAgent,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable;

    /**
     * @notice Allows governance to claim any native tokens accumulated from failed transactions.
     *  @param _refundee Receiver of any excess msg.value sent to Layer Zero on source chain.
     *  @param _recipient address to transfer ETH to on destination chain.
     *  @param _gParams gasParameters for remote execution
     */
    function sweep(address _refundee, address _recipient, uint16 _dstChainId, GasParams calldata _gParams)
        external
        payable;

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when an invalid chain id is provided.
    error InvalidChainId();

    /// @notice Error emitted when a chain id not approved by the Bridge Agent Manager is provided for chain addition.
    error UnauthorizedChainId();

    /// @notice Error emitted when the caller is not the Bridge Agent Manager.
    error UnauthorizedCallerNotManager();

    /// @notice Error emitted when the global token has already been added to a given chain.
    error TokenAlreadyAdded();

    /// @notice Error emitted when the provided token is not recognized as a global token.
    error UnrecognizedGlobalToken();

    /// @notice Error emitted when the caller is not the Bridge Agent Factory.
    error UnrecognizedBridgeAgentFactory();
}
