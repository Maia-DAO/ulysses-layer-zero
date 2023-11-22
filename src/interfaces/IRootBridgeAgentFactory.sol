// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title  Root Bridge Agent Factory Contract
 * @author MaiaDAO
 * @notice Factory contract for allowing permissionless deployment of new Root Bridge Agents. May or may not have a
 *         corresponding Root Router contract allowing for customized execution before and / or after cross-chain
 *         message execution / emission.
 */
interface IRootBridgeAgentFactory {
    /*///////////////////////////////////////////////////////////////
                        BRIDGE AGENT FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    function createBridgeAgent(address newRootRouterAddress) external returns (address newBridgeAgent);

    /*///////////////////////////////////////////////////////////////
                                EVENTS
    ///////////////////////////////////////////////////////////////*/

    event BridgeAgentAdded(address indexed bridgeAgent, address indexed manager);
}
