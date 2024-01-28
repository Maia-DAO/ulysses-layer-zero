//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./ImportHelper.sol";

contract TestHelper is Test, BridgeAgentConstants {
    address lzEndpointAddress = address(0xCAFE);

    address public mockApp = address(0xDAFA);

    MulticallRootRouter rootMulticallRouter;

    RootBridgeAgent coreBridgeAgent;

    function encodeCallNoDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) internal {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit * tx.gasprice + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        if (!success) console2.log("Failed to send gas");

        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId,
        bool _mockCall
    ) internal {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit * tx.gasprice + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _data);

        if (_mockCall) {
            vm.mockCall(
                address(rootMulticallRouter),
                abi.encodeWithSignature("executeDepositSingle(bytes,(uint32,address,address,uint256,uint256),uint16)"),
                abi.encode(0)
            );
        }

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        {
            (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
            if (!success) console2.log("Failed to send gas");
        }

        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) internal {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        if (!success) console2.log("Failed to send gas");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, _data
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId,
        bool _mockCall
    ) internal {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        // Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit * tx.gasprice + _gasParams.remoteBranchExecutionGas);

        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x03), uint8(_hTokens.length), _nonce, _hTokens, _tokens, _amounts, _deposits, _data
        );

        if (_mockCall) {
            vm.mockCall(
                address(rootMulticallRouter),
                abi.encodeWithSignature(
                    "executeDepositMultiple(bytes,(uint8,uint32,address[],address[],uint256[],uint256[]),uint16)"
                ),
                abi.encode(0)
            );
        }

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        {
            (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
            if (!success) console2.log("Failed to send gas");
        }

        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) internal {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        if (!success) console2.log("Failed to send gas");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, _data
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallNoDepositSigned(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        address _user,
        uint32 _nonce,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) internal {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit * tx.gasprice + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x04), _user, _nonce, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        if (!success) console2.log("Failed to send gas");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositSigned(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        address _user,
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) internal {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit * tx.gasprice + _gasParams.remoteBranchExecutionGas);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        //Encode Data
        bytes memory inputCalldata =
            abi.encodePacked(bytes1(0x05), _user, _nonce, _hToken, _token, _amount, _deposit, _data);

        {
            (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
            if (!success) console2.log("Failed to send gas");
        }

        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositMultipleSigned(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        address _user,
        uint32 _nonce,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) internal {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit * tx.gasprice + _gasParams.remoteBranchExecutionGas);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x06), _user, uint8(_hTokens.length), _nonce, _hTokens, _tokens, _amounts, _deposits, _data
        );

        {
            (bool success,) = _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
            if (!success) console2.log("Failed to send gas");
        }

        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function checkNonceState(RootBridgeAgent rootBridgeAgent, uint32 _nonce, uint16 _chainId) internal view {
        uint256 depositExecutionStateAfter = rootBridgeAgent.executionState(_chainId, _nonce);

        require(depositExecutionStateAfter == STATUS_DONE, "Execution state should be 1");
    }

    function checkNonceStateFail(RootBridgeAgent rootBridgeAgent, uint32 _nonce, uint16 _chainId) internal view {
        uint256 depositExecutionStateAfter = rootBridgeAgent.executionState(_chainId, _nonce);

        require(depositExecutionStateAfter == STATUS_READY, "Execution state should be 0");
    }

    function _getAdapterParams(uint256 _gasLimit, uint256 _remoteBranchExecutionGas, address _callee)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(2), _gasLimit, _remoteBranchExecutionGas, _callee);
    }

    function expectLayerZeroSend(
        uint16 _dstChainId,
        address destinationBridgeAgent,
        uint256 msgValue,
        bytes memory data,
        address refundee,
        GasParams memory gasParams,
        uint256 _baseGasCost
    ) internal {
        bytes memory adatperParams = _getAdapterParams(
            gasParams.gasLimit + _baseGasCost, gasParams.remoteBranchExecutionGas, destinationBridgeAgent
        );

        vm.expectCall(
            lzEndpointAddress,
            msgValue,
            abi.encodeWithSelector(
                // "send(uint16,bytes,bytes,address,address,bytes)",
                ILayerZeroEndpoint.send.selector,
                _dstChainId,
                abi.encodePacked(destinationBridgeAgent, coreBridgeAgent),
                data,
                refundee,
                address(0),
                adatperParams
            )
        );
    }

    function testCreateDepositSingle(
        ArbitrumBranchBridgeAgent _bridgeAgent,
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        GasParams memory
    ) internal view {
        // Cast to Dynamic
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Get Deposit
        Deposit memory deposit = _bridgeAgent.getDepositEntry(_depositNonce);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        require(
            keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(hTokens)),
            "Deposit local hToken doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(tokens)),
            "Deposit underlying token doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(amounts)),
            "Deposit amount doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(deposits)),
            "Deposit deposit doesn't match"
        );

        require(deposit.status == 0, "Deposit status should be succesful.");
    }
}
