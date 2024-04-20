//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./helpers/ImportHelper.sol";

contract MulticallRootRouterTest is Test {
    uint32 nonce;

    MockERC20 avaxNativeAssethToken;

    MockERC20 avaxNativeToken;

    MockERC20 ftmNativeAssethToken;

    MockERC20 ftmNativeToken;

    MockERC20 rewardToken;

    ERC20hToken testToken;

    ERC20hTokenRootFactory hTokenFactory;

    RootPort rootPort;

    CoreRootRouter rootCoreRouter;

    MulticallRootRouter rootMulticallRouter;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent coreBridgeAgent;

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

    address lzEndpointAddress = address(0xCAFE);

    address owner = address(this);

    address dao = address(this);

    fallback() external payable {}

    /// COPIED FROM MULTICALLROOTROUTER
    /// @dev Used for identifying cases when this contract's balance of a token is to be used as an input
    /// This value is equivalent to 1<<255, i.e. a singular 1 in the most significant bit.
    uint256 internal constant CONTRACT_BALANCE = 0x8000000000000000000000000000000000000000000000000000000000000000;

    function setNewMulticallRootRouter() internal virtual {
        rootMulticallRouter = new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);
    }

    function setUp() public {
        //Mock calls
        vm.mockCall(lzEndpointAddress, abi.encodeWithSignature("lzReceive(uint16,bytes,uint64,bytes)"), "");

        // Deploy Root Utils
        wrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        // Deploy Root Contracts
        rootPort = new RootPort(rootChainId);

        bridgeAgentFactory = new RootBridgeAgentFactory(rootChainId, lzEndpointAddress, address(rootPort));

        rootCoreRouter = new CoreRootRouter(rootChainId, address(rootPort));

        setNewMulticallRootRouter();

        hTokenFactory = new ERC20hTokenRootFactory(address(rootPort));

        // Initialize Root Contracts
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

        // Deploy Local Branch Contracts
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
                    address(arbitrumMulticallRouter), address(rootMulticallRouter), address(bridgeAgentFactory)
                )
            )
        );

        vm.stopPrank();

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        // Deploy Remote Branchs Contracts

        //////////////////////////////////

        // Sync Root with new branches

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(localPortAddress));

        coreBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        coreBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmChainId);

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

        testToken = new ERC20hToken(address(rootPort), "Hermes Global hToken 1", "hGT1", 18);

        // // Ensure there are gas tokens from each chain in the system.
        // vm.startPrank(address(rootPort));
        // ERC20hToken(avaxGlobalToken).mint(address(rootPort), 1 ether);
        // ERC20hToken(ftmGlobalToken).mint(address(rootPort), 1 ether);
        // vm.stopPrank();

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

        avaxNativeAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);

        avaxNativeToken = new MockERC20("underlying token", "UNDER", 18);

        ftmNativeAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);

        ftmNativeToken = new MockERC20("underlying token", "UNDER", 18);

        rewardToken = new MockERC20("hermes token", "HERMES", 18);

        userVirtualAccount = address(rootPort.fetchVirtualAccount(address(this)));
    }

    function encodeCalls(bytes memory data) internal virtual returns (bytes memory) {
        return data;
    }

    ////////////////////////////////////////////////////////////////////////// NO OUPUT ////////////////////////////////////////////////////////////////////

    address public mockApp = address(0xDAFA);

    // User Virtual Account
    address userVirtualAccount;

    function testMulticallNoOutputNoDeposit() public {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Add Local Token from Avax
        testSetLocalToken();

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        calls[0] =
            Multicall2.Call({target: mockApp, callData: abi.encodeWithSelector(bytes4(keccak256(bytes("distro()"))))});

        // RLP Encode Calldata
        bytes memory data = encodeCalls(abi.encode(calls));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        uint32 currentNonce = nonce;

        // Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            packedData,
            GasParams(0.5 ether, 0 ether),
            avaxChainId
        );

        require((multicallBridgeAgent).executionState(avaxChainId, currentNonce) == 1, "Nonce should be executed");
    }

    function testMulticallNoOutputNoDepositSigned() public {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Add Local Token from Avax
        testSetLocalToken();

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        calls[0] =
            Multicall2.Call({target: mockApp, callData: abi.encodeWithSelector(bytes4(keccak256(bytes("distro()"))))});

        // RLP Encode Calldata
        bytes memory data = encodeCalls(abi.encode(calls));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        uint32 currentNonce = nonce;

        // Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0 ether),
            avaxChainId
        );

        require((multicallBridgeAgent).executionState(avaxChainId, currentNonce) == 1, "Nonce should be executed");
    }

    function testMulticallSignedNoOutputDepositSingle() public {
        // Add Local Token from Avax
        testSetLocalToken();

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        // Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
        calls[0] = Multicall2.Call({
            target: newAvaxAssetGlobalAddress,
            callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
        });

        // RLP Encode Calldata
        bytes memory data = encodeCalls(abi.encode(calls));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        // Call Deposit function
        encodeCallWithDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeSigned(
                1,
                address(this),
                address(avaxNativeAssethToken),
                address(avaxNativeToken),
                100 ether,
                100 ether,
                packedData
            ),
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);
        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 50 ether, "Balance should be added");
        require(balanceTokenPortAfter == 0, "Balance should be cleared");
        require(balanceTokenVirtualAccountAfter == 50 ether, "Balance should be added");
    }

    function testMulticallSignedNoOutputDepositMultiple() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 wAVAX from virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x01), data);

            // Prepare input token arrays
            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[0] = 100 ether;
            inputTokenDeposits[0] = 0;

            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[1] = 100 ether;
            inputTokenDeposits[1] = 100 ether;
        }

        // Assure there are assets after mock action (mock previous branch port deposits)
        vm.startPrank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 100 ether);
        vm.stopPrank();

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 100 ether);
        rootPort.bridgeToBranch(address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 100 ether, 0, ftmChainId);
        vm.stopPrank();

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        // Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                packedData
            ),
            GasParams(0.5 ether, 0.5 ether),
            ftmChainId
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(mockApp));
        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(address(mockApp));

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);
        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 100 ether, "Balance should be added");
        require(balanceFtmMockAppAfter == 0 ether, "Balance should stay equal");

        require(balanceTokenPortAfter == 0 ether, "Balance should stay equal");
        require(balanceFtmPortAfter == balanceFtmPortBefore, "Balance should stay equal");

        require(balanceTokenVirtualAccountAfter == 0 ether, "Balance should stay equal");
        require(balanceFtmVirtualAccountAfter == 100 ether, "Balance should be incremented");
    }

    ////////////////////////////////////////////////////////////////////////// SINGLE OUTPUT ////////////////////////////////////////////////////////////////////

    function testMulticallNoCodeInTarget() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 99 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            // Assure there are assets after mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(ftmGlobalToken).mint(userVirtualAccount, 100 ether);
            vm.stopPrank();

            //dstChainId
            uint16 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(userVirtualAccount));

        // Call should revert with IVirtualAccount.CallFailed.selector
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );

        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(userVirtualAccount));

        require(
            balanceFtmPortAfter == balanceFtmPortBefore, "No state changes should happen. Balance should stay equal"
        );
    }

    function testMulticallSingleOutputNoDeposit() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 50 ether;
            depositOut = 25 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            // Assure there are assets after mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(ftmGlobalToken).mint(address(rootMulticallRouter), 50 ether);
            ERC20hToken(ftmGlobalToken).mint(multicallAddress, 50 ether);
            vm.stopPrank();

            // ToChain
            uint24 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        // Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            0,
            packedData,
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );

        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        require(balanceFtmMockAppAfter == 50 ether, "Mock app balance should be 50 ether");

        require(balanceFtmPortAfter == balanceFtmPortBefore + 25 ether, "Port should increase 25 ether");
    }

    function testMulticallSignedSingleOutputNoDeposit() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 50 ether;
            depositOut = 25 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 wFTM form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
            });

            // Assure there are assets for mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(ftmGlobalToken).mint(userVirtualAccount, 100 ether);
            vm.stopPrank();

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        // Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );

        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceFtmMockAppAfter == 50 ether, "Balance should be increased");

        require(balanceFtmPortAfter == balanceFtmPortBefore + 25 ether, "Balance should be half");

        require(balanceFtmVirtualAccountAfter == 0, "Balance should stay 0");
    }

    function testMulticallSignedSingleOutputNoDepositContractBalance() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = CONTRACT_BALANCE;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 wFTM form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
            });

            // Assure there are assets for mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(ftmGlobalToken).mint(userVirtualAccount, 100 ether);
            vm.stopPrank();

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        // Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );

        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceRootPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceFtmMockAppAfter == 50 ether, "Balance should be increased");

        require(balanceRootPortAfter == balanceFtmPortBefore, "Balance should be same, all native cleared");

        require(balanceFtmVirtualAccountAfter == 0, "Balance should stay 0");
    }

    function testMulticallSignedSingleOutputDepositSingle() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
        bytes memory packedData;

        {
            outputToken = newAvaxAssetGlobalAddress;
            amountOut = 99 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            //Prepare call to transfer 1 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            // assure there are assets after mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 100 ether);
            vm.stopPrank();

            vm.startPrank(address(multicallBridgeAgent));
            ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 100 ether);
            rootPort.bridgeToBranch(address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 100 ether, 0, ftmChainId);
            vm.stopPrank();

            //dstChainId
            uint16 dstChainId = avaxChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Call Deposit function
        encodeCallWithDeposit(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeSigned(1, address(this), address(newAvaxAssetLocalToken), address(0), 100 ether, 0, packedData),
            GasParams(0.5 ether, 0.5 ether),
            ftmChainId
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 1 ether, "Balance should be bigger");

        require(balanceTokenPortAfter == 49 ether, "Balance should be in port");

        require(balanceTokenVirtualAccountAfter == 0, "Balance should be cleared");
    }

    function testMulticallSignedSingleOutputDepositMultiple() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;

        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);
        bytes memory packedData;

        {
            outputToken = ftmGlobalToken;
            amountOut = 100 ether;
            depositOut = 50 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), outputToken, amountOut, depositOut);

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputParams, ftmChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);

            // Prepare input token arrays

            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[0] = 100 ether;
            inputTokenDeposits[0] = 0;

            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[1] = 100 ether;
            inputTokenDeposits[1] = 100 ether;
        }

        // Assure there are assets after mock action
        vm.startPrank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 100 ether);
        vm.stopPrank();

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 100 ether);
        rootPort.bridgeToBranch(address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 100 ether, 0, ftmChainId);
        vm.stopPrank();

        uint256 balanceFtmPortBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        // Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                packedData
            ),
            GasParams(0.5 ether, 0.5 ether),
            ftmChainId
        );

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);
        uint256 balanceFtmMockAppAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceFtmPortAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        uint256 balanceTokenVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);
        uint256 balanceFtmVirtualAccountAfter = MockERC20(ftmGlobalToken).balanceOf(userVirtualAccount);

        require(balanceTokenMockAppAfter == 100 ether, "Balance should be added");
        require(balanceFtmMockAppAfter == 0, "Balance should be cleared");

        require(balanceTokenPortAfter == 0, "Balance should be cleared");
        require(balanceFtmPortAfter == balanceFtmPortBefore + 50 ether, "Balance should be added");

        require(balanceTokenVirtualAccountAfter == 0, "Balance should be cleared");
        require(balanceFtmVirtualAccountAfter == 0, "Balance should be cleared");
    }

    ////////////////////////////////////////////////////////////////////////// MULTIPLE OUTPUT ////////////////////////////////////////////////////////////////////

    function testMulticallMultipleOutputNoDeposit() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        // Get previous port balance
        uint256 portBalanceBefore_A = MockERC20(avaxGlobalToken).balanceOf(address(rootPort));
        uint256 portBalanceBefore_B = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        // Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = avaxGlobalToken;
            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[0] = 100 ether;
            amountsOut[1] = 99 ether;
            depositsOut[0] = 50 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            // Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), address(this), outputTokens, amountsOut, depositsOut);

            // Assure there are assets after mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(newAvaxAssetGlobalAddress).mint(address(rootMulticallRouter), 99 ether);
            ERC20hToken(newAvaxAssetGlobalAddress).mint(multicallAddress, 1 ether);
            ERC20hToken(avaxGlobalToken).mint(address(rootMulticallRouter), 100 ether);
            vm.stopPrank();

            //dstChainId
            uint16 dstChainId = avaxChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputMultipleParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        // Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            packedData,
            GasParams(0.5 ether, 0 ether),
            avaxChainId
        );

        uint256 routerBalanceAfter_A = MockERC20(avaxGlobalToken).balanceOf(address(rootMulticallRouter));
        require(routerBalanceAfter_A == 0, "Router Balance should be cleared of token A");

        uint256 routerBalanceAfter_B = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootMulticallRouter));
        require(routerBalanceAfter_B == 0, "Router Balance should be cleared of token B");

        uint256 mockAppBalanceAfter_B = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);
        require(mockAppBalanceAfter_B == 1 ether, "Balance should be 1 ether");

        uint256 portBalanceAfter_A = MockERC20(avaxGlobalToken).balanceOf(address(rootPort));
        require(portBalanceAfter_A == portBalanceBefore_A + 50 ether, "Port Balance should increase 99 ether");

        uint256 portBalanceAfter_B = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        require(portBalanceAfter_B == portBalanceBefore_B + 99 ether, "Port Balance should increase  50 ether");
    }

    function testMulticallMultipleOutputNoDepositContractBalance() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        // Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = avaxGlobalToken;
            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[0] = CONTRACT_BALANCE;
            amountsOut[1] = CONTRACT_BALANCE;
            depositsOut[0] = 50 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 1 ether)
            });

            // Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), address(this), outputTokens, amountsOut, depositsOut);

            // Assure there are assets after mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(avaxGlobalToken).mint(userVirtualAccount, 100 ether);
            ERC20hToken(newAvaxAssetGlobalAddress).mint(userVirtualAccount, 100 ether);
            vm.stopPrank();

            //dstChainId
            uint16 dstChainId = avaxChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputMultipleParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        // Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0 ether),
            avaxChainId
        );

        uint256 balanceAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootMulticallRouter));
        uint256 balanceFtmAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootMulticallRouter));

        require(balanceAfter == 0, "Balance should be cleared");
        require(balanceFtmAfter == 0, "Balance should be cleared");

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);

        require(balanceTokenMockAppAfter == 1 ether, "Balance should be 1 ether");

        uint256 balanceVirtualAccountAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(userVirtualAccount));
        uint256 balanceVirtualAccountFtmAfter = MockERC20(ftmGlobalToken).balanceOf(address(userVirtualAccount));

        require(balanceVirtualAccountAfter == 0, "Balance should be cleared");
        require(balanceVirtualAccountFtmAfter == 0, "Balance should be cleared");
    }

    function testMulticallSignedMultipleOutputNoDeposit() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        // Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            amountsOut[0] = 50 ether;
            depositsOut[0] = 50 ether;

            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[1] = 100 ether;
            depositsOut[1] = 0 ether;

            // Assure there are assets after mock action
            vm.startPrank(address(rootPort));
            ERC20hToken(ftmGlobalToken).mint(address(userVirtualAccount), 100 ether);
            ERC20hToken(newAvaxAssetGlobalAddress).mint(address(userVirtualAccount), 100 ether);
            vm.stopPrank();

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 50 wFTM global token from virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 50 ether)
            });

            // Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), address(this), outputTokens, amountsOut, depositsOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputMultipleParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        // Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );

        uint256 balanceTokenAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(userVirtualAccount);
        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        require(balanceTokenAfter == 0, "Virtual account should be empty");
        require(balanceTokenPortAfter == 100 ether, "Balance be in Port");
    }

    function testMulticallSignedMultipleOutputDepositSingle() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);
        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            amountsOut[0] = 50 ether;
            depositsOut[0] = 25 ether;

            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[1] = 100 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({
                target: ftmGlobalToken,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            // Get some tokens into Virtual Account to be created with this call
            vm.startPrank(address(rootPort));
            ERC20hToken(ftmGlobalToken).mint(userVirtualAccount, 150 ether);
            vm.stopPrank();

            // Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), address(this), outputTokens, amountsOut, depositsOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputMultipleParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);
        }

        uint256 balanceGlobalFtmBefore = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));

        // Call Deposit function
        encodeCallWithDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeSigned(
                1,
                address(this),
                address(avaxNativeAssethToken),
                address(avaxNativeToken),
                100 ether,
                100 ether,
                packedData
            ),
            GasParams(0.5 ether, 0.5 ether),
            avaxChainId
        );
        uint256 balanceGlobalTokenAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        uint256 balanceGlobalFtmAfter = MockERC20(ftmGlobalToken).balanceOf(address(rootPort));
        uint256 mockAppBalanceAfter = MockERC20(ftmGlobalToken).balanceOf(mockApp);

        require(
            balanceGlobalTokenAfter == 100 ether,
            "Port should not have accumulated tokens since no hTokens were cleared"
        );

        require(
            balanceGlobalFtmAfter == balanceGlobalFtmBefore + 25 ether,
            "Port should have cleared half the 50 new hTokens for branch redemption"
        );

        require(mockAppBalanceAfter == 100 ether, "dApp interaction failed");
    }

    function testMulticallSignedMultipleOutputDepositMultiple() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        // Prepare data
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);

        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);

        bytes memory packedData;

        {
            outputTokens[0] = ftmGlobalToken;
            outputTokens[1] = newAvaxAssetGlobalAddress;
            amountsOut[0] = 100 ether;
            amountsOut[1] = 100 ether;
            depositsOut[0] = 50 ether;
            depositsOut[1] = 0 ether;

            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
            calls[0] = Multicall2.Call({target: 0x0000000000000000000000000000000000000000, callData: ""});

            // Output Params
            OutputMultipleParams memory outputMultipleParams =
                OutputMultipleParams(address(this), address(this), outputTokens, amountsOut, depositsOut);

            //dstChainId
            uint16 dstChainId = ftmChainId;

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls, outputMultipleParams, dstChainId));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);

            // Prepare input token arrays
            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);

            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);

            inputTokenAmounts[0] = 100 ether;
            inputTokenAmounts[1] = 100 ether;

            inputTokenDeposits[0] = 0;
            inputTokenDeposits[1] = 100 ether;
        }

        // Assure there are assets after mock action
        vm.startPrank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 100 ether);
        vm.stopPrank();

        // Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                packedData
            ),
            GasParams(0.5 ether, 0.5 ether),
            ftmChainId
        );

        uint256 balanceAfter =
            MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2));
        uint256 balanceFtmAfter =
            MockERC20(ftmGlobalToken).balanceOf(address(0x4f81992FCe2E1846dD528eC0102e6eE1f61ed3e2));

        require(balanceAfter == 0, "Balance should be cleared");
        require(balanceFtmAfter == 0, "Balance should be cleared");

        uint256 balanceTokenMockAppAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(mockApp);

        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");
        require(balanceTokenMockAppAfter == 0, "Balance should be cleared");
    }

    ////////////////////////////////////////////////////////////////////////////////// CALLOUT AND BRIDGE ///////////////////////////////////////////////////////////////////////////////

    function testCallOutAndBridge() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        address _user = address(this);

        // mint for user
        vm.startPrank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(_user, 100 ether);
        vm.stopPrank();

        //approve router
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootMulticallRouter), 100 ether);

        // Perform callOut
        rootMulticallRouter.callOutAndBridge(
            _user, _user, newAvaxAssetGlobalAddress, 100 ether, 0, avaxChainId, GasParams(500_000, 0)
        );

        uint256 balanceTokenPortAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        require(balanceTokenPortAfter == 100 ether, "Balance should be in port");

        uint256 balanceUserAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user);

        require(balanceUserAfter == 0, "Balance should be spent");
    }

    function testCallOutAndBridgeMultiple() public {
        // Add Local Token from Avax
        testSetLocalToken();

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );

        address _user = address(this);

        // Mint for user
        vm.startPrank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(_user, 100 ether);
        ERC20hToken(avaxGlobalToken).mint(_user, 100 ether);
        vm.stopPrank();

        // Approve router
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootMulticallRouter), 100 ether);
        ERC20hToken(avaxGlobalToken).approve(address(rootMulticallRouter), 100 ether);

        // Prepare Data
        address[] memory outputTokensAddresses = new address[](2);
        uint256[] memory outputTokensAmounts = new uint256[](2);
        uint256[] memory outputTokensDeposits = new uint256[](2);

        outputTokensAddresses[0] = address(newAvaxAssetGlobalAddress);
        outputTokensAddresses[1] = address(avaxGlobalToken);

        outputTokensAmounts[0] = 100 ether;
        outputTokensAmounts[1] = 100 ether;

        outputTokensDeposits[0] = 0;
        outputTokensDeposits[1] = 50 ether;

        // Perform callOut
        rootMulticallRouter.callOutAndBridgeMultiple(
            _user,
            _user,
            outputTokensAddresses,
            outputTokensAmounts,
            outputTokensDeposits,
            avaxChainId,
            GasParams(500_000, 0)
        );

        uint256 balanceTokenPortAfter_A = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));
        require(balanceTokenPortAfter_A == 100 ether, "Balance should be in port");

        uint256 balanceTokenPortAfter_B = MockERC20(avaxGlobalToken).balanceOf(address(rootPort));
        require(balanceTokenPortAfter_B == 50 ether, "Balance should be in port");

        uint256 balanceUserAfter_A = MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user);
        require(balanceUserAfter_A == 0, "Balance should be spent");

        uint256 balanceUserAfter_B = MockERC20(avaxGlobalToken).balanceOf(_user);
        require(balanceUserAfter_B == 0, "Balance should be spent");
    }

    ////////////////////////////////////////////////////////////////////////// TEST INCREMENT AND DECREMENT BRANCHES ////////////////////////////////////////////////////////////////////

    function testInvalidBranchhTokenMintSignedNoOutputDepositMultiple() public {
        // Add Local Token from Avax
        testSetLocalToken();

        // Prepare data
        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Prepare call to transfer 100 wAVAX from virtual account to Mock App
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
            });

            // RLP Encode Calldata
            bytes memory data = encodeCalls(abi.encode(calls));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x01), data);

            // Prepare input token arrays
            inputHTokenAddresses[0] = address(newAvaxAssetLocalToken);
            inputTokenAddresses[0] = address(avaxUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[0] = 100 ether;
            inputTokenDeposits[0] = 0;

            inputHTokenAddresses[1] = address(ftmLocalWrappedNativeTokenAddress);
            inputTokenAddresses[1] = address(ftmUnderlyingWrappedNativeTokenAddress);
            inputTokenAmounts[1] = 100 ether;
            inputTokenDeposits[1] = 100 ether;
        }

        // Assure there are assets after mock action (mock previous branch port deposits)
        vm.startPrank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 100 ether);
        vm.stopPrank();

        // Save branch deposit nonce
        uint32 branchNonce = nonce;
        vm.expectRevert(stdError.arithmeticError);

        // Call Deposit function
        encodeCallWithDepositMultiple(
            payable(ftmMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            _encodeMultipleSigned(
                1,
                address(this),
                inputHTokenAddresses,
                inputTokenAddresses,
                inputTokenAmounts,
                inputTokenDeposits,
                packedData
            ),
            GasParams(0.5 ether, 0.5 ether),
            ftmChainId
        );

        // Require root bridge agent execution status is READY
        require(multicallBridgeAgent.executionState(ftmChainId, branchNonce) == 0, "Nonce should not be executed");
    }

    //////////////////////////////////////////////////////////////////// UNRECOGNIZED FUNCTION ID ////////////////////////////////////////////////////////////

    function testMulticallUnrecognizedFuncitonId() public {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Add Local Token from Avax
        testSetLocalToken();

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        calls[0] =
            Multicall2.Call({target: mockApp, callData: abi.encodeWithSelector(bytes4(keccak256(bytes("distro()"))))});

        // RLP Encode Calldata
        bytes memory data = encodeCalls(abi.encode(calls));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x08), data);

        uint32 currentNonce = nonce;

        vm.expectRevert(abi.encodeWithSignature("UnrecognizedFunctionId()"));

        // Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            1,
            packedData,
            GasParams(0.5 ether, 0 ether),
            avaxChainId
        );

        require((multicallBridgeAgent).executionState(avaxChainId, currentNonce) == 0, "Nonce should not be executed");
    }

    function testMulticallUnrecognizedFuncitonIdSigned() public {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        //Add Local Token from Avax
        testSetLocalToken();

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        calls[0] =
            Multicall2.Call({target: mockApp, callData: abi.encodeWithSelector(bytes4(keccak256(bytes("distro()"))))});

        // RLP Encode Calldata
        bytes memory data = encodeCalls(abi.encode(calls));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x08), data);

        uint32 currentNonce = nonce;

        vm.expectRevert(abi.encodeWithSignature("UnrecognizedFunctionId()"));

        // Call Deposit function
        encodeCallNoDepositSigned(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            address(this),
            packedData,
            GasParams(0.5 ether, 0 ether),
            avaxChainId
        );

        require((multicallBridgeAgent).executionState(avaxChainId, currentNonce) == 0, "Nonce should not be executed");
    }

    ////////////////////////////////////////////////////////////////////////// ADD TOKENS ////////////////////////////////////////////////////////////////////

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() internal {
        // Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL");

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            GasParams(0.5 ether, 0.5 ether),
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

    function testAddGlobalToken() internal {
        // Add Local Token from Avax
        testAddLocalToken();

        //Encode Call Data
        bytes memory data = abi.encode(address(this), newAvaxAssetGlobalAddress, ftmChainId, GasParams(0.2 ether, 0));

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        vm.deal(address(rootCoreRouter), 1 ether);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            GasParams(0.5 ether, 0.5 ether),
            ftmChainId
        );
        // State change occurs in setLocalToken
    }

    address public newAvaxAssetLocalToken = address(0xFAFA);

    function testSetLocalToken() internal {
        // Add Local Token from Avax
        testAddGlobalToken();

        // Encode Data
        bytes memory data = abi.encode(newAvaxAssetGlobalAddress, newAvaxAssetLocalToken, "UnderLocal Coin", "UL");

        // Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        // Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            1,
            packedData,
            GasParams(0.5 ether, 0.5 ether),
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

    //////////////////////////////////////////////////////////////////////////   HELPERS   ////////////////////////////////////////////////////////////////////

    function encodeCallNoDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) private returns (bool success) {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x01), nonce++, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        success = RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallNoDepositSigned(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        address _user,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) private returns (bool success) {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x04), _user, nonce++, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        success = RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDeposit(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) private returns (bool success) {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        success = RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, _data
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositMultiple(
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _srcChainIdId
    ) private returns (bool success) {
        //Get some gas
        vm.deal(lzEndpointAddress, _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        success = RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _srcChainIdId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, _data
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function _encodeSigned(
        uint32,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _data
    ) internal returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x05), _user, nonce++, _hToken, _token, _amount, _deposit, _data);
    }

    function _encodeMultipleSigned(
        uint32,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _data
    ) internal returns (bytes memory inputCalldata) {
        // Encode Data
        inputCalldata = abi.encodePacked(
            bytes1(0x06), _user, uint8(_hTokens.length), nonce++, _hTokens, _tokens, _amounts, _deposits, _data
        );
    }
}
