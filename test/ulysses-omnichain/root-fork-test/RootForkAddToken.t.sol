//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

// The functions in this contract are defined with internal visibility
// so that the RunTest contract can make them public and avoid running the tests twice.
contract RootForkAddTokenTest is RootForkSetupTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    //////////////////////////////////////
    //          TOKEN MANAGEMENT        //
    //////////////////////////////////////

    function _testAddLocalToken() public {
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);

        vm.deal(address(this), 10 ether);

        avaxCoreRouter.addLocalToken{value: 10 ether}(address(avaxMockAssetToken), GasParams(2_000_000, 0));

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        avaxMockAssethToken = rootPort.getLocalTokenFromUnderlying(address(avaxMockAssetToken), avaxChainId);

        newAvaxAssetGlobalAddress = rootPort.getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId);

        require(
            rootPort.getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            rootPort.getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId) == avaxMockAssethToken,
            "Token should be added"
        );
        require(
            rootPort.getUnderlyingTokenFromLocal(avaxMockAssethToken, avaxChainId) == address(avaxMockAssetToken),
            "Token should be added"
        );
    }

    function _testAddGlobalTokenFork() public {
        //Add Local Token from Avax
        _testAddLocalToken();

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);

        vm.deal(address(this), 1000 ether);

        GasParams[3] memory gasParams =
            [GasParams(15_000_000, 0.1 ether), GasParams(2_000_000, 3 ether), GasParams(200_000, 0)];

        avaxCoreRouter.addGlobalToken{value: 1000 ether}(newAvaxAssetGlobalAddress, ftmChainId, gasParams);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        newAvaxAssetFtmLocalToken = rootPort.getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId);

        require(newAvaxAssetFtmLocalToken != address(0), "Failed is zero");

        require(
            rootPort.getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetFtmLocalToken,
            "Token should be added"
        );

        require(
            rootPort.getUnderlyingTokenFromLocal(newAvaxAssetFtmLocalToken, ftmChainId) == address(0),
            "Underlying should not be added"
        );
    }

    function _testAddLocalTokenArbitrum() public {
        //Set up
        _testAddGlobalTokenFork();

        //Get some gas.
        vm.deal(address(this), 1 ether);

        //Add new localToken
        arbitrumCoreBranchRouter.addLocalToken{value: 0.0005 ether}(
            address(arbitrumMockToken), GasParams(0.5 ether, 0.5 ether)
        );

        newArbitrumAssetGlobalAddress = rootPort.getLocalTokenFromUnderlying(address(arbitrumMockToken), rootChainId);

        require(
            rootPort.getGlobalTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            rootPort.getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress, rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            rootPort.getUnderlyingTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(arbitrumMockToken),
            "Token should be added"
        );
    }
}

contract RootForkAddTokenRunTest is RootForkAddTokenTest {
    function testAddLocalToken() public {
        _testAddLocalToken();
    }

    function testAddGlobalTokenFork() public {
        _testAddGlobalTokenFork();
    }

    function testAddLocalTokenArbitrum() public {
        _testAddLocalTokenArbitrum();
    }
}
