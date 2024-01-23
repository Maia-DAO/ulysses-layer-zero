//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "../helpers/RootForkHelper.t.sol";

pragma solidity ^0.8.0;

contract RootForkSetupTest is LzForkTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    // Consts

    //Arb
    uint16 constant rootChainId = uint16(110);

    //Avax
    uint16 constant avaxChainId = uint16(106);

    //Ftm
    uint16 constant ftmChainId = uint16(112);

    //// System contracts

    // Root

    RootPort rootPort;

    ERC20hTokenRootFactory hTokenRootFactory;

    RootBridgeAgentFactory rootBridgeAgentFactory;

    RootBridgeAgent coreRootBridgeAgent;

    RootBridgeAgent multicallRootBridgeAgent;

    CoreRootRouter coreRootRouter;

    MulticallRootRouter rootMulticallRouter;

    // Arbitrum Branch

    ArbitrumBranchPort arbitrumPort;

    ArbitrumBranchBridgeAgentFactory arbitrumBranchBridgeAgentFactory;

    ArbitrumBranchBridgeAgent arbitrumCoreBranchBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBranchBridgeAgent;

    ArbitrumCoreBranchRouter arbitrumCoreBranchRouter;

    BaseBranchRouter arbitrumMulticallRouter;

    // Avax Branch

    BranchPort avaxPort;

    ERC20hTokenBranchFactory avaxHTokenFactory;

    BranchBridgeAgentFactory avaxBranchBridgeAgentFactory;

    BranchBridgeAgent avaxCoreBridgeAgent;

    BranchBridgeAgent avaxMulticallBridgeAgent;

    CoreBranchRouter avaxCoreRouter;

    BaseBranchRouter avaxMulticallRouter;

    // Ftm Branch

    BranchPort ftmPort;

    ERC20hTokenBranchFactory ftmHTokenFactory;

    BranchBridgeAgentFactory ftmBranchBridgeAgentFactory;

    BranchBridgeAgent ftmCoreBridgeAgent;

    BranchBridgeAgent ftmMulticallBridgeAgent;

    CoreBranchRouter ftmCoreRouter;

    BaseBranchRouter ftmMulticallRouter;

    // ERC20s from different chains.

    address avaxMockAssethToken;

    MockERC20 avaxMockAssetToken;

    address ftmMockAssethToken;

    MockERC20 ftmMockAssetToken;

    ERC20hToken arbitrumMockAssethToken;

    MockERC20 arbitrumMockToken;

    // Mocks

    address arbitrumGlobalToken;
    address avaxGlobalToken;
    address ftmGlobalToken;

    address avaxWrappedNativeToken;
    address ftmWrappedNativeToken;

    address avaxLocalWrappedNativeToken;
    address ftmLocalWrappedNativeToken;

    address multicallAddress;

    address nonFungiblePositionManagerAddress = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address lzEndpointAddress = address(0x3c2269811836af69497E5F486A85D7316753cf62);
    address lzEndpointAddressAvax = address(0x3c2269811836af69497E5F486A85D7316753cf62);
    address lzEndpointAddressFtm = address(0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);

    address owner = address(this);

    address dao = address(this);

    // For specific tests

    address public newAvaxAssetGlobalAddress;

    address public newFtmAssetGlobalAddress;

    address public newAvaxAssetFtmLocalToken;

    address public mockApp = address(0xDAFA);

    address public newArbitrumAssetGlobalAddress;

    function setUp() public override {
        /////////////////////////////////
        //         Fork Setup          //
        /////////////////////////////////

        // Set up default fork chains
        setUpDefaultLzChains();

        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////

        _deployRoot();

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////

        _initRoot();

        /////////////////////////////////
        //Deploy Local Branch Contracts//
        /////////////////////////////////

        _deployLocalBranch();

        //////////////////////////////////
        // Deploy Avax Branch Contracts //
        //////////////////////////////////

        _deployAvaxBranch();

        //////////////////////////////////
        // Deploy Ftm Branch Contracts //
        //////////////////////////////////

        _deployFtmBranch();

        /////////////////////////////
        //  Add new branch chains  //
        /////////////////////////////

        _addNewBranchChainsToRoot();

        ///////////////////////////////////
        //  Approve new Branches in Root  //
        ///////////////////////////////////

        _approveNewBranchesInRoot();

        ///////////////////////////////////////
        //  Add new branches to  Root Agents //
        ///////////////////////////////////////

        _addNewBranchesToRootAgents();

        /////////////////////////////////////
        //  Initialize new Branch Routers  //
        /////////////////////////////////////

        _initNewBranchRouters();

        //////////////////////////////////////
        //Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        _deployUnderlyingTokensAndMocks();
    }

    function _deployRoot() internal {
        (rootPort, rootBridgeAgentFactory, hTokenRootFactory, coreRootRouter, rootMulticallRouter) =
            RootForkHelper._deployRoot(rootChainId, lzEndpointAddress, multicallAddress);
    }

    function _initRoot() internal {
        (coreRootBridgeAgent, multicallRootBridgeAgent) = RootForkHelper._initRoot(
            rootPort, rootBridgeAgentFactory, hTokenRootFactory, coreRootRouter, rootMulticallRouter
        );
    }

    function _deployLocalBranch() internal {
        (
            arbitrumPort,
            arbitrumMulticallRouter,
            arbitrumCoreBranchRouter,
            arbitrumBranchBridgeAgentFactory,
            arbitrumCoreBranchBridgeAgent
        ) = RootForkHelper._deployLocalBranch(rootChainId, rootPort, owner, rootBridgeAgentFactory, coreRootBridgeAgent);
    }

    function _deployAvaxBranch() internal {
        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        (
            avaxPort,
            avaxHTokenFactory,
            avaxCoreRouter,
            avaxWrappedNativeToken,
            avaxBranchBridgeAgentFactory,
            avaxMulticallRouter
        ) = RootForkHelper._deployBranch(
            "Avalanche Ulysses ",
            "avax-u",
            rootChainId,
            avaxChainId,
            owner,
            rootBridgeAgentFactory,
            lzEndpointAddressAvax
        );

        (avaxCoreBridgeAgent, avaxLocalWrappedNativeToken) = RootForkHelper._initBranch(
            coreRootBridgeAgent,
            avaxWrappedNativeToken,
            avaxPort,
            avaxHTokenFactory,
            avaxCoreRouter,
            avaxBranchBridgeAgentFactory
        );
    }

    function _deployFtmBranch() internal {
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        (
            ftmPort,
            ftmHTokenFactory,
            ftmCoreRouter,
            ftmWrappedNativeToken,
            ftmBranchBridgeAgentFactory,
            ftmMulticallRouter
        ) = RootForkHelper._deployBranch(
            "Fantom Ulysses ", "ftm-u", rootChainId, ftmChainId, owner, rootBridgeAgentFactory, lzEndpointAddressFtm
        );

        (ftmCoreBridgeAgent, ftmLocalWrappedNativeToken) = RootForkHelper._initBranch(
            coreRootBridgeAgent,
            ftmWrappedNativeToken,
            ftmPort,
            ftmHTokenFactory,
            ftmCoreRouter,
            ftmBranchBridgeAgentFactory
        );
    }

    function _addNewBranchChainsToRoot() internal {
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        avaxGlobalToken = RootForkHelper._addNewBranchChainToRoot(
            rootPort,
            avaxCoreBridgeAgent,
            avaxChainId,
            "Avalanche",
            "AVAX",
            18,
            avaxLocalWrappedNativeToken,
            avaxWrappedNativeToken,
            hTokenRootFactory
        );

        ftmGlobalToken = RootForkHelper._addNewBranchChainToRoot(
            rootPort,
            ftmCoreBridgeAgent,
            ftmChainId,
            "Fantom Opera",
            "FTM",
            18,
            ftmLocalWrappedNativeToken,
            ftmWrappedNativeToken,
            hTokenRootFactory
        );
    }

    function _approveNewBranchesInRoot() internal {
        rootPort._initCore(coreRootBridgeAgent, arbitrumCoreBranchBridgeAgent, arbitrumPort);

        multicallRootBridgeAgent._approveBranchBridgeAgent(rootChainId);

        multicallRootBridgeAgent._approveBranchBridgeAgent(avaxChainId);

        multicallRootBridgeAgent._approveBranchBridgeAgent(ftmChainId);
    }

    function _addNewBranchesToRootAgents() internal {
        // Start the recorder necessary for packet tracking
        vm.recordLogs();

        vm.deal(address(this), 100 ether);

        coreRootRouter._addBranchToBridgeAgent(
            multicallRootBridgeAgent,
            avaxBranchBridgeAgentFactory,
            avaxMulticallRouter,
            address(this),
            avaxChainId,
            [GasParams(6_000_000, 10 ether), GasParams(1_000_000, 0)],
            10 ether
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        vm.deal(address(this), 100 ether);

        coreRootRouter._addBranchToBridgeAgent(
            multicallRootBridgeAgent,
            ftmBranchBridgeAgentFactory,
            ftmMulticallRouter,
            address(this),
            ftmChainId,
            [GasParams(6_000_000, 15 ether), GasParams(1_000_000, 0)],
            10 ether
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);

        coreRootRouter._addBranchToBridgeAgent(
            multicallRootBridgeAgent,
            arbitrumBranchBridgeAgentFactory,
            arbitrumMulticallRouter,
            address(this),
            rootChainId,
            [GasParams(0, 0), GasParams(0, 0)],
            0
        );
    }

    function _initNewBranchRouters() internal {
        arbitrumMulticallBranchBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(1)));
        arbitrumMulticallRouter._init(arbitrumMulticallBranchBridgeAgent, arbitrumPort);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);
        avaxMulticallBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(1)));
        avaxMulticallRouter._init(avaxMulticallBridgeAgent, avaxPort);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        ftmMulticallBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(1)));
        ftmMulticallRouter._init(ftmMulticallBridgeAgent, ftmPort);
    }

    function _deployUnderlyingTokensAndMocks() internal {
        // Switch Chain and Execute Incoming Packets
        switchToLzChain(avaxChainId);
        // avaxMockAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);
        // ftmMockAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
        //arbitrumMockAssethToken is global
        arbitrumMockToken = new MockERC20("underlying token", "UNDER", 18);
    }

    uint32 prevNonceRoot;

    function _updateRootNonce(RootBridgeAgent bridgeAgent) internal {
        prevNonceRoot = bridgeAgent.settlementNonce();
    }

    function _checkRootNonce(RootBridgeAgent bridgeAgent, bool shouldBeIncremented) internal view {
        require(
            shouldBeIncremented
                ? bridgeAgent.settlementNonce() == prevNonceRoot + 1
                : bridgeAgent.settlementNonce() == prevNonceRoot,
            "Nonce Operation Failed"
        );
    }

    uint32 prevNonceBranch;

    function _updateBranchNonce(BranchBridgeAgent bridgeAgent) internal {
        prevNonceBranch = bridgeAgent.depositNonce();
    }

    function _checkBranchNonce(BranchBridgeAgent bridgeAgent, bool shouldBeIncremented) internal view {
        require(
            shouldBeIncremented
                ? bridgeAgent.depositNonce() == prevNonceBranch + 1
                : bridgeAgent.depositNonce() == prevNonceBranch,
            "Nonce Operation Failed"
        );
    }

    fallback() external payable {}

    receive() external payable {}
}
