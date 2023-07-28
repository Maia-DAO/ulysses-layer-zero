//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;
//TEST

import {LzForkTest} from "../../test-utils/fork/LzForkTest.t.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

//COMPONENTS
import {RootPort} from "@omni/RootPort.sol";
import {ArbitrumBranchPort} from "@omni/ArbitrumBranchPort.sol";
import {BranchPort} from "@omni/BranchPort.sol";

import {RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {CoreBranchRouter} from "@omni/CoreBranchRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenBranch} from "@omni/token/ERC20hTokenBranch.sol";
import {ERC20hTokenRoot} from "@omni/token/ERC20hTokenRoot.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {DepositParams, DepositMultipleParams} from "./mocks/MockRootBridgeAgent.t.sol";
import {Deposit, DepositStatus, DepositMultipleInput, DepositInput} from "@omni/interfaces/IBranchBridgeAgent.sol";
import {Settlement, SettlementStatus, GasParams} from "@omni/interfaces/IRootBridgeAgent.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";
import {Multicall2} from "./mocks/Multicall2.sol";

pragma solidity ^0.8.0;

interface IAnycallApp {
    /// (required) call on the destination chain to exec the interaction
    function execute(bytes calldata _data) external returns (bool success, bytes memory result);

    /// (optional,advised) call back on the originating chain if the cross chain interaction fails
    /// `_data` is the orignal interaction arguments exec on the destination chain
    function anyFallback(bytes calldata _data) external returns (bool success, bytes memory result);
}

contract RootForkTest is LzForkTest {
    // Consts

    //Arb
    uint16 constant rootChainId = uint16(110);

    //Avax
    uint16 constant avaxChainId = uint16(106);

    //     //Ftm
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

    ERC20hTokenRoot arbitrumMockAssethToken;

    MockERC20 arbitrumMockToken;

    // Mocks

    address arbitrumGlobalToken;
    address avaxGlobalToken;
    address ftmGlobalToken;

    address arbitrumWrappedNativeToken;
    address avaxWrappedNativeToken;
    address ftmWrappedNativeToken;

    address arbitrumLocalWrappedNativeToken;
    address avaxLocalWrappedNativeToken;
    address ftmLocalWrappedNativeToken;

    address multicallAddress;

    address nonFungiblePositionManagerAddress = address(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    address lzEndpointAddress = address(0x3c2269811836af69497E5F486A85D7316753cf62);
    address lzEndpointAddressAvax = address(0x3c2269811836af69497E5F486A85D7316753cf62);
    address lzEndpointAddressFtm = address(0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7);

    address owner = address(this);

    address dao = address(this);

    function setUp() public override {
        /////////////////////////////////
        //         Fork Setup          //
        /////////////////////////////////

        // Set up default fork chains
        console2.log("Adding Default Chains...");
        setUpDefaultLzChains();
        console2.log("Added Default Chains.");

        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////
        console2.log("Deploying Root Contracts...");
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        arbitrumWrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////

        rootPort = new RootPort(rootChainId, arbitrumWrappedNativeToken);

        rootBridgeAgentFactory = new RootBridgeAgentFactory(
            rootChainId,
            WETH9(arbitrumWrappedNativeToken),
            lzEndpointAddress,
            address(rootPort),
            dao
        );

        coreRootRouter = new CoreRootRouter(rootChainId, arbitrumWrappedNativeToken, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        hTokenRootFactory = new ERC20hTokenRootFactory(rootChainId, address(rootPort));

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////

        console2.log("Initializing Root Contracts...");

        rootPort.initialize(address(rootBridgeAgentFactory), address(coreRootRouter));

        vm.deal(address(rootPort), 1 ether);
        vm.prank(address(rootPort));
        WETH(arbitrumWrappedNativeToken).deposit{value: 1 ether}();

        hTokenRootFactory.initialize(address(coreRootRouter));

        coreRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(coreRootRouter)))
        );

        multicallRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        coreRootRouter.initialize(address(coreRootBridgeAgent), address(hTokenRootFactory));

        rootMulticallRouter.initialize(address(multicallRootBridgeAgent));

        /////////////////////////////////
        //Deploy Local Branch Contracts//
        /////////////////////////////////

        console2.log("Deploying Arbitrum Local Branch Contracts...");

        arbitrumPort = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new BaseBranchRouter();

        arbitrumCoreBranchRouter = new ArbitrumCoreBranchRouter();

        arbitrumBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId,
            address(rootBridgeAgentFactory),
            WETH9(arbitrumWrappedNativeToken),
            lzEndpointAddress,
            address(arbitrumCoreBranchRouter),
            address(arbitrumPort),
            owner
        );

        arbitrumPort.initialize(address(arbitrumCoreBranchRouter), address(arbitrumBranchBridgeAgentFactory));

        arbitrumBranchBridgeAgentFactory.initialize(address(coreRootBridgeAgent));
        arbitrumCoreBranchBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(0)));

        arbitrumCoreBranchRouter.initialize(address(arbitrumCoreBranchBridgeAgent));
        //arbitrumMulticallRouter.initialize(address(arbitrumMulticallBranchBridgeAgent));

        //////////////////////////////////
        // Deploy Avax Branch Contracts //
        //////////////////////////////////

        console2.log("Deploying Avalanche Branch Contracts...");

        switchToLzChainWithoutExecutePendingOrPacketUpdate(avaxChainId);

        avaxWrappedNativeToken = address(new WETH());

        avaxPort = new BranchPort(owner);

        avaxHTokenFactory = new ERC20hTokenBranchFactory(rootChainId, address(avaxPort), "Avalanche Ulysses ", "avax-u");

        avaxMulticallRouter = new BaseBranchRouter();

        avaxCoreRouter = new CoreBranchRouter(address(avaxHTokenFactory));

        avaxBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            avaxChainId,
            rootChainId,
            address(rootBridgeAgentFactory),
            WETH9(avaxWrappedNativeToken),
            lzEndpointAddressAvax,
            address(avaxCoreRouter),
            address(avaxPort),
            owner
        );

        avaxPort.initialize(address(avaxCoreRouter), address(avaxBranchBridgeAgentFactory));

        avaxBranchBridgeAgentFactory.initialize(address(coreRootBridgeAgent));
        avaxCoreBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(0)));

        avaxHTokenFactory.initialize(avaxWrappedNativeToken, address(avaxCoreRouter));
        avaxLocalWrappedNativeToken = address(avaxHTokenFactory.hTokens(0));

        avaxCoreRouter.initialize(address(avaxCoreBridgeAgent));

        //////////////////////////////////
        // Deploy Ftm Branch Contracts //
        //////////////////////////////////

        console2.log("Deploying Fantom Contracts...");

        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        ftmWrappedNativeToken = address(new WETH());

        ftmPort = new BranchPort(owner);

        ftmHTokenFactory = new ERC20hTokenBranchFactory(rootChainId, address(ftmPort), "Fantom Ulysses ", "ftm-u");

        ftmMulticallRouter = new BaseBranchRouter();

        ftmCoreRouter = new CoreBranchRouter(address(ftmHTokenFactory));

        ftmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(rootBridgeAgentFactory),
            WETH9(ftmWrappedNativeToken),
            lzEndpointAddressFtm,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        ftmPort.initialize(address(ftmCoreRouter), address(ftmBranchBridgeAgentFactory));

        ftmBranchBridgeAgentFactory.initialize(address(coreRootBridgeAgent));
        ftmCoreBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(0)));

        ftmHTokenFactory.initialize(ftmWrappedNativeToken, address(ftmCoreRouter));
        ftmLocalWrappedNativeToken = address(ftmHTokenFactory.hTokens(0));

        ftmCoreRouter.initialize(address(ftmCoreBridgeAgent));

        /////////////////////////////
        //  Add new branch chains  //
        /////////////////////////////

        console2.log("Adding new Branch Chains to Root...");

        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        RootPort(rootPort).addNewChain(
            address(avaxCoreBridgeAgent),
            avaxChainId,
            "Avalanche",
            "AVAX",
            18,
            avaxLocalWrappedNativeToken,
            avaxWrappedNativeToken
        );

        RootPort(rootPort).addNewChain(
            address(ftmCoreBridgeAgent),
            ftmChainId,
            "Fantom Opera",
            "FTM",
            18,
            ftmLocalWrappedNativeToken,
            ftmWrappedNativeToken
        );

        avaxGlobalToken = address(hTokenRootFactory.hTokens(0));

        ftmGlobalToken = address(hTokenRootFactory.hTokens(1));

        // //Ensure there are gas tokens from each chain in the system.
        // vm.startPrank(address(arbitrumPort));
        // vm.deal(address(arbitrumPort), 1 ether);
        // WETH9(arbitrumWrappedNativeToken).deposit{value: 1 ether}();
        // vm.stopPrank();

        // vm.startPrank(address(rootPort));
        // ERC20hTokenRoot(avaxGlobalToken).mint(address(rootPort), 1 ether, avaxChainId);
        // vm.stopPrank();

        // vm.deal(address(this), 1 ether);
        // WETH9(avaxWrappedNativeToken).deposit{value: 1 ether}();
        // ERC20hTokenRoot(avaxWrappedNativeToken).transfer(address(avaxPort), 1 ether);

        // vm.startPrank(address(rootPort));
        // ERC20hTokenRoot(ftmGlobalToken).mint(address(rootPort), 2 ether, ftmChainId);
        // vm.stopPrank();

        // vm.deal(address(this), 2 ether);
        // WETH9(ftmWrappedNativeToken).deposit{value: 2 ether}();
        // ERC20hTokenRoot(ftmWrappedNativeToken).transfer(address(ftmPort), 2 ether);

        //////////////////////
        // Verify Addition  //
        //////////////////////

        require(RootPort(rootPort).isGlobalAddress(avaxGlobalToken), "Token should be added");

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxLocalWrappedNativeToken), avaxChainId)
                == avaxGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(avaxGlobalToken, avaxChainId)
                == address(avaxLocalWrappedNativeToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(avaxLocalWrappedNativeToken), avaxChainId)
                == address(avaxWrappedNativeToken),
            "Token should be added"
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(address(ftmLocalWrappedNativeToken), ftmChainId)
                == ftmGlobalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(ftmGlobalToken, ftmChainId)
                == address(ftmLocalWrappedNativeToken),
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(ftmLocalWrappedNativeToken), ftmChainId)
                == address(ftmWrappedNativeToken),
            "Token should be added"
        );

        ///////////////////////////////////
        //  Approve new Branchs in Root  //
        ///////////////////////////////////

        rootPort.initializeCore(
            address(coreRootBridgeAgent), address(arbitrumCoreBranchBridgeAgent), address(arbitrumPort)
        );

        multicallRootBridgeAgent.approveBranchBridgeAgent(rootChainId);

        multicallRootBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        ///////////////////////////////////////
        //  Add new branches to  Root Agents //
        ///////////////////////////////////////

        // Start the recorder necessary for packet tracking
        console2.log("Initializing Fork Test Environment...");
        vm.recordLogs();

        console2.log("Adding new Branch Bridge Agents to Root Bridge Agents...");

        vm.deal(address(this), 10000000_000_000 ether);

        coreRootRouter.addBranchToBridgeAgent{value: 1000_000_000 ether}(
            address(multicallRootBridgeAgent),
            address(avaxBranchBridgeAgentFactory),
            address(avaxCoreRouter),
            address(this),
            avaxChainId,
            [GasParams(150_000_000_000_000_000, 50_000_000_000_000_000), GasParams(25_000_000_000_000_000, 1_000_000_000_000)]
        );

        console2.log("1Adding new Branch Bridge Agents to Root Bridge Agents...");
        switchToChain(avaxChainId);
        console2.log("2Adding new Branch Bridge Agents to Root Bridge Agents...");
        switchToChain(rootChainId);
        console2.log("3Adding new Branch Bridge Agents to Root Bridge Agents...");

        coreRootRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(ftmCoreRouter),
            address(this),
            ftmChainId,
            [GasParams(150_000, 50_000), GasParams(25_000, 0)]
        );
        console2.log("4Adding new Branch Bridge Agents to Root Bridge Agents...");

        switchToChain(ftmChainId);
        switchToChain(rootChainId);

        coreRootRouter.addBranchToBridgeAgent(
            address(multicallRootBridgeAgent),
            address(arbitrumBranchBridgeAgentFactory),
            address(arbitrumCoreBranchRouter),
            address(this),
            rootChainId,
            [GasParams(0, 0), GasParams(0, 0)]
        );

        /////////////////////////////////////
        //  Initialize new Branch Routers  //
        /////////////////////////////////////

        console2.log("Initializing new Branch Routers...");

        arbitrumMulticallBranchBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(1)));
        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBranchBridgeAgent));

        switchToChain(avaxChainId);
        avaxMulticallBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(1)));
        avaxMulticallRouter.initialize(address(avaxMulticallBridgeAgent));

        switchToChain(ftmChainId);
        ftmMulticallBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(1)));
        ftmMulticallRouter.initialize(address(ftmMulticallBridgeAgent));

        //////////////////////////////////////
        //Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        switchToChain(avaxChainId);
        // avaxMockAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        switchToChain(ftmChainId);
        // ftmMockAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        switchToChain(rootChainId);
        //arbitrumMockAssethToken is global
        arbitrumMockToken = new MockERC20("underlying token", "UNDER", 18);
    }

    fallback() external payable {}

    receive() external payable {}

    struct OutputParams {
        address recipient;
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
    }

    struct OutputMultipleParams {
        address recipient;
        address[] outputTokens;
        uint256[] amountsOut;
        uint256[] depositsOut;
    }

    //////////////////////////////////////
    //           Bridge Agents          //
    //////////////////////////////////////

    function testAddBridgeAgentSimple() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Create Branch Router
        BaseBranchRouter ftmTestRouter = new BaseBranchRouter();

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        switchToChain(ftmChainId);

        console2.log("new branch bridge agent", ftmPort.bridgeAgents(2));

        BranchBridgeAgent ftmTestBranchBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(2)));

        ftmTestRouter.initialize(address(ftmTestBranchBridgeAgent));

        switchToChain(rootChainId);

        require(testRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == address(ftmTestBranchBridgeAgent));
    }

    function testAddBridgeAgentAlreadyAdded() public {
        testAddBridgeAgentSimple();

        //Get some gas
        vm.deal(address(this), 1 ether);

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("AlreadyAddedBridgeAgent()"));

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);
    }

    function testAddBridgeAgentTwoTimes() public {
        testAddBridgeAgentSimple();

        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("InvalidChainId()"));

        //Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );
    }

    function testAddBridgeAgentNotApproved() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        vm.expectRevert(abi.encodeWithSignature("UnauthorizedChainId()"));

        //Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );
    }

    function testAddBridgeAgentNotManager() public {
        //Get some gas
        vm.deal(address(89), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        vm.startPrank(address(89));

        vm.expectRevert(abi.encodeWithSignature("UnauthorizedCallerNotManager()"));
        //Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );
    }

    function testAddBridgeAgentWrongBranchFactory() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Router
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(32),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    function testRemoveBridgeAgent() public {
        coreRootRouter.removeBranchBridgeAgent{value: 0.05 ether}(
            address(ftmMulticallBridgeAgent), address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        require(!ftmPort.isBridgeAgent(address(ftmMulticallBridgeAgent)), "Should be disabled");
    }

    //////////////////////////////////////
    //        Bridge Agent Factory     //
    //////////////////////////////////////

    function testAddBridgeAgentFactory() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        BranchBridgeAgentFactory newFtmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(80),
            WETH9(ftmWrappedNativeToken),
            lzEndpointAddressFtm,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        console2.log("Core Router Owner", coreRootRouter.owner());

        coreRootRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(rootBridgeAgentFactory),
            address(newFtmBranchBridgeAgentFactory),
            address(this),
            ftmChainId,
            GasParams(0.05 ether, 0.05 ether)
        );

        require(ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Factory not enabled");
    }

    function testAddBridgeAgentWrongRootFactory() public {
        testAddBridgeAgentFactory();

        //Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(rootBridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        //Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        //Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        //Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            ftmPort.bridgeAgentFactories(1),
            address(testMulticallRouter),
            address(ftmCoreRouter),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    function testRemoveBridgeAgentFactory() public {
        //Add Factory
        testAddBridgeAgentFactory();

        //Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(rootBridgeAgentFactory),
            ftmPort.bridgeAgentFactories(1),
            address(this),
            ftmChainId,
            GasParams(0.05 ether, 0.05 ether)
        );

        require(!ftmPort.isBridgeAgentFactory(ftmPort.bridgeAgentFactories(1)), "Should be disabled");
    }

    //////////////////////////////////////
    //           Port Strategies        //
    //////////////////////////////////////

    function testAddStrategyToken() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.manageStrategyToken{value: 0.05 ether}(
            address(102), 300, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        require(ftmPort.isStrategyToken(address(102)), "Should be added");
    }

    function testAddStrategyTokenInvalidMinReserve() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        // vm.expectRevert(abi.encodeWithSignature("InvalidMinimumReservesRatio()"));
        coreRootRouter.manageStrategyToken{value: 0.05 ether}(
            address(102), 30000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );
        require(!ftmPort.isStrategyToken(address(102)), "Should note be added");
    }

    function testRemoveStrategyToken() public {
        //Add Token
        testAddStrategyToken();

        //Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.manageStrategyToken{value: 0.05 ether}(
            address(102), 0, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        require(!ftmPort.isStrategyToken(address(102)), "Should be removed");
    }

    function testAddPortStrategy() public {
        //Add strategy token
        testAddStrategyToken();

        //Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.managePortStrategy{value: 0.05 ether}(
            address(50), address(102), 300, false, address(this), ftmChainId, GasParams(0.05 ether, 0)
        );

        require(ftmPort.isPortStrategy(address(50), address(102)), "Should be added");
    }

    function testAddPortStrategyNotToken() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //UnrecognizedStrategyToken();
        coreRootRouter.managePortStrategy{value: 0.1 ether}(
            address(50), address(102), 300, false, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        require(!ftmPort.isPortStrategy(address(50), address(102)), "Should not be added");
    }

    //////////////////////////////////////
    //          TOKEN MANAGEMENT        //
    //////////////////////////////////////

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        vm.deal(address(this), 1 ether);

        avaxCoreRouter.addLocalToken{value: 0.1 ether}(address(avaxMockAssetToken), GasParams(0.5 ether, 0.5 ether));

        avaxMockAssethToken = RootPort(rootPort).getLocalTokenFromUnder(address(avaxMockAssetToken), avaxChainId);

        newAvaxAssetGlobalAddress = RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId);

        console2.log("New Global: ", newAvaxAssetGlobalAddress);
        console2.log("New Local: ", avaxMockAssethToken);

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId) == avaxMockAssethToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(avaxMockAssethToken, avaxChainId)
                == address(avaxMockAssetToken),
            "Token should be added"
        );
    }

    address public newFtmAssetGlobalAddress;

    address public newAvaxAssetLocalToken;

    function testAddGlobalToken() public {
        //Add Local Token from Avax
        testAddLocalToken();

        GasParams[3] memory gasParams =
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.05 ether, 0.0025 ether), GasParams(0.002 ether, 0)];

        avaxCoreRouter.addGlobalToken{value: 0.15 ether}(newAvaxAssetGlobalAddress, ftmChainId, gasParams);

        newAvaxAssetLocalToken = RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId);

        console2.log("New Local: ", newAvaxAssetLocalToken);

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(newAvaxAssetLocalToken, ftmChainId) == address(0),
            "Underlying should not be added"
        );
    }

    address public mockApp = address(0xDAFA);

    address public newArbitrumAssetGlobalAddress;

    function testAddLocalTokenArbitrum() public {
        //Set up
        testAddGlobalToken();

        //Get some gas.
        vm.deal(address(this), 1 ether);

        //Add new localToken
        arbitrumCoreBranchRouter.addLocalToken{value: 0.0005 ether}(
            address(arbitrumMockToken), GasParams(0.5 ether, 0.5 ether)
        );

        newArbitrumAssetGlobalAddress =
            RootPort(rootPort).getLocalTokenFromUnder(address(arbitrumMockToken), rootChainId);

        console2.log("New: ", newArbitrumAssetGlobalAddress);

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
                == address(arbitrumMockToken),
            "Token should be added"
        );
    }

    //////////////////////////////////////
    //          TOKEN TRANSFERS         //
    //////////////////////////////////////

    function testCallOutWithDeposit() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newArbitrumAssetGlobalAddress;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), outputToken, amountOut, depositOut);

            //toChain
            uint16 toChain = rootChainId;

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, toChain);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Get some gas.
        vm.deal(address(this), 1 ether);

        //Mint Underlying Token.
        arbitrumMockToken.mint(address(this), 100 ether);

        //Approve spend by router
        arbitrumMockToken.approve(address(arbitrumPort), 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        //Call Deposit function
        arbitrumMulticallBranchBridgeAgent.callOutSignedAndBridge{value: 1 ether}(
            payable(address(this)), packedData, depositInput, GasParams(0.5 ether, 0.5 ether)
        );

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBranchBridgeAgent,
            uint32(1),
            address(this),
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumMockToken),
            100 ether,
            100 ether,
            GasParams(0.5 ether, 0.5 ether)
        );

        console2.log("LocalPort Balance:", MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)));
        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == 50 ether, "LocalPort should have 50 tokens"
        );

        console2.log("User Balance:", MockERC20(arbitrumMockToken).balanceOf(address(this)));
        require(MockERC20(arbitrumMockToken).balanceOf(address(this)) == 50 ether, "User should have 50 tokens");

        console2.log("User Global Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)));
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(this)) == 50 ether,
            "User should have 50 global tokens"
        );
    }

    function testFuzzCallOutWithDeposit(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) public {
        // Input restrictions
        _amount %= type(uint256).max / 1 ether;

        vm.assume(
            _user != address(0) && _amount > _deposit && _amount >= _amountOut && _amount - _amountOut >= _depositOut
                && _depositOut < _amountOut
        );

        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock Omnichain dApp call
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams =
                OutputParams(_user, newArbitrumAssetGlobalAddress, _amountOut, _depositOut);

            //RLP Encode Calldata
            bytes memory data = abi.encode(calls, outputParams, rootChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        //Get some gas.
        vm.deal(_user, 1 ether);

        if (_amount - _deposit > 0) {
            //assure there is enough balance for mock action
            vm.startPrank(address(rootPort));
            ERC20hTokenRoot(newArbitrumAssetGlobalAddress).mint(_user, _amount - _deposit, rootChainId);
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

        console2.log("BALANCE BEFORE:");
        console2.log("arbitrumMockToken Balance:", MockERC20(arbitrumMockToken).balanceOf(_user));
        console2.log(
            "newArbitrumAssetGlobalAddress Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user)
        );

        //Call Deposit function
        vm.startPrank(_user);
        arbitrumMockToken.approve(address(arbitrumPort), _deposit);
        ERC20hTokenRoot(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBranchBridgeAgent.callOutSignedAndBridge{value: 1 ether}(
            payable(_user), packedData, depositInput, GasParams(0.5 ether, 0.5 ether)
        );
        vm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(
            arbitrumMulticallBranchBridgeAgent,
            uint32(1),
            _user,
            address(newArbitrumAssetGlobalAddress),
            address(arbitrumMockToken),
            _amount,
            _deposit,
            GasParams(0.05 ether, 0.05 ether)
        );

        console2.log("DATA");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        address userAccount = address(RootPort(rootPort).getUserAccount(_user));

        console2.log("LocalPort Balance:", MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)));
        console2.log("Expected:", _amount - _deposit + _deposit - _depositOut);
        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == _amount - _deposit + _deposit - _depositOut,
            "LocalPort tokens"
        );

        console2.log("RootPort Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)));
        // console2.log("Expected:", 0); SINCE ORIGIN == DESTINATION == ARBITRUM
        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        console2.log("User Balance:", MockERC20(arbitrumMockToken).balanceOf(_user));
        console2.log("Expected:", _depositOut);
        require(MockERC20(arbitrumMockToken).balanceOf(_user) == _depositOut, "User tokens");

        console2.log("User Global Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user));
        console2.log("Expected:", _amountOut - _depositOut);
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == _amountOut - _depositOut, "User Global tokens"
        );

        console2.log("User Account Balance:", MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount));
        console2.log("Expected:", _amount - _amountOut);
        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount) == _amount - _amountOut,
            "User Account tokens"
        );
    }

    function testRetrySettlement() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

            //RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, ftmChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address _user = address(this);

        //Get some gas.
        vm.deal(_user, 1 ether);
        vm.deal(address(ftmPort), 1 ether);

        //assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 50 ether, rootChainId);
        vm.prank(address(avaxPort));
        ERC20hTokenBranch(avaxMockAssethToken).mint(_user, 50 ether);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        console2.log("BALANCE BEFORE:");
        console2.log("User avaxMockAssetToken Balance:", MockERC20(avaxMockAssetToken).balanceOf(_user));
        console2.log("User avaxMockAssethToken Balance:", MockERC20(avaxMockAssethToken).balanceOf(_user));

        //Set MockEndpoint AnyFallback mode ON
        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);
        ERC20hTokenRoot(avaxMockAssethToken).approve(address(avaxPort), 50 ether);
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(
            payable(address(this)), packedData, depositInput, gasParams
        );

        //Set MockEndpoint AnyFallback mode OFF
        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        //Perform anyFallback transaction back to root bridge agent
        MockEndpoint(lzEndpointAddress).sendFallback();

        uint256 _amount = 150 ether;
        uint256 _deposit = 100 ether;
        uint256 _amountOut = 150 ether;
        uint256 _depositOut = 150 ether;
        console2.log("DATA");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        uint32 settlementNonce = multicallRootBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallRootBridgeAgent.getSettlementEntry(settlementNonce);

        console2.log("Status after fallback:", settlement.status == SettlementStatus.Failed ? "Failed" : "Success");

        require(settlement.status == SettlementStatus.Failed, "Settlement status should be failed.");

        //Get some gas.
        vm.deal(_user, 1 ether);

        //Retry Settlement
        multicallRootBridgeAgent.retrySettlement{value: 1 ether}(settlementNonce, GasParams(0.5 ether, 0.5 ether));

        settlement = multicallRootBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == SettlementStatus.Success, "Settlement status should be success.");
    }

    function testRedeemSettlement() public {
        //Set up
        testAddLocalTokenArbitrum();

        //Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Mock action
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            //Output Params
            OutputParams memory outputParams = OutputParams(address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

            //RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, ftmChainId);

            //Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address _user = address(this);

        //Get some gas.
        vm.deal(_user, 1 ether);
        vm.deal(address(ftmPort), 1 ether);

        //assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hTokenRoot(newAvaxAssetGlobalAddress).mint(address(rootPort), 50 ether, rootChainId);
        vm.prank(address(avaxPort));
        ERC20hTokenBranch(avaxMockAssethToken).mint(_user, 50 ether);

        //Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        //Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        console2.log("BALANCE BEFORE:");
        console2.log("User avaxMockAssetToken Balance:", MockERC20(avaxMockAssetToken).balanceOf(_user));
        console2.log("User avaxMockAssethToken Balance:", MockERC20(avaxMockAssethToken).balanceOf(_user));

        //Set MockEndpoint AnyFallback mode ON
        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);
        ERC20hTokenRoot(avaxMockAssethToken).approve(address(avaxPort), 50 ether);
        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(
            payable(address(this)), packedData, depositInput, gasParams
        );

        //Set MockEndpoint AnyFallback mode OFF
        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        //Perform anyFallback transaction back to root bridge agent
        MockEndpoint(lzEndpointAddress).sendFallback();

        uint256 _amount = 150 ether;
        uint256 _deposit = 100 ether;
        uint256 _amountOut = 150 ether;
        uint256 _depositOut = 150 ether;
        console2.log("DATA");
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_amountOut);
        console2.log(_depositOut);

        uint32 settlementNonce = multicallRootBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallRootBridgeAgent.getSettlementEntry(settlementNonce);

        console2.log("Status after fallback:", settlement.status == SettlementStatus.Failed ? "Failed" : "Success");

        require(settlement.status == SettlementStatus.Failed, "Settlement status should be failed.");

        //Retry Settlement
        multicallRootBridgeAgent.redeemSettlement(settlementNonce);

        settlement = multicallRootBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.owner == address(0), "Settlement should cease to exist.");

        require(
            MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user) == 150 ether, "Settlement should have been redeemed"
        );
    }

    //////////////////////////////////////////////////////////////////////////   HELPERS   ///////////////////////////////////////////////////////////////////

    function testCreateDepositSingle(
        ArbitrumBranchBridgeAgent _bridgeAgent,
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        GasParams memory _gasParams
    ) private view {
        // Cast to Dynamic TODO clean up
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

        console2.log(deposit.hTokens[0], hTokens[0]);
        console2.log(deposit.tokens[0], tokens[0]);
        console2.log("owner", deposit.owner);
        console2.log("user", _user);

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

        require(deposit.status == DepositStatus.Success, "Deposit status should be succesful.");

        console2.logUint(WETH9(arbitrumWrappedNativeToken).balanceOf(address(arbitrumPort)));
    }

    function encodeSystemCall(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x00), _nonce, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _fromChainId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallNoDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);
        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _fromChainId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
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
        uint16 _toChain,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata =
            abi.encodePacked(bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _toChain, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _fromChainId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint16 _toChain,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data for cross-chain call.
        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x03), uint8(_hTokens.length), _nonce, _hTokens, _tokens, _amounts, _deposits, _toChain, _data
        );

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _fromChainId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function _encodeSystemCall(uint32 _nonce, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        pure
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x00), _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDeposit(uint32 _nonce, bytes memory _data, uint128 _rootExecGas, uint128 _remoteExecGas)
        internal
        pure
        returns (bytes memory inputCalldata)
    {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x01), _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encodeNoDepositSigned(
        uint32 _nonce,
        address _user,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x04), _user, _nonce, _data, _rootExecGas, _remoteExecGas);
    }

    function _encode(
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint16 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _toChain, _data, _rootExecGas, _remoteExecGas
        );
    }

    function _encodeSigned(
        uint32 _nonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        uint16 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x05),
            _user,
            _nonce,
            _hToken,
            _token,
            _amount,
            _deposit,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function _encodeMultiple(
        uint32 _nonce,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint16 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x03),
            uint8(_hTokens.length),
            _nonce,
            _hTokens,
            _tokens,
            _amounts,
            _deposits,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function _encodeMultipleSigned(
        uint32 _nonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        uint16 _toChain,
        bytes memory _data,
        uint128 _rootExecGas,
        uint128 _remoteExecGas
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x06),
            _user,
            uint8(_hTokens.length),
            _nonce,
            _hTokens,
            _tokens,
            _amounts,
            _deposits,
            _toChain,
            _data,
            _rootExecGas,
            _remoteExecGas
        );
    }

    function compareDynamicArrays(bytes memory a, bytes memory b) public pure returns (bool aEqualsB) {
        assembly {
            aEqualsB := eq(a, b)
        }
    }
}

