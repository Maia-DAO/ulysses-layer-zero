// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IBranchBridgeAgent as IBridgeAgent, GasParams} from "./interfaces/IBranchBridgeAgent.sol";
import {IBranchBridgeAgentFactory as IBridgeAgentFactory} from "./interfaces/IBranchBridgeAgentFactory.sol";
import {IERC20hTokenBranchFactory as IFactory} from "./interfaces/IERC20hTokenBranchFactory.sol";
import {IArbitrumBranchPort as IPort} from "./interfaces/IArbitrumBranchPort.sol";

import {CoreBranchRouter} from "./CoreBranchRouter.sol";
import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";

/**
 * @title  Arbitrum Core Branch Router Contract
 * @author MaiaDAO
 * @notice Core Branch Router implementation for Arbitrum deployment.
 *         This contract is responsible for permissionlessly adding new
 *         tokens or Bridge Agents to the system as well as key governance
 *         enabled system functions (i.e. `addBridgeAgentFactory`).
 * @dev    The function `addGlobalToken` is used to add a global token to a
 *         given Branch Chain is not available since the Arbitrum Branch is
 *         in the same network as the Root Environment.
 *         Func IDs for calling these functions through messaging layer:
 *
 *         CROSS-CHAIN MESSAGING FUNCIDs
 *         -----------------------------
 *         FUNC ID      | FUNC NAME
 *         -------------+---------------
 *         0x02         | addBridgeAgent
 *         0x03         | toggleBranchBridgeAgentFactory
 *         0x04         | removeBranchBridgeAgent
 *         0x05         | manageStrategyToken
 *         0x06         | managePortStrategy
 *
 */
contract ArbitrumCoreBranchRouter is CoreBranchRouter {
    constructor() CoreBranchRouter(address(0)) {}

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///@inheritdoc CoreBranchRouter
    function addLocalToken(address _underlyingAddress, GasParams calldata) external payable override {
        //Encode Data
        bytes memory data = abi.encode(
            _underlyingAddress,
            address(0),
            string.concat("Arbitrum Ulysses ", ERC20(_underlyingAddress).name()),
            string.concat("arb-u", ERC20(_underlyingAddress).symbol()),
            ERC20(_underlyingAddress).decimals()
        );

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Send Cross-Chain request (System Response/Request)
        IBridgeAgent(localBridgeAgentAddress).callOutSystem(payable(msg.sender), packedData, GasParams(0, 0));
    }

    /*///////////////////////////////////////////////////////////////
                BRIDGE AGENT MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to deploy/add a token already active in the global environment in the Root Chain. Must be called from another chain.
     *    @param _newBranchRouter the address of the new branch router.
     *    @param _branchBridgeAgentFactory the address of the branch bridge agent factory.
     *    @param _rootBridgeAgent the address of the root bridge agent.
     *    @param _rootBridgeAgentFactory the address of the root bridge agent factory.
     *    @param _gParams Gas parameters for remote execution.
     *    @dev FUNC ID: 2
     *    @dev all hTokens have 18 decimals.
     *
     */
    function _receiveAddBridgeAgent(
        address _newBranchRouter,
        address _branchBridgeAgentFactory,
        address _rootBridgeAgent,
        address _rootBridgeAgentFactory,
        GasParams memory _gParams
    ) internal override {
        //Check if msg.sender is a valid BridgeAgentFactory
        if (!IPort(localPortAddress).isBridgeAgentFactory(_branchBridgeAgentFactory)) {
            revert UnrecognizedBridgeAgentFactory();
        }

        //Create Token
        address newBridgeAgent = IBridgeAgentFactory(_branchBridgeAgentFactory).createBridgeAgent(
            _newBranchRouter, _rootBridgeAgent, _rootBridgeAgentFactory
        );

        //Check BridgeAgent Address
        if (!IPort(localPortAddress).isBridgeAgent(newBridgeAgent)) {
            revert UnrecognizedBridgeAgent();
        }

        //Encode Data
        bytes memory data = abi.encode(newBridgeAgent, _rootBridgeAgent);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x04), data);

        //Send Cross-Chain request
        IBridgeAgent(localBridgeAgentAddress).callOutSystem(payable(localPortAddress), packedData, _gParams);
    }

    /*///////////////////////////////////////////////////////////////
                    ANYCALL EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///@inheritdoc CoreBranchRouter
    function executeNoSettlement(bytes calldata _data) external payable override requiresAgentExecutor {
        if (_data[0] == 0x02) {
            (
                address newBranchRouter,
                address branchBridgeAgentFactory,
                address rootBridgeAgent,
                address rootBridgeAgentFactory,
            ) = abi.decode(_data[1:], (address, address, address, address, GasParams));

            _receiveAddBridgeAgent(
                newBranchRouter, branchBridgeAgentFactory, rootBridgeAgent, rootBridgeAgentFactory, GasParams(0, 0)
            );

            /// _toggleBranchBridgeAgentFactory
        } else if (_data[0] == 0x03) {
            (address bridgeAgentFactoryAddress) = abi.decode(_data[1:], (address));

            _toggleBranchBridgeAgentFactory(bridgeAgentFactoryAddress);

            /// _removeBranchBridgeAgent
        } else if (_data[0] == 0x04) {
            (address branchBridgeAgent) = abi.decode(_data[1:], (address));
            _removeBranchBridgeAgent(branchBridgeAgent);

            /// _manageStrategyToken
        } else if (_data[0] == 0x05) {
            (address underlyingToken, uint256 minimumReservesRatio) = abi.decode(_data[1:], (address, uint256));
            _manageStrategyToken(underlyingToken, minimumReservesRatio);

            /// _managePortStrategy
        } else if (_data[0] == 0x06) {
            (address portStrategy, address underlyingToken, uint256 dailyManagementLimit, bool isUpdateDailyLimit) =
                abi.decode(_data[1:], (address, address, uint256, bool));
            _managePortStrategy(portStrategy, underlyingToken, dailyManagementLimit, isUpdateDailyLimit);

            /// Unrecognized Function Selector
        } else {
            revert UnrecognizedFunctionId();
        }
    }
}
