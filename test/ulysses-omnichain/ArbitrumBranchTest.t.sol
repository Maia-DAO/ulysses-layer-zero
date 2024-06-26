//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./helpers/TestHelper.t.sol";

import "./helpers/RootForkHelper.t.sol";

contract ArbitrumBranchTest is TestHelper {
    using BranchBridgeAgentHelper for BranchBridgeAgent;

    receive() external payable {}

    uint32 nonce;

    MockERC20 avaxNativeAssethToken;

    MockERC20 avaxNativeToken;

    MockERC20 ftmNativeAssethToken;

    MockERC20 ftmNativeToken;

    ERC20hToken arbitrumNativeAssethToken;

    MockERC20 arbitrumNativeToken;

    MockERC20 rewardToken;

    ERC20hToken testToken;

    ERC20hTokenRootFactory hTokenFactory;

    RootPort rootPort;

    CoreRootRouter rootCoreRouter;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent multicallBridgeAgent;

    ArbitrumBranchPort localPortAddress;

    ArbitrumCoreBranchRouter arbitrumCoreRouter;

    BaseBranchRouter arbitrumMulticallRouter;

    ArbitrumBranchBridgeAgent arbitrumCoreBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBridgeAgent;

    ERC20hTokenBranchFactory localHTokenFactory;

    ArbitrumBranchBridgeAgentFactory localBranchBridgeAgentFactory;

    uint16 rootChainId = uint16(42161);

    uint16 avaxChainId = uint16(1088);

    uint16 ftmChainId = uint16(2040);

    address avaxGlobalToken;

    address ftmGlobalToken;

    address wrappedNativeToken;

    address multicallAddress;

    address testGasPoolAddress = address(0xFFFF);

    address nonFungiblePositionManagerAddress = address(0xABAD);

    address avaxLocalWrappedNativeTokenAddress = address(0xBFFF);
    address avaxUnderlyingWrappedNativeTokenAddress = address(0xFFFB);

    address ftmLocalWrappedNativeTokenAddress = address(0xABBB);
    address ftmUnderlyingWrappedNativeTokenAddress = address(0xAAAB);

    address avaxCoreBridgeAgentAddress = address(0xBEEF);

    address avaxMulticallBridgeAgentAddress = address(0xEBFE);

    address avaxPortAddress = address(0xFEEB);

    address ftmCoreBridgeAgentAddress = address(0xCACA);

    address ftmMulticallBridgeAgentAddress = address(0xACAC);

    address ftmPortAddressM = address(0xABAC);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////
        wrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////
        rootPort = new RootPort(rootChainId);

        bridgeAgentFactory = new RootBridgeAgentFactory(rootChainId, lzEndpointAddress, address(rootPort));

        rootCoreRouter = new CoreRootRouter(rootChainId, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        hTokenFactory = new ERC20hTokenRootFactory(address(rootPort));

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////
        rootPort.initialize(address(bridgeAgentFactory), address(rootCoreRouter));

        hTokenFactory.initialize(address(rootCoreRouter));

        coreBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootCoreRouter)))
        );

        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        rootCoreRouter.initialize(address(coreBridgeAgent), address(hTokenFactory));

        rootMulticallRouter.initialize(address(multicallBridgeAgent));

        /////////////////////////////////
        // Deploy Local Branch Contracts//
        /////////////////////////////////

        localPortAddress = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new ArbitrumBaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter();

        localBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId, address(bridgeAgentFactory), address(arbitrumCoreRouter), address(localPortAddress), owner
        );

        localPortAddress.initialize(address(arbitrumCoreRouter), address(localBranchBridgeAgentFactory));

        vm.startPrank(address(arbitrumCoreRouter));

        arbitrumCoreBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(
                    address(arbitrumCoreRouter), address(coreBridgeAgent), address(bridgeAgentFactory)
                )
            )
        );

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(
            payable(
                localBranchBridgeAgentFactory.createBridgeAgent(
                    address(arbitrumMulticallRouter), address(multicallBridgeAgent), address(bridgeAgentFactory)
                )
            )
        );

        vm.stopPrank();

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        ///////////////////////////////////
        //  Sync Root with new branches  //
        ///////////////////////////////////

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(localPortAddress));

        multicallBridgeAgent.approveBranchBridgeAgent(rootChainId);

        coreBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        coreBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        vm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            address(arbitrumMulticallBridgeAgent), address(multicallBridgeAgent), rootChainId
        );

        vm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            avaxCoreBridgeAgentAddress, address(coreBridgeAgent), avaxChainId
        );

        vm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            avaxMulticallBridgeAgentAddress, address(multicallBridgeAgent), avaxChainId
        );

        vm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            ftmCoreBridgeAgentAddress, address(coreBridgeAgent), ftmChainId
        );

        vm.prank(address(rootCoreRouter));
        RootPort(rootPort).syncBranchBridgeAgentWithRoot(
            ftmMulticallBridgeAgentAddress, address(multicallBridgeAgent), ftmChainId
        );

        // Add new chains

        RootPort(rootPort).addNewChain(
            avaxCoreBridgeAgentAddress,
            avaxChainId,
            "Avalanche",
            "AVAX",
            18,
            avaxLocalWrappedNativeTokenAddress,
            avaxUnderlyingWrappedNativeTokenAddress
        );

        RootPort(rootPort).addNewChain(
            ftmCoreBridgeAgentAddress,
            ftmChainId,
            "Fantom Opera",
            "FTM",
            18,
            ftmLocalWrappedNativeTokenAddress,
            ftmUnderlyingWrappedNativeTokenAddress
        );

        avaxGlobalToken = RootPort(rootPort).getGlobalTokenFromLocal(avaxLocalWrappedNativeTokenAddress, avaxChainId);

        ftmGlobalToken = RootPort(rootPort).getGlobalTokenFromLocal(ftmLocalWrappedNativeTokenAddress, ftmChainId);

        // //Ensure there are gas tokens from each chain in the system.
        // vm.startPrank(address(rootPort));
        // ERC20hToken(avaxGlobalToken).mint(address(rootPort), 1 ether);
        // ERC20hToken(ftmGlobalToken).mint(address(rootPort), 1 ether);
        // ERC20hToken(avaxGlobalToken).approve(address(rootPort), 1 ether);
        // ERC20hToken(ftmGlobalToken).approve(address(rootPort), 1 ether);
        // vm.stopPrank();

        // //Update balance
        // vm.startPrank(address(rootBridgeAgent));
        // RootPort(rootPort).bridgeToRoot(address _recipient, address _hToken, uint256 _amount, uint256 _deposit, uint256 _srcChainId)

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxLocalWrappedNativeTokenAddress), avaxChainId)
                == avaxGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(avaxGlobalToken, avaxChainId)
                == address(avaxLocalWrappedNativeTokenAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxLocalWrappedNativeTokenAddress), avaxChainId)
                == address(avaxUnderlyingWrappedNativeTokenAddress),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(ftmLocalWrappedNativeTokenAddress), ftmChainId)
                == ftmGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(ftmGlobalToken, ftmChainId)
                == address(ftmLocalWrappedNativeTokenAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(ftmLocalWrappedNativeTokenAddress), ftmChainId)
                == address(ftmUnderlyingWrappedNativeTokenAddress),
            "Token should be added"
        );

        //////////////////////////////////////
        // Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        rewardToken = new MockERC20("hermes token", "HERMES", 18);

        testToken = new ERC20hToken(address(rootPort), "Hermes Global hToken 1", "hGT1", 18);

        avaxNativeAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxNativeToken = new MockERC20("underlying token", "UNDER", 18);

        ftmNativeAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmNativeToken = new MockERC20("underlying token", "UNDER", 18);

        // arbitrumNativeAssethToken
        arbitrumNativeToken = new MockERC20("underlying token", "UNDER", 18);
    }

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        // Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL", uint8(18));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        // Call Deposit function
        GasParams memory gasParams = GasParams(1 ether, 0.5 ether);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            nonce++,
            packedData,
            gasParams,
            avaxChainId
        );

        newAvaxAssetGlobalAddress =
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId) != address(0),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId)
                == address(avaxNativeAssethToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxNativeAssethToken), avaxChainId)
                == address(avaxNativeToken),
            "Token should be added"
        );
    }

    address public newFtmAssetGlobalAddress;

    function testAddGlobalToken() public {
        // Add Local Token from Avax
        testAddLocalToken();

        //Gas Params
        GasParams memory _gasParams = GasParams(0.5 ether, 0.5 ether);

        //Gas Params
        GasParams[2] memory gasParams = [GasParams(0.5 ether, 0.5 ether), GasParams(0.5 ether, 0.5 ether)];

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newAvaxAssetGlobalAddress, ftmChainId, gasParams);

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        // Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            nonce++,
            packedData,
            _gasParams,
            ftmChainId
        );
        // State change occurs in setLocalToken
    }

    address public newAvaxAssetLocalToken = address(0xFAFA);

    function testSetLocalToken() public {
        // Add Local Token from Avax
        testAddGlobalToken();

        // Encode Data
        bytes memory data = abi.encode(newAvaxAssetGlobalAddress, newAvaxAssetLocalToken, "UnderLocal Coin", "UL");

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        //Gas Params
        GasParams memory _gasParams = GasParams(0.5 ether, 0.5 ether);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            nonce++,
            packedData,
            _gasParams,
            ftmChainId
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(newAvaxAssetLocalToken, ftmChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newAvaxAssetLocalToken), ftmChainId) == address(0),
            "Token should not exist"
        );
    }

    address public newArbitrumAssetGlobalAddress;

    function testAddLocalTokenArbitrum() public {
        // Get some gas.
        vm.deal(address(this), 1 ether);

        //Get gas params
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Add new localToken
        arbitrumCoreRouter.addLocalToken(address(arbitrumNativeToken), gasParams);

        newArbitrumAssetGlobalAddress =
            RootPort(rootPort).getLocalTokenFromUnderlying(address(arbitrumNativeToken), rootChainId);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress, rootChainId)
                == address(newArbitrumAssetGlobalAddress),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newArbitrumAssetGlobalAddress), rootChainId)
                == address(arbitrumNativeToken),
            "Token should be added"
        );
    }

    address public newArbitrumAssetGlobalAddress_2;

    function testAddLocalTokenArbitrum_2() internal {
        // Get some gas.
        vm.deal(address(this), 1 ether);

        //Get gas params
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Add new localToken
        arbitrumCoreRouter.addLocalToken(address(rewardToken), gasParams);

        newArbitrumAssetGlobalAddress_2 =
            RootPort(rootPort).getLocalTokenFromUnderlying(address(rewardToken), rootChainId);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(newArbitrumAssetGlobalAddress_2), rootChainId)
                == address(newArbitrumAssetGlobalAddress_2),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress_2, rootChainId)
                == address(newArbitrumAssetGlobalAddress_2),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newArbitrumAssetGlobalAddress_2), rootChainId)
                == address(rewardToken),
            "Token should be added"
        );
    }

    function testAddLocalTokenArbitrumFailedIsGlobal() public {
        // Get some gas.
        vm.deal(address(this), 1 ether);

        address prevAddress = RootPort(rootPort).getLocalTokenFromUnderlying(address(arbitrumNativeToken), rootChainId);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(arbitrumNativeToken), rootChainId)
                == address(prevAddress),
            "Token should be added"
        );

        //Gas Params
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.expectRevert(abi.encodeWithSignature("ExecutionFailure()"));

        //Add new localToken
        arbitrumCoreRouter.addLocalToken(ftmGlobalToken, gasParams);
    }

    function testAddBridgeAgentArbitrum() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter;
        testMulticallRouter = new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Create Branch Router in FTM
        BaseBranchRouter arbTestRouter = new BaseBranchRouter();

        //Allow new branch from root
        testRootBridgeAgent.approveBranchBridgeAgent(rootChainId);

        //Create Branch Bridge Agent
        rootCoreRouter.addBranchToBridgeAgent{value: 2 ether}(
            address(testRootBridgeAgent),
            address(localBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            rootChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)]
        );

        BranchBridgeAgent arbTestBranchBridgeAgent = BranchBridgeAgent(payable(localPortAddress.bridgeAgents(2)));

        arbTestRouter.initialize(address(arbTestBranchBridgeAgent));

        require(testRootBridgeAgent.getBranchBridgeAgent(rootChainId) == address(arbTestBranchBridgeAgent));
    }

    function testAddBridgeAgentArbitrum_unrecognizedFactory() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        // New router
        BaseBranchRouter arbTestRouter = new BaseBranchRouter();

        // Wrong factory address
        address wrongFactory = address(0x1234);

        // Encode Data
        bytes memory data = abi.encode(
            address(arbTestRouter),
            wrongFactory,
            address(multicallBridgeAgent),
            address(bridgeAgentFactory),
            address(this),
            GasParams(0, 0)
        );

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Call Execute no settlement
        vm.expectRevert(abi.encodeWithSignature("UnrecognizedBridgeAgentFactory()"));
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testAddBridgeAgentArbitrum_unrecognizedBridgeAgent() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        // New router
        BaseBranchRouter arbTestRouter = new BaseBranchRouter();

        // Encode Data
        bytes memory data = abi.encode(
            address(arbTestRouter),
            address(localBranchBridgeAgentFactory),
            address(multicallBridgeAgent),
            address(bridgeAgentFactory),
            address(this),
            GasParams(0, 0)
        );

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        // Mock Call to represent failed Port state update
        vm.mockCall(address(localPortAddress), abi.encodeWithSignature("isBridgeAgent(address)"), abi.encode(false));

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Call Execute no settlement
        vm.expectRevert(abi.encodeWithSignature("UnrecognizedBridgeAgent()"));
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    //////////////////////////////////////
    // EXECUTE NO SETTLEMENT DISPATCHER //
    //////////////////////////////////////

    function testExecuteNoSettlement_toggleBranchBridgeAgentFactory() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(localBranchBridgeAgentFactory));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call toggleBranchBridgeAgentFactory
        vm.expectCall(
            address(localPortAddress),
            abi.encodeWithSignature("toggleBridgeAgentFactory(address)", address(localBranchBridgeAgentFactory))
        );
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testExecuteNoSettlement_toggleStrategyToken() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(arbitrumNativeToken), 7000);

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x04), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call toggleStrategyToken
        vm.expectCall(
            address(localPortAddress),
            abi.encodeWithSignature("toggleStrategyToken(address,uint256)", address(arbitrumNativeToken), 7000)
        );
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testExecuteNoSettlement_updateStrategyToken() public {
        // Add Token
        testExecuteNoSettlement_toggleStrategyToken();

        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(arbitrumNativeToken), 7500);

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x05), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call updateStrategyToken
        vm.expectCall(
            address(localPortAddress),
            abi.encodeWithSignature("updateStrategyToken(address,uint256)", address(arbitrumNativeToken), 7500)
        );
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testExecuteNoSettlement_togglePortStrategy() public {
        // Add strategy token
        testExecuteNoSettlement_updateStrategyToken();

        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(this), address(arbitrumNativeToken), 10 ether, 7000);

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x06), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call togglePortStrategy
        vm.expectCall(
            address(localPortAddress),
            abi.encodeWithSignature(
                "togglePortStrategy(address,address,uint256,uint256)",
                address(this),
                address(arbitrumNativeToken),
                10 ether,
                7000
            )
        );
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testExecuteNoSettlement_updatePortStrategy() public {
        // Add strategy token
        testExecuteNoSettlement_togglePortStrategy();

        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(this), address(arbitrumNativeToken), 10 ether, 7500);

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x07), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call updatePortStrategy
        vm.expectCall(
            address(localPortAddress),
            abi.encodeWithSignature(
                "updatePortStrategy(address,address,uint256,uint256)",
                address(this),
                address(arbitrumNativeToken),
                10 ether,
                7500
            )
        );
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testExecuteNoSettlement_setCoreBranchRouter() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(this), address(9));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x08), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call setCoreBranchRouter
        vm.expectCall(
            address(localPortAddress),
            abi.encodeWithSignature("setCoreBranchRouter(address,address)", address(this), address(9))
        );
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testExecuteNoSettlement_sweep() public {
        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(this), address(9));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x09), data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call sweep
        vm.expectCall(address(localPortAddress), abi.encodeWithSignature("sweep(address)", address(this)));
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    function testFuzzExecuteNoSettlement_expectUnrecognizedFunctionId(bytes1 funcId) public {
        // Treat fuzzed input
        if (uint8(funcId) < 10) funcId = bytes1(0x10);

        //Get some gas
        vm.deal(address(this), 2 ether);

        // Encode Data
        bytes memory data = abi.encode(address(this), address(9));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(funcId, data);

        // Prank into Arb Core Bridge Agent
        vm.prank(address(arbitrumCoreBridgeAgent.bridgeAgentExecutorAddress()));

        // Perform call sweep
        vm.expectRevert(abi.encodeWithSignature("UnrecognizedFunctionId()"));
        arbitrumCoreRouter.executeNoSettlement(packedData);
    }

    /////////////////////////////////
    //   TOKEN DEPOSIT FUNCITONS   //
    /////////////////////////////////

    function testDepositToPort() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Mint Tokens
        arbitrumNativeToken.mint(address(this), 100 ether);

        // Approve Tokens
        arbitrumNativeToken.approve(address(localPortAddress), 100 ether);

        // Call deposit to port
        arbitrumMulticallBridgeAgent.depositToPort(address(arbitrumNativeToken), 100 ether);

        // Test If Deposit was successful
        require(MockERC20(arbitrumNativeToken).balanceOf(address(this)) == 0, "User should have 0 tokens");
        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == 100 ether,
            "Port should have underlying tokens"
        );
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 100 ether,
            "User should have 100 global tokens"
        );
    }

    function testDepositToPortUnrecognized() public {
        // Mint Tokens
        arbitrumNativeToken.mint(address(this), 100 ether);

        // Approve Tokens
        arbitrumNativeToken.approve(address(localPortAddress), 100 ether);

        // Call deposit to port
        vm.expectRevert(abi.encodeWithSignature("UnknownGlobalToken()"));

        arbitrumMulticallBridgeAgent.depositToPort(address(arbitrumNativeToken), 100 ether);
    }

    /////////////////////////////////
    //   TOKEN WITHDRAW FUNCITONS  //
    /////////////////////////////////

    function testWithdrawFromPort() public {
        // Deposit Tokens
        testDepositToPort();

        arbitrumMulticallBridgeAgent.withdrawFromPort(address(newArbitrumAssetGlobalAddress), 100 ether);

        // Test If Deposit was successful
        require(MockERC20(arbitrumNativeToken).balanceOf(address(this)) == 100 ether, "User should have 100 tokens");
        require(MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == 0, "Port should have 0 tokens");
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 0, "User should have 0 global tokens"
        );
    }

    function testWithdrawFromPortUnknownGlobal() public {
        // Deposit Tokens
        testDepositToPort();

        // Call withdraw from port
        vm.expectRevert(abi.encodeWithSignature("UnknownGlobalToken()"));
        arbitrumMulticallBridgeAgent.withdrawFromPort(address(arbitrumNativeToken), 100 ether);
    }

    /////////////////////////////////
    //      CALLOUT FUNCITONS      //
    /////////////////////////////////

    function testCallOutWithDeposit() public {
        // Set up
        testAddLocalTokenArbitrum();

        //Get gas
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newArbitrumAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = rootChainId;

            // RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Get some gas.
        vm.deal(address(this), 1 ether);

        // Mint Underlying Token.
        arbitrumNativeToken.mint(address(this), 100 ether);

        // Approve spend by router
        arbitrumNativeToken.approve(address(localPortAddress), 100 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);

        BranchBridgeAgent(arbitrumMulticallBridgeAgent)._testCreateDepositSingle(
            uint32(1),
            address(this),
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumNativeToken),
            100 ether,
            100 ether
        );

        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == 50 ether,
            "LocalPort should have 50 tokens"
        );

        require(MockERC20(arbitrumNativeToken).balanceOf(address(this)) == 50 ether, "User should have 50 tokens");

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 49 ether,
            "User should have 50 global tokens"
        );
    }

    function testCallOutWithDepositUsingRouter() public {
        // Set up
        testAddLocalTokenArbitrum();

        //Get gas
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newArbitrumAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = rootChainId;

            // RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address user = address(this);

        // // Assure there are assets after mock action
        // vm.startPrank(address(rootPort));
        // ERC20hToken(newArbitrumAssetGlobalAddress).mint(address(rootPort), 50 ether);
        // vm.stopPrank();

        // vm.startPrank(address(multicallBridgeAgent));
        // ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 50 ether);
        // rootPort.bridgeToBranch(user, newArbitrumAssetGlobalAddress, 50 ether, 0, rootChainId);
        // vm.stopPrank();

        // Assure there are assets after mock action
        vm.startPrank(address(rootPort));
        ERC20hToken(newArbitrumAssetGlobalAddress).mint(user, 50 ether);
        vm.stopPrank();

        // Get some gas.
        vm.deal(address(this), 1 ether);

        // Mint Underlying Token.
        arbitrumNativeToken.mint(address(this), 100 ether);

        // Approve spend by router
        arbitrumNativeToken.approve(address(arbitrumMulticallRouter), 100 ether);
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(arbitrumMulticallRouter), 50 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        vm.mockCall(
            address(rootMulticallRouter),
            abi.encodeWithSignature("executeDepositSingle(bytes,(uint32,address,address,uint256,uint256),uint16)"),
            abi.encode(0)
        );

        //Call Deposit function
        arbitrumMulticallRouter.callOutAndBridge{value: 1 ether}(packedData, depositInput, gasParams);

        BranchBridgeAgent(arbitrumMulticallBridgeAgent)._testCreateDepositSingle(
            uint32(1),
            address(this),
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumNativeToken),
            150 ether,
            100 ether
        );

        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == 100 ether,
            "LocalPort should have 100 tokens"
        );

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootMulticallRouter)) == 150 ether,
            "rootMulticallRouter should have 150 global tokens"
        );
    }

    function testCallOutFailedTriggerFallbackDestinationArbitrumBranch_executeNoSettlementShouldRevert() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Store user
        address user = address(this);

        // Store multicallBridgeAgent settlement nonce
        uint32 settlementNonce = multicallBridgeAgent.settlementNonce();

        //Get gas
        GasParams memory gasParams = GasParams(5_000_000, 0);

        // Prank into rootMulticallRouter
        vm.startPrank(address(rootMulticallRouter));

        // Approve spend by router
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 100 ether);

        //Call Deposit function with Fallback on
        multicallBridgeAgent.callOut(payable(user), user, rootChainId, "should fail", gasParams);

        // Check if settlement is set to failure
        require(multicallBridgeAgent.settlementNonce() == settlementNonce + 1, "Settlement nonce should be incremented");
        require(
            multicallBridgeAgent.getSettlementEntry(settlementNonce).status == STATUS_SUCCESS,
            "Settlement should be success"
        );

        // Check arb branch bridge agent execution status on destination
        require(
            arbitrumMulticallBridgeAgent.executionState(settlementNonce) == STATUS_READY,
            "Settlement should not be successfull"
        );
    }

    function testCallOutWithDepositFailedTriggerFallbackDestinationArbitrumBranch() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Store user
        address user = address(this);

        // Store multicallBridgeAgent settlement nonce
        uint32 settlementNonce = multicallBridgeAgent.settlementNonce();

        //Get gas
        GasParams memory gasParams = GasParams(5_000_000, 0);

        // Prank into rootPort
        vm.prank(address(rootPort));

        // Mint Underlying Token.
        ERC20hToken(newArbitrumAssetGlobalAddress).mint(address(rootMulticallRouter), 100 ether);

        // Prank into rootMulticallRouter
        vm.startPrank(address(rootMulticallRouter));

        // Approve spend by router
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 100 ether);

        //Call Deposit function with Fallback on
        multicallBridgeAgent.callOutAndBridge(
            payable(user),
            user,
            rootChainId,
            "should fail",
            SettlementInput(newArbitrumAssetGlobalAddress, 100 ether, 0),
            gasParams,
            true
        );

        // Check if settlement is set to failure
        require(multicallBridgeAgent.settlementNonce() == settlementNonce + 1, "Settlement nonce should be incremented");
        require(multicallBridgeAgent.getSettlementEntry(settlementNonce).status == 1, "Settlement should be failed");
    }

    function testCallOutWithDepositMultipleFailedTriggerFallbackDestinationArbitrumBranch() public {
        // Set up
        testAddLocalTokenArbitrum();
        testAddLocalTokenArbitrum_2();

        // Store user
        address user = address(this);

        // Store multicallBridgeAgent settlement nonce
        uint32 settlementNonce = multicallBridgeAgent.settlementNonce();

        //Get gas
        GasParams memory gasParams = GasParams(5_000_000, 0);

        // Prank into rootPort
        vm.startPrank(address(rootPort));

        // Mint Underlying Token.
        ERC20hToken(newArbitrumAssetGlobalAddress_2).mint(address(rootMulticallRouter), 100 ether);
        ERC20hToken(newArbitrumAssetGlobalAddress).mint(address(rootMulticallRouter), 100 ether);

        vm.stopPrank();

        // Prank into rootMulticallRouter
        vm.startPrank(address(rootMulticallRouter));

        // Approve spend by router
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 100 ether);
        ERC20hToken(newArbitrumAssetGlobalAddress_2).approve(address(rootPort), 100 ether);

        // Create input arrays
        address[] memory tokens = new address[](2);
        tokens[0] = newArbitrumAssetGlobalAddress;
        tokens[1] = newArbitrumAssetGlobalAddress_2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100 ether;
        amounts[1] = 100 ether;

        uint256[] memory deposits = new uint256[](2);
        deposits[0] = 0;
        deposits[1] = 0;

        //Call Deposit function with Fallback on
        multicallBridgeAgent.callOutAndBridgeMultiple(
            payable(user),
            user,
            rootChainId,
            "should fail",
            SettlementMultipleInput(tokens, amounts, deposits),
            gasParams,
            true
        );

        // Check if settlement is set to failure
        require(multicallBridgeAgent.settlementNonce() == settlementNonce + 1, "Settlement nonce should be incremented");
        require(multicallBridgeAgent.getSettlementEntry(settlementNonce).status == 1, "Settlement should be failed");
    }

    function testCallOutWithDepositFailedTriggerFallbackDestinationArbitrumBranchWithRootExecutionFailure() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Store user
        address user = address(this);

        // Store multicallBridgeAgent settlement nonce
        uint32 settlementNonce = multicallBridgeAgent.settlementNonce();

        //Get gas
        GasParams memory gasParams = GasParams(5_000_000, 0);

        // Mock Call to RootBridgeAgent
        vm.mockCall(
            address(multicallBridgeAgent),
            abi.encodeWithSignature(
                "lzReceive(uint16,bytes,uint64,bytes)",
                rootChainId,
                "",
                0,
                abi.encodePacked(bytes1(0x09), settlementNonce)
            ),
            abi.encode(false)
        );

        // Prank into rootPort
        vm.prank(address(rootPort));

        // Mint Underlying Token.
        ERC20hToken(newArbitrumAssetGlobalAddress).mint(address(rootMulticallRouter), 100 ether);

        // Prank into rootMulticallRouter
        vm.startPrank(address(rootMulticallRouter));

        // Approve spend by router
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 100 ether);

        // Can´t Expect ExecutionFailure Error since it is caught
        // vm.expectRevert(abi.encodeWithSignature("ExecutionFailure()"));

        //Call Deposit function with Fallback on
        multicallBridgeAgent.callOutAndBridge(
            payable(user),
            user,
            rootChainId,
            "should fail",
            SettlementInput(newArbitrumAssetGlobalAddress, 100 ether, 0),
            gasParams,
            true
        );

        // Check if settlement is set to failure
        require(multicallBridgeAgent.settlementNonce() == settlementNonce + 1, "Settlement nonce should be incremented");
        require(multicallBridgeAgent.getSettlementEntry(settlementNonce).status == 0, "Settlement should be success");
    }

    function testCallOutWithDepositWithHTokens() public {
        // Set up
        testCallOutWithDeposit();

        //Get gas
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 98 ether;
            depositOut = 98 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newArbitrumAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = rootChainId;

            // RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Get some gas.
        vm.deal(address(this), 1 ether);

        // Approve spend by router
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 49 ether);

        // Approve spend by router
        arbitrumNativeToken.approve(address(localPortAddress), 50 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
            amount: 99 ether,
            deposit: 50 ether
        });

        // Round 2

        //Call Deposit function
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);

        BranchBridgeAgent(arbitrumMulticallBridgeAgent)._testCreateDepositSingle(
            uint32(2),
            address(this),
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumNativeToken),
            99 ether,
            50 ether
        );

        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == 2 ether,
            "LocalPort should have 2 tokens difference"
        );

        require(MockERC20(arbitrumNativeToken).balanceOf(address(this)) == 98 ether, "User should have 98 tokens");

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 0, "User should have spent all hTokens"
        );
    }

    function testCallOutWithDepositExecutionFailed() public {
        // Set up
        testAddLocalTokenArbitrum();

        //Get gas
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newArbitrumAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = rootChainId;

            // RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, dstChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Get some gas.
        vm.deal(address(this), 1 ether);

        // Mint Underlying Token.
        arbitrumNativeToken.mint(address(this), 100 ether);

        // Approve spend by router
        arbitrumNativeToken.approve(address(localPortAddress), 100 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        vm.expectRevert(abi.encodeWithSignature("ExecutionFailure()"));
        //Call Deposit function
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);
    }

    function testFuzzCallOutWithDeposit() public {
        testFuzzCallOutWithDeposit(address(this), 100 ether, 100 ether, 100 ether, 50 ether);
    }

    function testFuzzCallOutWithDeposit(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) public {
        // Set up
        testAddLocalTokenArbitrum();

        (_user, _amount, _deposit, _amountOut, _depositOut) =
            BranchBridgeAgentHelper.adjustValues(_user, _amount, _deposit, _amountOut, _depositOut);

        //Gas Params
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newArbitrumAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(_user, _user, newArbitrumAssetGlobalAddress, _amountOut, _depositOut);

            // RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, rootChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Get some gas.
        vm.deal(_user, 1 ether);

        if (_amount - _deposit > 0) {
            // Assure there is enough balance for mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(newArbitrumAssetGlobalAddress).mint(_user, _amount - _deposit);
            vm.stopPrank();
            arbitrumNativeToken.mint(address(localPortAddress), _amount - _deposit);
        }

        // Mint Underlying Token.
        if (_deposit > 0) arbitrumNativeToken.mint(_user, _deposit);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumNativeToken),
            amount: _amount,
            deposit: _deposit
        });

        // Mock token decimals call
        vm.mockCall(address(arbitrumNativeToken), abi.encodeWithSignature("decimals()"), abi.encode(18));

        // Call Deposit function
        vm.startPrank(_user);
        arbitrumNativeToken.approve(address(localPortAddress), _deposit);
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);
        vm.stopPrank();

        BranchBridgeAgent(arbitrumMulticallBridgeAgent)._testCreateDepositSingle(
            uint32(1), _user, address(newArbitrumAssetGlobalAddress), address(arbitrumNativeToken), _amount, _deposit
        );

        address userAccount = address(RootPort(rootPort).getUserAccount(_user));
        require(
            MockERC20(arbitrumNativeToken).balanceOf(address(localPortAddress)) == _amount - _depositOut,
            "LocalPort tokens"
        );

        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        require(MockERC20(arbitrumNativeToken).balanceOf(_user) == _depositOut, "User tokens");

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == _amountOut - _depositOut, "User Global tokens"
        );

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount) == _amount - _amountOut,
            "User Account tokens"
        );
    }

    function testRetrySettlementRevert() public {
        vm.expectRevert();

        arbitrumMulticallBridgeAgent.retrySettlement(
            1, "", [GasParams(1 ether, 0.5 ether), GasParams(1 ether, 0.5 ether)], true
        );
    }
}
