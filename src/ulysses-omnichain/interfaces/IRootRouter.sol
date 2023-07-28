// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DepositParams, DepositMultipleParams} from "../interfaces/IRootBridgeAgent.sol";

/**
 * @title  Root Router Contract
 * @author MaiaDAO
 * @notice Base Branch Contract for interfacing with Root Bridge Agents.
 *         This contract for deployment in the Root Chain of the Ulysses Omnichain System,
 *         additional logic can be implemented to perform actions before sending cross-chain
 *         requests to Branch Chains, as well as in response to remote requests.
 */
interface IRootRouter {
    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     *     @notice Function to execute Branch Bridge Agent system initiated requests with no asset deposit.
     *     @param funcId 1 byte called Router function identifier.
     *     @param encodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     */
    function executeResponse(bytes1 funcId, bytes memory encodedData, uint16 fromChainId) external payable;

    /**
     *     @notice Function responsible of executing a crosschain request without any deposit.
     *     @param funcId 1 byte Router function identifier.
     *     @param encodedData data received from messaging layer.
     *     @param fromChainId chain where the request originated from.
     *
     */
    function execute(bytes1 funcId, bytes memory encodedData, uint16 fromChainId) external payable;

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param encodedData execution data received from messaging layer.
     *   @param dParams cross-chain deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function executeDepositSingle(
        bytes1 funcId,
        bytes memory encodedData,
        DepositParams memory dParams,
        uint16 fromChainId
    ) external payable;

    /**
     *   @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets attached.
     *   @param funcId 1 byte Router function identifier.
     *   @param encodedData execution data received from messaging layer.
     *   @param dParams cross-chain multiple deposit information.
     *   @param fromChainId chain where the request originated from.
     *
     */
    function executeDepositMultiple(
        bytes1 funcId,
        bytes memory encodedData,
        DepositMultipleParams memory dParams,
        uint16 fromChainId
    ) external payable;

    /**
     * @notice Function responsible of executing a crosschain request with msg.sender without any deposit.
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function executeSigned(bytes1 funcId, bytes memory encodedData, address userAccount, uint16 fromChainId)
        external
        payable;

    /**
     * @notice Function responsible of executing a crosschain request which contains cross-chain deposit information and msg.sender attached.
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param dParams cross-chain deposit information.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function executeSignedDepositSingle(
        bytes1 funcId,
        bytes memory encodedData,
        DepositParams memory dParams,
        address userAccount,
        uint16 fromChainId
    ) external payable;

    /**
     * @notice Function responsible of executing a crosschain request which contains cross-chain deposit information for multiple assets and msg.sender attached.
     * @param funcId 1 byte Router function identifier.
     * @param encodedData execution data received from messaging layer.
     * @param dParams cross-chain multiple deposit information.
     * @param userAccount user account address.
     * @param fromChainId chain where the request originated from.
     */
    function executeSignedDepositMultiple(
        bytes1 funcId,
        bytes memory encodedData,
        DepositMultipleParams memory dParams,
        address userAccount,
        uint16 fromChainId
    ) external payable;

    /*///////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnrecognizedFunctionId();
    error UnrecognizedBridgeAgentExecutor();
}