contract MockEndpoint is DSTestPlus {
    uint256 constant rootChain = 42161;

    address public lastFrom;
    address public anyConfig;
    address public to;
    bytes public data;
    bool forceFallback;
    uint256 fallbackCountdown;
    uint256 gasLimit;
    uint256 remoteBranchExecutionGas;
    address receiver;

    constructor() {}

    function toggleFallback(uint256 _fallbackCountdown) external {
        forceFallback = !forceFallback;
        fallbackCountdown = _fallbackCountdown;
    }

    function sendFallback() public {
        console2.log("Mocking fallback...");
        console2.log("to:", lastFrom);
        console2.log("from:", to);
        console2.log("fromChain:", BranchBridgeAgent(payable(to)).localChainId());

        hevm.deal(address(this), gasLimit + remoteBranchExecutionGas);

        bytes memory fallbackData =
            abi.encodePacked(BranchBridgeAgent(payable(lastFrom)).localChainId() == 42161 ? 0x09 : 0x03, data);

        // Perform Call
        lastFrom.call{value: remoteBranchExecutionGas}("");
        RootBridgeAgent(payable(lastFrom)).lzReceive{gas: gasLimit}(
            BranchBridgeAgent(payable(to)).localChainId(), abi.encodePacked(to, lastFrom), 1, fallbackData
        );
    }
    // @notice send a LayerZero message to the specified address at a LayerZero endpoint.
    // @param _dstChainId - the destination chain identifier
    // @param _destination - the address on destination chain (in bytes). address length/format may vary by chains
    // @param _payload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    // @param _zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
    // @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination

    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable,
        address,
        bytes calldata _adapterParams
    ) external payable {
        lastFrom = msg.sender;
        to = address(bytes20(_destination[:20]));
        data = _payload;

        console2.log("Mocking lzSends...");
        console2.log("from:", lastFrom);
        console2.log("fromChain:", BranchBridgeAgent(payable(msg.sender)).localChainId());

        // Decode adapter params
        if (_adapterParams.length > 0) {
            gasLimit = uint256(bytes32(_adapterParams[0:32]));
            remoteBranchExecutionGas = uint256(bytes32(_adapterParams[32:64]));
            receiver = address(bytes20(_adapterParams[64:84]));
        } else {
            gasLimit = 200_000;
            remoteBranchExecutionGas = 0;
            receiver = address(0);
        }

        if (!forceFallback) {
            // Perform Call
            to.call{value: remoteBranchExecutionGas}("");
            RootBridgeAgent(payable(to)).lzReceive{gas: gasLimit}(
                BranchBridgeAgent(payable(msg.sender)).localChainId(), abi.encodePacked(lastFrom, to), 1, data
            );
        } else {
            if (fallbackCountdown > 0) {
                console2.log("Execute anycall request...", fallbackCountdown--);
                // Perform Call
                to.call{value: remoteBranchExecutionGas}("");
                RootBridgeAgent(payable(to)).lzReceive{gas: gasLimit}(
                    BranchBridgeAgent(payable(msg.sender)).localChainId(), abi.encodePacked(lastFrom, to), 1, data
                );
            }
        }
    }
}
