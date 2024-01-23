//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

contract RootForkNewCoreCouterTest is RootForkSetupTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    CoreRootRouter newCoreRootRouter;
    RootBridgeAgent newCoreRootBridgeAgent;
    ERC20hTokenRootFactory newHTokenRootFactory;

    CoreBranchRouter newFtmCoreBranchRouter;
    BranchBridgeAgent newFtmCoreBranchBridgeAgent;
    ERC20hTokenBranchFactory newFtmHTokenFactory;

    function testSetBranchRouter() public {
        switchToLzChain(rootChainId);

        vm.deal(address(this), 1000 ether);

        // Deploy new root core

        newHTokenRootFactory = new ERC20hTokenRootFactory(address(rootPort));

        newCoreRootRouter = new CoreRootRouter(rootChainId, address(rootPort));

        newCoreRootBridgeAgent =
            RootBridgeAgent(payable(rootBridgeAgentFactory.createBridgeAgent(address(newCoreRootRouter))));

        // Init new root core

        newCoreRootRouter.initialize(address(newCoreRootBridgeAgent), address(newHTokenRootFactory));

        newHTokenRootFactory.initialize(address(newCoreRootRouter));

        switchToLzChain(ftmChainId);

        // Deploy new Branch Core

        newFtmHTokenFactory = new ERC20hTokenBranchFactory(address(ftmPort), "Fantom", "FTM");

        newFtmCoreBranchRouter = new CoreBranchRouter(address(newFtmHTokenFactory));

        newFtmCoreBranchBridgeAgent = new BranchBridgeAgent(
            rootChainId,
            ftmChainId,
            address(newCoreRootBridgeAgent),
            lzEndpointAddressFtm,
            address(newFtmCoreBranchRouter),
            address(ftmPort)
        );

        // Init new branch core

        newFtmCoreBranchRouter.initialize(address(newFtmCoreBranchBridgeAgent));

        newFtmHTokenFactory.initialize(address(ftmWrappedNativeToken), address(newFtmCoreBranchRouter));

        switchToLzChain(rootChainId);

        rootPort.setCoreBranchRouter{value: 1000 ether}(
            address(this),
            address(newFtmCoreBranchRouter),
            address(newFtmCoreBranchBridgeAgent),
            ftmChainId,
            GasParams(200_000, 0)
        );

        switchToLzChain(ftmChainId);

        require(ftmPort.coreBranchRouterAddress() == address(newFtmCoreBranchRouter));
        require(ftmPort.isBridgeAgent(address(newFtmCoreBranchBridgeAgent)));

        ftmCoreRouter = newFtmCoreBranchRouter;
        ftmCoreBridgeAgent = newFtmCoreBranchBridgeAgent;
    }

    function testSetCoreRootRouter() public {
        testSetBranchRouter();

        // @dev Once all branches have been migrated we are ready to set the new root router

        switchToLzChain(rootChainId);

        // newCoreRootRouter = new CoreRootRouter(rootChainId, address(rootPort));

        // newCoreRootBridgeAgent =
        //     RootBridgeAgent(payable(rootBridgeAgentFactory.createBridgeAgent(address(newCoreRootRouter))));

        rootPort.setCoreRootRouter(address(newCoreRootRouter), address(newCoreRootBridgeAgent));

        require(rootPort.coreRootRouterAddress() == address(newCoreRootRouter));
        require(rootPort.coreRootBridgeAgentAddress() == address(newCoreRootBridgeAgent));

        coreRootRouter = newCoreRootRouter;
        coreRootBridgeAgent = newCoreRootBridgeAgent;
    }

    function testSyncNewCoreBranchRouter() public {
        testSetCoreRootRouter();

        // @dev after setting the new root core we can sync each new branch one by one

        rootPort.syncNewCoreBranchRouter(
            address(newFtmCoreBranchRouter), address(newFtmCoreBranchBridgeAgent), ftmChainId
        );

        require(newCoreRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == address(newFtmCoreBranchBridgeAgent));
    }

    MockERC20 newFtmMockUnderlyingToken;
    address newFtmMockAssetLocalToken;
    address newFtmMockGlobalToken;

    function testAddLocalTokenNewCore() public {
        testSyncNewCoreBranchRouter();

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        vm.deal(address(this), 10 ether);

        newFtmMockUnderlyingToken = new MockERC20("UnderTester", "UTST", 6);

        ftmCoreRouter.addLocalToken{value: 10 ether}(address(newFtmMockUnderlyingToken), GasParams(2_000_000, 0));

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        newFtmMockAssetLocalToken = rootPort.getLocalTokenFromUnderlying(address(newFtmMockUnderlyingToken), ftmChainId);

        newFtmMockGlobalToken = rootPort.getGlobalTokenFromLocal(newFtmMockAssetLocalToken, ftmChainId);

        require(
            rootPort.getGlobalTokenFromLocal(newFtmMockAssetLocalToken, ftmChainId) == newFtmMockGlobalToken,
            "Token should be added"
        );
        require(
            rootPort.getLocalTokenFromGlobal(newFtmMockGlobalToken, ftmChainId) == newFtmMockAssetLocalToken,
            "Token should be added"
        );
        require(
            rootPort.getUnderlyingTokenFromLocal(newFtmMockAssetLocalToken, ftmChainId)
                == address(newFtmMockUnderlyingToken),
            "Token should be added"
        );
    }
}
