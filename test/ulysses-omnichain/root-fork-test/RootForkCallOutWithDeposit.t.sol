//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkAddToken.t.sol";

// The functions in this contract are defined with internal visibility
// so that the RunTest contract can make them public and avoid running the tests twice.
contract RootForkCallOutWithDepositTest is RootForkAddTokenTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using BranchBridgeAgentHelper for BranchBridgeAgent;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    address user = address(18);

    //////////////////////////////////////
    //          TOKEN TRANSFERS         //
    //////////////////////////////////////

    function encodeMulticallNoOutput(Multicall2.Call[] memory callData) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x01), abi.encode(callData));
    }

    function encodeMulticallSingleOutput(
        Multicall2.Call[] memory callData,
        OutputParams memory outputParams,
        uint16 dstChainId,
        GasParams memory gasParams
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x02), abi.encode(callData, outputParams, dstChainId, gasParams));
    }

    function encodeMulticallMultipleOutput(
        Multicall2.Call[] memory callData,
        OutputMultipleParams memory outputMultipleParams,
        uint16 dstChainId,
        GasParams memory gasParams
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes1(0x03), abi.encode(callData, outputMultipleParams, dstChainId, gasParams));
    }

    function prepareMulticallSingleOutput_singleTransfer(
        address, // multicallTransferToken,
        address multicallTransferTo,
        uint256 multicallTransferAmount,
        address settlementOwner,
        address recipient,
        address outputToken,
        uint256 amountOut,
        uint256 depositOut,
        uint16 dstChainId,
        GasParams memory gasParams
    ) internal pure returns (bytes memory) {
        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        //Mock action
        calls[0] = Multicall2.Call({
            target: outputToken,
            callData: abi.encodeWithSelector(bytes4(0xa9059cbb), multicallTransferTo, multicallTransferAmount)
        });

        //Output Params
        OutputParams memory outputParams = OutputParams(settlementOwner, recipient, outputToken, amountOut, depositOut);

        return encodeMulticallSingleOutput(calls, outputParams, dstChainId, gasParams);
    }

    function _testCallOutWithDepositArbtirum() public {
        _testFuzzCallOutWithDepositArbtirum(address(this), 100 ether, 100 ether, 100 ether, 50 ether);
    }

    function _testFuzzCallOutWithDepositArbtirum(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) internal {
        //Set up
        _testAddLocalTokenArbitrum();

        (_user, _amount, _deposit, _amountOut, _depositOut) =
            BranchBridgeAgentHelper.adjustValues(_user, _amount, _deposit, _amountOut, _depositOut);

        // Prepare data
        bytes memory packedData = prepareMulticallSingleOutput_singleTransfer(
            newArbitrumAssetGlobalAddress,
            mockApp,
            0,
            _user,
            _user,
            newArbitrumAssetGlobalAddress,
            _amountOut,
            _depositOut,
            rootChainId,
            GasParams(0, 0)
        );

        //Get some gas.
        vm.deal(_user, 1 ether);

        if (_amount - _deposit > 0) {
            //assure there is enough balance for mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(newArbitrumAssetGlobalAddress).mint(_user, _amount - _deposit);
            vm.stopPrank();
            arbitrumMockToken.mint(address(arbitrumPort), _amount - _deposit);
        }

        //Mint Underlying Token.
        if (_deposit > 0) arbitrumMockToken.mint(_user, _deposit);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: _amount,
            deposit: _deposit
        });

        //Call Deposit function
        vm.startPrank(_user);
        arbitrumMockToken.approve(address(arbitrumPort), _deposit);
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBranchBridgeAgent.callOutSignedAndBridge{value: 1 ether}(
            packedData, depositInput, GasParams(0.5 ether, 0.5 ether), false
        );
        vm.stopPrank();

        // Test If Deposit was successful
        BranchBridgeAgent(payable(arbitrumMulticallBranchBridgeAgent))._testCreateDepositSingle(
            uint32(1), _user, address(newArbitrumAssetGlobalAddress), address(arbitrumMockToken), _amount, _deposit
        );

        address userAccount = address(rootPort.getUserAccount(_user));

        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == _amount - _deposit + _deposit - _depositOut,
            "LocalPort tokens"
        );

        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        require(MockERC20(arbitrumMockToken).balanceOf(_user) == _depositOut, "User tokens");

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == _amountOut - _depositOut, "User Global tokens"
        );

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount) == _amount - _amountOut,
            "User Account tokens"
        );
    }

    function _testCallOutWithDepositSuccess() public {
        //Set up
        _testAddLocalTokenArbitrum();

        _updateRootNonce(multicallRootBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        _updateBranchNonce(avaxMulticallBridgeAgent);

        // Prepare data
        bytes memory packedData = prepareMulticallSingleOutput_singleTransfer(
            newAvaxAssetGlobalAddress,
            mockApp,
            1 ether,
            user,
            user,
            newAvaxAssetGlobalAddress,
            99 ether,
            50 ether,
            avaxChainId,
            GasParams(500_000, 0)
        );

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 100 ether}(
            packedData, depositInput, GasParams(1_800_000, 0.01 ether), false
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, true);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, true);

        switchToChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        // Test If Deposit was successful
        BranchBridgeAgent(payable(avaxMulticallBridgeAgent))._testCreateDepositSingle(
            uint32(prevNonceBranch),
            user,
            address(avaxMockAssethToken),
            address(avaxMockAssetToken),
            100 ether,
            100 ether
        );

        switchToChainWithoutExecutePendingOrPacketUpdate(rootChainId);
    }

    function _testCallOutWithDepositNotEnoughGasForRootRetryMode() public {
        //Set up
        _testAddLocalTokenArbitrum();

        _updateRootNonce(multicallRootBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);
        _updateBranchNonce(avaxMulticallBridgeAgent);

        // Prepare data
        bytes memory packedData = prepareMulticallSingleOutput_singleTransfer(
            newAvaxAssetGlobalAddress,
            mockApp,
            1 ether,
            user,
            user,
            newAvaxAssetGlobalAddress,
            99 ether,
            50 ether,
            avaxChainId,
            GasParams(500_000, 0)
        );

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 100 ether}(
            packedData, depositInput, GasParams(600_000, 0.01 ether), false
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, true);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, false);

        switchToChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        // Test If Deposit was successful
        BranchBridgeAgent(payable(avaxMulticallBridgeAgent))._testCreateDepositSingle(
            uint32(prevNonceBranch),
            user,
            address(avaxMockAssethToken),
            address(avaxMockAssetToken),
            100 ether,
            100 ether
        );

        switchToChainWithoutExecutePendingOrPacketUpdate(rootChainId);
    }

    function _testCallOutWithDepositWrongCalldataForRootRetryMode() public {
        //Set up
        _testAddLocalTokenArbitrum();

        _updateRootNonce(multicallRootBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);
        _updateBranchNonce(avaxMulticallBridgeAgent);

        // Prepare data
        bytes memory packedData = prepareMulticallSingleOutput_singleTransfer(
            newAvaxAssetGlobalAddress,
            mockApp,
            1 ether,
            user,
            user,
            newAvaxAssetGlobalAddress,
            99 ether,
            50 ether,
            ftmChainId, // root will revert with `UnrecognizedUnderlyingAddress` because ftm local token was not added
            GasParams(500_000, 0)
        );

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 100 ether}(
            packedData, depositInput, GasParams(1_250_000, 0.01 ether), false
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, true);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, false);

        switchToChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        // Test If Deposit was successful
        BranchBridgeAgent(payable(avaxMulticallBridgeAgent))._testCreateDepositSingle(
            uint32(prevNonceBranch),
            user,
            address(avaxMockAssethToken),
            address(avaxMockAssetToken),
            100 ether,
            100 ether
        );
    }

    function _testCallOutWithDepositNotEnoughGasForRootFallbackMode() public {
        //Set up
        _testAddLocalTokenArbitrum();

        _updateRootNonce(multicallRootBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);
        _updateBranchNonce(avaxMulticallBridgeAgent);

        // Prepare data
        bytes memory packedData = prepareMulticallSingleOutput_singleTransfer(
            newAvaxAssetGlobalAddress,
            mockApp,
            1 ether,
            user,
            user,
            newAvaxAssetGlobalAddress,
            99 ether,
            50 ether,
            avaxChainId,
            GasParams(500_000, 0)
        );

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 100 ether}(
            packedData, depositInput, GasParams(800_000, 0.01 ether), true
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, true);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, false);

        switchToChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        // Test If Deposit was successful
        BranchBridgeAgent(payable(avaxMulticallBridgeAgent))._testCreateDepositSingle(
            uint32(prevNonceBranch),
            user,
            address(avaxMockAssethToken),
            address(avaxMockAssetToken),
            100 ether,
            100 ether
        );

        // Clear logs from failed tx
        vm.getRecordedLogs();

        switchToChainWithoutExecutePendingOrPacketUpdate(rootChainId);
    }

    function _testCallOutWithDepositWrongCalldataForRootFallbackMode() public {
        //Set up
        _testAddLocalTokenArbitrum();

        _updateRootNonce(multicallRootBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);
        _updateBranchNonce(avaxMulticallBridgeAgent);

        // Prepare data
        bytes memory packedData = prepareMulticallSingleOutput_singleTransfer(
            newAvaxAssetGlobalAddress,
            mockApp,
            1 ether,
            user,
            user,
            newAvaxAssetGlobalAddress,
            99 ether,
            50 ether,
            ftmChainId, // root will revert with `UnrecognizedUnderlyingAddress` because ftm local token was not added
            GasParams(500_000, 0)
        );

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 100 ether}(
            packedData, depositInput, GasParams(1_500_000, 0.2 ether), true
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, true);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, false);

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        // Test If Deposit was successful
        BranchBridgeAgent(payable(avaxMulticallBridgeAgent))._testCreateDepositSingle(
            uint32(prevNonceBranch),
            user,
            address(avaxMockAssethToken),
            address(avaxMockAssetToken),
            100 ether,
            100 ether
        );

        switchToLzChain(avaxChainId);

        // Check if status failed
        avaxMulticallBridgeAgent.getDepositEntry(prevNonceBranch).status = 1;
    }
}

contract RootForkCallOutWithDepositRunTest is RootForkCallOutWithDepositTest {
    function testCallOutWithDepositArbtirum() public {
        _testCallOutWithDepositArbtirum();
    }

    function testFuzzCallOutWithDepositArbtirum(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) public {
        _testFuzzCallOutWithDepositArbtirum(_user, _amount, _deposit, _amountOut, _depositOut);
    }

    function testCallOutWithDepositSuccess() public {
        _testCallOutWithDepositSuccess();
    }

    function testCallOutWithDepositNotEnoughGasForRootRetryMode() public {
        _testCallOutWithDepositNotEnoughGasForRootRetryMode();
    }

    function testCallOutWithDepositWrongCalldataForRootRetryMode() public {
        _testCallOutWithDepositWrongCalldataForRootRetryMode();
    }

    function testCallOutWithDepositNotEnoughGasForRootFallbackMode() public {
        _testCallOutWithDepositNotEnoughGasForRootFallbackMode();
    }

    function testCallOutWithDepositWrongCalldataForRootFallbackMode() public {
        _testCallOutWithDepositWrongCalldataForRootFallbackMode();
    }
}
