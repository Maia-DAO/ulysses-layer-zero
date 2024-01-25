// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BranchBridgeAgent} from "@omni/BranchBridgeAgent.sol";

contract MockBranchBridgeAgent is BranchBridgeAgent {
    constructor(
        uint16 _rootChainId,
        uint16 _localChainId,
        address _rootBridgeAgentAddress,
        address _lzEndpointAddress,
        address _localRouterAddress,
        address _localPortAddress
    )
        BranchBridgeAgent(
            _rootChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _lzEndpointAddress,
            _localRouterAddress,
            _localPortAddress
        )
    {}

    /*///////////////////////////////////////////////////////////////
                      INTERNAL FUNCTIONS MADE PUBLIC
    ///////////////////////////////////////////////////////////////*/

    function setExecutionState(uint256 nonce, uint8 state) external {
        executionState[nonce] = state;
    }
}
