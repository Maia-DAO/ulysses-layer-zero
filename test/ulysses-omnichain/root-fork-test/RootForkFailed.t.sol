//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkCallOutWithDeposit.t.sol";

contract RootForkFailedTest is RootForkCallOutWithDepositTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using BranchBridgeAgentHelper for BranchBridgeAgent;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    //////////////////////////////////////
    //    RETRY, RETRIEVE AND REDEEM    //
    //////////////////////////////////////

    function testRetrieveDeposit() public {
        //Set up
        _testCallOutWithDepositNotEnoughGasForRootRetryMode();

        switchToLzChain(avaxChainId);

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        //Call Deposit function
        avaxMulticallBridgeAgent.retrieveDeposit{value: 10 ether}(prevNonceRoot, GasParams(1_000_000, 0.01 ether));

        //Stop prank
        vm.stopPrank();

        require(
            avaxMulticallBridgeAgent.getDepositEntry(prevNonceRoot).status == 0, "Deposit status should be success."
        );

        switchToLzChain(rootChainId);

        switchToLzChain(avaxChainId);

        require(
            avaxMulticallBridgeAgent.getDepositEntry(prevNonceRoot).status == 1,
            "Deposit status should be ready for redemption."
        );
    }

    function testRedeemDepositAfterRetrieve() public {
        //Set up
        testRetrieveDeposit();

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        uint256 balanceBefore = avaxMockAssetToken.balanceOf(user);

        //Call Deposit function
        avaxMulticallBridgeAgent.redeemDeposit(prevNonceRoot, user);

        //Stop prank
        vm.stopPrank();

        require(
            avaxMulticallBridgeAgent.getDepositEntry(prevNonceRoot).owner == address(0),
            "Deposit status should have ceased to exist"
        );

        require(avaxMockAssetToken.balanceOf(user) == balanceBefore + 100 ether, "Balance should be increased.");
    }

    function testRedeemDepositAfterFallback() public {
        //Set up
        _testCallOutWithDepositWrongCalldataForRootFallbackMode();

        uint256 balanceBefore = avaxMockAssetToken.balanceOf(user);

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        //Call Deposit function
        avaxMulticallBridgeAgent.redeemDeposit(prevNonceRoot, user);

        //Stop prank
        vm.stopPrank();

        require(
            avaxMulticallBridgeAgent.getDepositEntry(prevNonceRoot).owner == address(0),
            "Deposit status should have ceased to exist"
        );

        require(avaxMockAssetToken.balanceOf(user) == balanceBefore + 100 ether, "Balance should be increased.");
    }

    function testRetryDeposit() public {
        //Set up
        _testCallOutWithDepositNotEnoughGasForRootRetryMode();

        _updateBranchNonce(avaxMulticallBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
        _updateRootNonce(multicallRootBridgeAgent);

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newAvaxAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 0;

            // encodeRetryDepositCallData(
            //     outputToken,
            //     amountOut,
            //     depositOut,
            //     newAvaxAssetFtmLocalToken,
            //     mockApp,
            //     ftmChainId,
            //     800_000,
            //     1 ether,
            //     packedData
            // );

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            //Output Params
            OutputParams memory outputParams = OutputParams(user, user, outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId, GasParams(800_000, 1 ether));

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Call Deposit function
        avaxMulticallBridgeAgent.retryDepositSigned{value: 5 ether}(
            prevNonceBranch - 1, packedData, GasParams(2_000_000, 0.02 ether), false
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, false);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, true);

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).status == 0,
            "Settlement status should be success."
        );

        switchToLzChain(ftmChainId);

        // check this address balance
        require(MockERC20(newAvaxAssetFtmLocalToken).balanceOf(user) == 99 ether, "Tokens should be received");
    }

    function testRetryDepositUnexpectedSettlementFailure() public {
        //Set up
        _testCallOutWithDepositNotEnoughGasForRootRetryMode();

        _updateBranchNonce(avaxMulticallBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
        _updateRootNonce(multicallRootBridgeAgent);

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newAvaxAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 0;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            //Output Params
            OutputParams memory outputParams = OutputParams(user, user, outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId, GasParams(0, 1 ether));

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        bytes memory bytecode = address(newAvaxAssetFtmLocalToken).code;

        vm.etch(address(newAvaxAssetFtmLocalToken), "");

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(user, 100 ether);

        //Approve spend by router
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        //Call Deposit function
        avaxMulticallBridgeAgent.retryDepositSigned{value: 5 ether}(
            prevNonceBranch - 1, packedData, GasParams(2_000_000, 0.02 ether), false
        );

        // Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, false);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, true);

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).status == 0,
            "Settlement status should be success."
        );

        switchToLzChain(ftmChainId);

        //ExecutionStatus should be 0
        require(
            ftmMulticallBridgeAgent.executionState(prevNonceRoot + 1) == 0, "Settlement status should not be executed."
        );

        vm.etch(address(newAvaxAssetFtmLocalToken), bytecode);

        // check this address balance
        require(MockERC20(newAvaxAssetFtmLocalToken).balanceOf(user) == 0, "Tokens should not be received");
    }

    function testRetrySettlement() public {
        //Set up
        testRetryDepositUnexpectedSettlementFailure();

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        _updateBranchNonce(avaxMulticallBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
        _updateRootNonce(multicallRootBridgeAgent);

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);
        vm.etch(user, address(avaxMulticallBridgeAgent).code);

        //Call Deposit function
        avaxMulticallBridgeAgent.retrySettlement{value: 100 ether}(
            prevNonceBranch - 1, "", [GasParams(1_000_000, 0.1 ether), GasParams(0, 0)], false
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, false);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, false);

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).status == 0,
            "Settlement status should be success."
        );

        switchToLzChain(ftmChainId);

        // check this address balance
        require(MockERC20(newAvaxAssetFtmLocalToken).balanceOf(user) == 99 ether, "Tokens should be received");

        //ExecutionStatus should be 1 (DONE)
        require(ftmMulticallBridgeAgent.executionState(prevNonceRoot - 1) == 1, "Settlement status be executed.");
    }

    // Branch Removed
    // function testRetrySettlementTriggerFallback() public {
    //     //Set up
    //     testRetryDepositUnexpectedSettlementFailure();

    //     switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

    //     _updateBranchNonce(avaxMulticallBridgeAgent);

    //     //Switch to avax
    //     switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
    //     _updateRootNonce(multicallRootBridgeAgent);

    //     switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

    //     //Get some ether.
    //     vm.deal(user, 100 ether);

    //     //Prank address 18
    //     vm.startPrank(user);

    //     //Call Deposit function
    //     avaxMulticallBridgeAgent.retrySettlement{value: 100 ether}(
    //         prevNonceBranch - 1, "a", [GasParams(1_000_000, 0.1 ether), GasParams(300_000, 5 ether)], true
    //     );

    //     //Stop prank
    //     vm.stopPrank();

    //     _checkBranchNonce(avaxMulticallBridgeAgent, false);

    //     switchToLzChain(rootChainId);

    //     _checkRootNonce(multicallRootBridgeAgent, false);

    //     require(
    //         multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).status == 0,
    //         "Settlement status should be success."
    //     );

    //     switchToLzChain(ftmChainId);

    //     switchToLzChain(rootChainId);

    //     require(
    //         multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot - 1).status == 1,
    //         "Settlement status should be failed after fallback."
    //     );
    // }

    function testRetrySettlementNoFallback() public {
        //Set up
        testRetryDepositUnexpectedSettlementFailure();

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        _updateBranchNonce(avaxMulticallBridgeAgent);

        //Switch to avax
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
        _updateRootNonce(multicallRootBridgeAgent);

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newAvaxAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 0;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            //Output Params
            OutputParams memory outputParams = OutputParams(user, user, outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId, GasParams(800_000, 1 ether));

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        bytes memory bytecode = address(newAvaxAssetFtmLocalToken).code;

        vm.etch(address(newAvaxAssetFtmLocalToken), "");

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        //Get some ether.
        vm.deal(user, 100 ether);

        //Prank address 18
        vm.startPrank(user);

        // Call Retry Seetlement function
        avaxMulticallBridgeAgent.retrySettlement{value: 100 ether}(
            prevNonceBranch - 1, "", [GasParams(1_000_000, 0.1 ether), GasParams(300_000, 0)], false
        );

        //Stop prank
        vm.stopPrank();

        _checkBranchNonce(avaxMulticallBridgeAgent, false);

        switchToLzChain(rootChainId);

        _checkRootNonce(multicallRootBridgeAgent, false);

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).status == 0,
            "Settlement status should be success."
        );

        switchToLzChain(ftmChainId);

        vm.etch(address(newAvaxAssetFtmLocalToken), bytecode);

        switchToLzChain(rootChainId);

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot - 1).status == 0,
            "Settlement status should be stay unexecuted after failure."
        );
    }

    function testRetrieveSettlement() public {
        //Set up
        testRetrySettlementNoFallback();

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        //Call Deposit function
        multicallRootBridgeAgent.retrieveSettlement{value: 1 ether}(prevNonceRoot - 1, GasParams(1_000_000, 0.1 ether));

        //Stop prank
        vm.stopPrank();

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).status == 0,
            "Settlement status should be success."
        );

        switchToLzChain(ftmChainId);

        switchToLzChain(rootChainId);

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot - 1).status == 1,
            "Settlement status should be ready for redemption."
        );
    }

    function testRedeemSettlement() public {
        //Set up
        testRetrieveSettlement();

        //Get some ether.
        vm.deal(user, 10 ether);

        //Prank address 18
        vm.startPrank(user);

        //Call Deposit function
        multicallRootBridgeAgent.redeemSettlement(prevNonceRoot - 1, user);

        //Stop prank
        vm.stopPrank();

        require(
            multicallRootBridgeAgent.getSettlementEntry(prevNonceRoot).owner == address(0),
            "Settlement should have vanished."
        );
    }
}
