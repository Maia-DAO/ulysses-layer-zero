//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

contract RootForkBridgeMultipleTest is RootForkSetupTest, BridgeAgentConstants {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using BranchBridgeAgentHelper for BranchBridgeAgent;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    /*///////////////////////////////////////////////////////////////
                   CALL OUT AND BRIDGE MULTIPLE TESTS
    ///////////////////////////////////////////////////////////////*/

    // Test takes over 1min per run when fuzzing if the length is too high, max without reverting should be 255
    uint8 constant MAX_LENGTH = 5;

    function test_fuzz_CallOutAndBridgeMultiple_withLocalToken_router_ftm(
        uint256[MAX_LENGTH] memory _amounts,
        uint256[MAX_LENGTH] memory _deposits,
        uint8[MAX_LENGTH] memory _decimals,
        uint8 length
    ) public {
        _test_fuzz_CallOutAndBridgeMultiple_withLocalToken(
            true,
            ftmMulticallBridgeAgent,
            ftmMulticallRouter,
            ftmCoreRouter,
            ftmPort,
            _amounts,
            _deposits,
            _decimals,
            length,
            ftmChainId
        );
    }

    function test_fuzz_CallOutAndBridgeMultiple_withLocalToken_bridgeAgent_ftm(
        uint256[MAX_LENGTH] memory _amounts,
        uint256[MAX_LENGTH] memory _deposits,
        uint8[MAX_LENGTH] memory _decimals,
        uint8 length
    ) public {
        _test_fuzz_CallOutAndBridgeMultiple_withLocalToken(
            false,
            ftmMulticallBridgeAgent,
            ftmMulticallRouter,
            ftmCoreRouter,
            ftmPort,
            _amounts,
            _deposits,
            _decimals,
            length,
            ftmChainId
        );
    }

    function test_fuzz_CallOutAndBridgeMultiple_withLocalToken_router_avax(
        uint256[MAX_LENGTH] memory _amounts,
        uint256[MAX_LENGTH] memory _deposits,
        uint8[MAX_LENGTH] memory _decimals,
        uint8 length
    ) public {
        _test_fuzz_CallOutAndBridgeMultiple_withLocalToken(
            true,
            avaxMulticallBridgeAgent,
            avaxMulticallRouter,
            avaxCoreRouter,
            avaxPort,
            _amounts,
            _deposits,
            _decimals,
            length,
            avaxChainId
        );
    }

    function test_fuzz_CallOutAndBridgeMultiple_withLocalToken_bridgeAgent_avax(
        uint256[MAX_LENGTH] memory _amounts,
        uint256[MAX_LENGTH] memory _deposits,
        uint8[MAX_LENGTH] memory _decimals,
        uint8 length
    ) public {
        _test_fuzz_CallOutAndBridgeMultiple_withLocalToken(
            false,
            avaxMulticallBridgeAgent,
            avaxMulticallRouter,
            avaxCoreRouter,
            avaxPort,
            _amounts,
            _deposits,
            _decimals,
            length,
            avaxChainId
        );
    }

    struct Cache {
        bool callRouter;
        BranchBridgeAgent branchBridgeAgent;
        BaseBranchRouter branchMulticallRouter;
        CoreBranchRouter branchCoreRouter;
        BranchPort branchPort;
        uint256[MAX_LENGTH] amounts;
        uint256[MAX_LENGTH] deposits;
        uint8[MAX_LENGTH] decimals;
        address spenderToApprove;
    }

    function _test_fuzz_CallOutAndBridgeMultiple_withLocalToken(
        bool _callRouter,
        BranchBridgeAgent _branchBridgeAgent,
        BaseBranchRouter _branchMulticallRouter,
        CoreBranchRouter _branchCoreRouter,
        BranchPort _branchPort,
        uint256[MAX_LENGTH] memory _amounts,
        uint256[MAX_LENGTH] memory _deposits,
        uint8[MAX_LENGTH] memory _decimals,
        uint8 _length,
        uint16 _lzChainId
    ) internal {
        Cache memory cache = Cache({
            callRouter: _callRouter,
            branchBridgeAgent: _branchBridgeAgent,
            branchMulticallRouter: _branchMulticallRouter,
            branchCoreRouter: _branchCoreRouter,
            branchPort: _branchPort,
            amounts: _amounts,
            deposits: _deposits,
            decimals: _decimals,
            spenderToApprove: _callRouter ? address(_branchMulticallRouter) : address(_branchPort)
        });

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(_lzChainId);

        vm.deal(address(this), 256_000 ether);

        _length %= MAX_LENGTH;
        _length++;

        address[] memory underlyingTokens = new address[](_length);
        uint256[] memory amounts = new uint256[](_length);
        uint256[] memory deposits = new uint256[](_length);

        for (uint256 i = 0; i < _length; i++) {
            MockERC20 underToken =
                new MockERC20("Test Ulysses Hermes underlying token", "test-uhUNDER", cache.decimals[i]);

            underlyingTokens[i] = address(underToken);
            cache.branchCoreRouter.addLocalToken{value: 100 ether}(address(underToken), GasParams(2_000_000, 0));

            if (cache.amounts[i] > 0) {
                amounts[i] = cache.amounts[i];
                deposits[i] = cache.deposits[i] % cache.amounts[i];

                if (deposits[i] > 0) {
                    underToken.mint(address(this), deposits[i]);
                    underToken.approve(cache.spenderToApprove, deposits[i]);
                }
            }
        }

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(_lzChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        address[] memory hTokens = new address[](_length);
        address[] memory globalTokens = new address[](_length);

        for (uint256 i = 0; i < _length; i++) {
            hTokens[i] = rootPort.getLocalTokenFromUnderlying(underlyingTokens[i], _lzChainId);

            MockERC20 globalToken = MockERC20(rootPort.getGlobalTokenFromLocal(hTokens[i], _lzChainId));
            globalTokens[i] = address(globalToken);

            uint256 hTokenAmount = amounts[i] - deposits[i];
            if (hTokenAmount > 0) {
                vm.prank(address(rootPort));
                globalToken.mint(address(this), hTokenAmount);

                globalToken.approve(address(rootPort), hTokenAmount);

                vm.prank(address(multicallRootBridgeAgent));
                rootPort.bridgeToBranch(address(this), address(globalToken), hTokenAmount, 0, _lzChainId);
            }
        }

        switchToLzChain(_lzChainId);

        for (uint256 i = 0; i < _length; i++) {
            uint256 hTokenAmount = amounts[i] - deposits[i];
            if (hTokenAmount > 0) {
                vm.prank(address(cache.branchBridgeAgent));
                cache.branchPort.bridgeIn(address(this), hTokens[i], hTokenAmount);

                MockERC20(hTokens[i]).approve(cache.spenderToApprove, hTokenAmount);
            }
        }

        // Prepare deposit info
        DepositMultipleInput memory depositInput =
            DepositMultipleInput({hTokens: hTokens, tokens: underlyingTokens, amounts: amounts, deposits: deposits});

        // GasParams
        GasParams memory gasParams = GasParams(1_250_000, 0 ether);

        uint256 currentNonce = cache.branchBridgeAgent.depositNonce();

        vm.deal(address(this), 10 ether);

        // Empty
        bytes memory emptyPayload = abi.encodePacked(bytes1(0x01), abi.encode(new Call[](0)));

        // deposit multiple assets from branch to Root
        if (cache.callRouter) {
            cache.branchMulticallRouter.callOutAndBridgeMultiple{value: 10 ether}(emptyPayload, depositInput, gasParams);
        } else {
            cache.branchBridgeAgent.callOutSignedAndBridgeMultiple{value: 10 ether}(
                emptyPayload, depositInput, gasParams, false
            );
        }

        assertEq(cache.branchBridgeAgent.depositNonce(), currentNonce + 1);

        Deposit memory deposit = cache.branchBridgeAgent.getDepositEntry(uint32(currentNonce));
        assertEq(deposit.status, STATUS_SUCCESS);
        assertEq(deposit.owner, address(this));
        assertEq(deposit.hTokens.length, _length);
        assertEq(deposit.tokens.length, _length);
        assertEq(deposit.amounts.length, _length);
        assertEq(deposit.deposits.length, _length);
        assertEq(deposit.isSigned, cache.callRouter ? UNSIGNED_DEPOSIT : SIGNED_DEPOSIT);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        // Root tx reverted if the call was not signed because `executeDepositMultiple` is not implemented
        assertEq(
            multicallRootBridgeAgent.executionState(_lzChainId, currentNonce),
            cache.callRouter ? STATUS_READY : STATUS_DONE
        );

        // Check that the tokens were deposited in the virtual account
        if (!cache.callRouter) {
            address virtualAccount = address(rootPort.getUserAccount(address(this)));
            assertNotEq(virtualAccount, address(0));

            for (uint256 i = 0; i < _length; i++) {
                // Can be greater than the deposit amount if there are duplicate entries
                assertGe(
                    MockERC20(globalTokens[i]).balanceOf(virtualAccount),
                    amounts[i],
                    "Virtual account balance should be updated"
                );
            }
        }
    }

    function test_CallOutAndBridgeMultiple_withLocalToken() public {
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);

        MockERC20 underToken0 = new MockERC20("u0 token", "U0", 18);
        MockERC20 underToken1 = new MockERC20("u0 token", "U0", 18);

        vm.deal(address(this), 10 ether);
        avaxCoreRouter.addLocalToken{value: 1 ether}(address(underToken0), GasParams(2_000_000, 0));
        avaxCoreRouter.addLocalToken{value: 1 ether}(address(underToken1), GasParams(2_000_000, 0));

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
        address localTokenUnder0 = rootPort.getLocalTokenFromUnderlying(address(underToken0), avaxChainId);
        address localTokenUnder1 = rootPort.getLocalTokenFromUnderlying(address(underToken1), avaxChainId);

        switchToLzChain(avaxChainId);

        vm.deal(address(this), 50 ether);
        uint256 _amount0 = 2 ether;
        uint256 _amount1 = 2 ether;
        uint256 _deposit0 = 1 ether;
        uint256 _deposit1 = 1 ether;

        // GasParams
        GasParams memory gasParams = GasParams(1_250_000, 0 ether);

        address _recipient = address(this);

        underToken0.mint(_recipient, _deposit0);
        underToken1.mint(_recipient, _deposit1);

        address[] memory hTokens = new address[](2);
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory deposits = new uint256[](2);

        hTokens[0] = localTokenUnder0;
        hTokens[1] = localTokenUnder1;
        tokens[0] = address(underToken0);
        tokens[1] = address(underToken1);
        amounts[0] = _amount0;
        amounts[1] = _amount1;
        deposits[0] = _deposit0;
        deposits[1] = _deposit1;

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        _getLocalhTokensToBranch(
            GetLocalhTokensToBranchParams(
                avaxChainId,
                address(this),
                _recipient,
                hTokens,
                tokens,
                amounts,
                deposits,
                GasParams(2_250_000, 0.1 ether),
                gasParams
            )
        );
    }

    struct GetLocalhTokensToBranchParams {
        uint16 branchChainId;
        address owner;
        address recipient;
        address[] hTokensLocal;
        address[] tokens;
        uint256[] amounts;
        uint256[] deposits;
        GasParams gasParamsFromBranchToRoot;
        GasParams gasParamsFromRootToBranch;
    }

    function _getLocalhTokensToBranch(GetLocalhTokensToBranchParams memory _params) internal {
        address[] memory hTokensGlobal = new address[](_params.hTokensLocal.length);

        for (uint256 i = 0; i < _params.hTokensLocal.length; i++) {
            // Get Global Token
            hTokensGlobal[i] = rootPort.getGlobalTokenFromLocal(_params.hTokensLocal[i], _params.branchChainId);
        }

        uint256[] memory hTokenDesiredBalance = new uint256[](_params.amounts.length);

        for (uint256 i = 0; i < _params.amounts.length; i++) {
            // Get local hToken amount
            hTokenDesiredBalance[i] = _params.amounts[i] - _params.deposits[i];
        }

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);

        OutputMultipleParams memory outputMultipleParams;
        bytes memory routerPayload;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](0);

            {
                uint256[] memory emptyDeposits = new uint256[](_params.amounts.length);

                // Output Params
                outputMultipleParams = OutputMultipleParams(
                    _params.owner, _params.recipient, hTokensGlobal, hTokenDesiredBalance, emptyDeposits
                );
            }

            routerPayload = abi.encodePacked(
                bytes1(0x03),
                abi.encode(calls, outputMultipleParams, _params.branchChainId, _params.gasParamsFromRootToBranch)
            );
        }

        DepositMultipleInput memory depositInput = DepositMultipleInput({
            hTokens: _params.hTokensLocal,
            tokens: _params.tokens,
            amounts: hTokenDesiredBalance,
            deposits: hTokenDesiredBalance
        });

        for (uint256 i = 0; i < _params.tokens.length; i++) {
            // Mint to owner
            MockERC20(_params.tokens[i]).mint(_params.owner, hTokenDesiredBalance[0]);
            // Approve spend by router
            MockERC20(_params.tokens[i]).approve(address(avaxPort), hTokenDesiredBalance[0]);
        }

        avaxMulticallBridgeAgent.callOutSignedAndBridgeMultiple{value: 50 ether}(
            routerPayload, depositInput, _params.gasParamsFromBranchToRoot, false
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }
}
