//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

contract RootForkBridgeAgentFactoryTest is RootForkSetupTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    //////////////////////////////////////
    //        Bridge Agent Factory     //
    //////////////////////////////////////

    RootBridgeAgentFactory newRootBridgeAgentFactory;

    BranchBridgeAgentFactory newFtmBranchBridgeAgentFactory;

    function testAddBridgeAgentFactory() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        // Add new Root Bridge Agent Factory
        newRootBridgeAgentFactory = newRootBridgeAgentFactory._deploy(rootChainId, lzEndpointAddress, rootPort);

        // Enable new Factory in Root
        rootPort.toggleBridgeAgentFactory(address(newRootBridgeAgentFactory));

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        // Add new Branch Bridge Agent Factory
        newFtmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(newRootBridgeAgentFactory),
            lzEndpointAddressFtm,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        // Enable new Factory in Branch
        coreRootRouter.toggleBranchBridgeAgentFactory{value: 1 ether}(
            address(newRootBridgeAgentFactory),
            address(newFtmBranchBridgeAgentFactory),
            address(this),
            ftmChainId,
            GasParams(200_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Factory not enabled");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    function testAddBridgeAgentFactoryNotRootFactory() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        // Add new Root Bridge Agent Factory
        newRootBridgeAgentFactory = newRootBridgeAgentFactory._deploy(rootChainId, lzEndpointAddress, rootPort);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        // Add new Branch Bridge Agent Factory
        newFtmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(newRootBridgeAgentFactory),
            lzEndpointAddressFtm,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        vm.expectRevert(abi.encodeWithSignature("UnrecognizedBridgeAgentFactory()"));

        // Add new Factory to Branch
        coreRootRouter.toggleBranchBridgeAgentFactory{value: 1 ether}(
            address(newRootBridgeAgentFactory),
            address(newFtmBranchBridgeAgentFactory),
            address(this),
            ftmChainId,
            GasParams(200_000, 0)
        );
    }

    RootBridgeAgentFactory newRootBridgeAgentFactory_2;

    BranchBridgeAgentFactory newFtmBranchBridgeAgentFactory_2;

    function testAddTwoBridgeAgentFactories() public {
        // Add first factory
        testAddBridgeAgentFactory();

        //Get some gas
        vm.deal(address(this), 1 ether);

        // Add new Root Bridge Agent Factory
        newRootBridgeAgentFactory_2 = newRootBridgeAgentFactory_2._deploy(rootChainId, lzEndpointAddress, rootPort);

        // Enable new Factory in Root
        rootPort.toggleBridgeAgentFactory(address(newRootBridgeAgentFactory_2));

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        // Add new Branch Bridge Agent Factory
        newFtmBranchBridgeAgentFactory_2 = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(newRootBridgeAgentFactory_2),
            lzEndpointAddressFtm,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        coreRootRouter.toggleBranchBridgeAgentFactory{value: 1 ether}(
            address(newRootBridgeAgentFactory_2),
            address(newFtmBranchBridgeAgentFactory_2),
            address(this),
            ftmChainId,
            GasParams(200_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Factory not enabled");
        require(ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory_2)), "Factory not enabled");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    function testRemoveBridgeAgentFactory() public {
        //Add Factory
        testAddBridgeAgentFactory();

        //Get some gas
        vm.deal(address(this), 1 ether);

        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);
        address factoryToRemove = address(newFtmBranchBridgeAgentFactory);
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        coreRootRouter.toggleBranchBridgeAgentFactory{value: 1 ether}(
            address(rootBridgeAgentFactory), factoryToRemove, address(this), ftmChainId, GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(!ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Should be disabled");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    //////////////////////////////////////
    //           Bridge Agents          //
    //////////////////////////////////////

    function testAddBridgeAgentSimple() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            rootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        //Create Branch Router in FTM
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);
        BaseBranchRouter ftmTestRouter;
        ftmTestRouter = ftmTestRouter._deploy();
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        //Allow new branch from root
        testRootBridgeAgent._approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            ftmBranchBridgeAgentFactory,
            BaseBranchRouter(address(testMulticallRouter)),
            address(this),
            ftmChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)],
            2 ether
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        BranchBridgeAgent ftmTestBranchBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(2)));

        ftmTestRouter.initialize(address(ftmTestBranchBridgeAgent));

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        require(testRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == address(ftmTestBranchBridgeAgent));
    }

    function testAddBridgeAgentArbitrum() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            rootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        //Create Branch Router in FTM
        BaseBranchRouter arbTestRouter = new ArbitrumBaseBranchRouter();

        //Allow new branch from root
        testRootBridgeAgent._approveBranchBridgeAgent(rootChainId);

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            arbitrumBranchBridgeAgentFactory,
            BaseBranchRouter(address(testMulticallRouter)),
            address(this),
            rootChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)],
            2 ether
        );

        BranchBridgeAgent arbTestBranchBridgeAgent = BranchBridgeAgent(payable(arbitrumPort.bridgeAgents(2)));

        arbTestRouter._init(arbTestBranchBridgeAgent, arbitrumPort);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        require(testRootBridgeAgent.getBranchBridgeAgent(rootChainId) == address(arbTestBranchBridgeAgent));
    }

    function testAddBridgeAgentAlreadyAdded() public {
        testAddBridgeAgentSimple();

        //Get some gas
        vm.deal(address(this), 1 ether);

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("AlreadyAddedBridgeAgent()"));

        //Allow new branch
        testRootBridgeAgent._approveBranchBridgeAgent(ftmChainId);
    }

    function testAddBridgeAgentTwoTimes() public {
        testAddBridgeAgentSimple();

        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("InvalidChainId()"));

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            ftmBranchBridgeAgentFactory,
            BaseBranchRouter(address(testMulticallRouter)),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)],
            0.05 ether
        );
    }

    function testAddBridgeAgentNotApproved() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            rootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        vm.expectRevert(abi.encodeWithSignature("UnauthorizedChainId()"));

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            ftmBranchBridgeAgentFactory,
            BaseBranchRouter(address(testMulticallRouter)),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)],
            0.05 ether
        );
    }

    function testAddBridgeAgentNotManager() public {
        //Get some gas
        vm.deal(address(89), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            rootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        vm.startPrank(address(89));

        vm.expectRevert(abi.encodeWithSignature("UnauthorizedCallerNotManager()"));
        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            ftmBranchBridgeAgentFactory,
            BaseBranchRouter(address(testMulticallRouter)),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)],
            0.05 ether
        );
    }

    address newFtmBranchBridgeAgent;

    function testAddBridgeAgentNewFactory() public {
        testAddBridgeAgentFactory();

        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            newRootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        //Allow new branch
        testRootBridgeAgent._approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            newFtmBranchBridgeAgentFactory,
            BaseBranchRouter(address(testMulticallRouter)),
            address(this),
            ftmChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)],
            1 ether
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        newFtmBranchBridgeAgent = ftmPort.bridgeAgents(2);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        require(
            testRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == newFtmBranchBridgeAgent,
            "Branch Bridge Agent should be created"
        );
    }

    function testAddBridgeAgentWrongBranchFactory() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            rootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        //Allow new branch
        testRootBridgeAgent._approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            BranchBridgeAgentFactory(address(32)),
            BaseBranchRouter(address(testMulticallRouter)),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)],
            0.05 ether
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    function testAddBridgeAgentWrongRootFactory() public {
        testAddBridgeAgentFactory();

        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = testMulticallRouter._deploy(rootChainId, rootPort, multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent =
            rootBridgeAgentFactory._createRootBridgeAgent(address(testMulticallRouter));

        //Initialize Router
        testMulticallRouter._init(testRootBridgeAgent);

        //Allow new branch
        testRootBridgeAgent._approveBranchBridgeAgent(ftmChainId);

        // Get wrong factory
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        address branchBridgeAgentFactory = address(newFtmBranchBridgeAgentFactory);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        //Create Branch Bridge Agent
        coreRootRouter._addBranchToBridgeAgent(
            testRootBridgeAgent,
            BranchBridgeAgentFactory(branchBridgeAgentFactory),
            BaseBranchRouter(address(testMulticallRouter)),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)],
            1 ether
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }
}
