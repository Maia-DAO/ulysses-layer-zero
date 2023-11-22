// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Branch Bridge Agent Factory Contract
 * @author MaiaDAO
 * @notice Factory contract for allowing permissionless deployment of new Branch Bridge Agents. May or may not have a
 *         corresponding Branch Router contract allowing for customized execution before and / or after cross-chain
 *         message execution / emission.
 */
interface IBranchBridgeAgentFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new Branch Bridge Agent.
     * @param newRootRouterAddress New Root Router Address.
     * @param rootBridgeAgentAddress Root Bridge Agent Address.
     * @param rootBridgeAgentFactoryAddress Root Bridge Agent Factory Address.
     * @return newBridgeAgent New Bridge Agent Address.
     */
    function createBridgeAgent(
        address newRootRouterAddress,
        address rootBridgeAgentAddress,
        address rootBridgeAgentFactoryAddress
    ) external returns (address newBridgeAgent);

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new Bridge Agent is created.
    event BridgeAgentAdded(address indexed _bridgeAgent);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when caller is not the Core Branch Router.
    error UnrecognizedCoreBranchRouter();

    /// @notice Error emitted when Core Root Bridge Agent is received as zero address.
    error InvalidInputCannotBeZeroAddress();

    /// @notice Error emitted when the Root Bridge Agent Factory does not match with the Branch Bridge Agent Factory.
    error InvalidInputFactoryMismatch();
}
