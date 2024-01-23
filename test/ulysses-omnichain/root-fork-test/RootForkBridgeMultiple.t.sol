//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

contract RootForkBridgeMultipleTest is RootForkSetupTest {
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

    function _test_CallOutAndBridgeMultiple_withLocalToken(
        address[] memory hTokens,
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory deposits,
        GasParams memory gasParams
    ) public {
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);

        // Prepare deposit info
        DepositMultipleInput memory depositInput =
            DepositMultipleInput({hTokens: hTokens, tokens: tokens, amounts: amounts, deposits: deposits});

        for (uint256 i = 0; i < tokens.length; i++) {
            MockERC20(tokens[i]).approve(address(avaxMulticallRouter), deposits[i]);
        }

        vm.deal(address(this), 50 ether);
        // deposit multiple assets from Avax branch to Root
        // Attempting to deposit two hTokens and two underlyingTokens
        avaxMulticallRouter.callOutAndBridgeMultiple{value: 1 ether}(bytes(""), depositInput, gasParams);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
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
