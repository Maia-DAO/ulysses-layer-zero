//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;
//TEST

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {stdError} from "forge-std/StdError.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

//COMPONENTS
import {RootPort} from "@omni/RootPort.sol";
import {ArbitrumBranchPort} from "@omni/ArbitrumBranchPort.sol";

import {RootBridgeAgent, WETH9} from "./mocks/MockRootBridgeAgent.t.sol";
import {BranchBridgeAgent} from "./mocks/MockBranchBridgeAgent.t.sol";
import {ArbitrumBranchBridgeAgent} from "@omni/ArbitrumBranchBridgeAgent.sol";

import {BaseBranchRouter} from "@omni/BaseBranchRouter.sol";
import {MulticallRootRouter} from "@omni/MulticallRootRouter.sol";
import {CoreRootRouter} from "@omni/CoreRootRouter.sol";
import {ArbitrumCoreBranchRouter} from "@omni/ArbitrumCoreBranchRouter.sol";

import {ERC20hTokenRoot} from "@omni/token/ERC20hTokenRoot.sol";
import {ERC20hTokenRootFactory} from "@omni/factories/ERC20hTokenRootFactory.sol";
import {ERC20hTokenBranchFactory} from "@omni/factories/ERC20hTokenBranchFactory.sol";
import {RootBridgeAgentFactory} from "@omni/factories/RootBridgeAgentFactory.sol";
import {BranchBridgeAgentFactory} from "@omni/factories/BranchBridgeAgentFactory.sol";
import {ArbitrumBranchBridgeAgentFactory} from "@omni/factories/ArbitrumBranchBridgeAgentFactory.sol";

//UTILS
import {DepositParams, DepositMultipleParams} from "./mocks/MockRootBridgeAgent.t.sol";
import {
    Deposit,
    DepositStatus,
    DepositMultipleInput,
    DepositInput,
    GasParams
} from "@omni/interfaces/IBranchBridgeAgent.sol";

import {WETH9 as WETH} from "./mocks/WETH9.sol";
import {Multicall2} from "./mocks/Multicall2.sol";

contract MulticallRootBridgeAgentTest is Test {
    uint32 nonce;

    MockERC20 avaxNativeAssethToken;

    MockERC20 avaxNativeToken;

    MockERC20 ftmNativeAssethToken;

    MockERC20 ftmNativeToken;

    MockERC20 rewardToken;

    ERC20hTokenRoot testToken;

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

    address localAnyCongfig = address(0xCAFF);

    address owner = address(this);

    address dao = address(this);

    function setUp() public {
        //Mock calls
        vm.mockCall(lzEndpointAddress, abi.encodeWithSignature("executor()"), abi.encode(lzEndpointAddress));

        vm.mockCall(lzEndpointAddress, abi.encodeWithSignature("config()"), abi.encode(localAnyCongfig));

        //Deploy Root Utils
        wrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        //Deploy Root Contracts
        rootPort = new RootPort(rootChainId, wrappedNativeToken);

        bridgeAgentFactory = new RootBridgeAgentFactory(
            rootChainId,
            WETH9(wrappedNativeToken),
            lzEndpointAddress,
            address(rootPort),
            dao
        );

        rootCoreRouter = new CoreRootRouter(rootChainId, wrappedNativeToken, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(
            rootChainId,
            address(rootPort),
            multicallAddress
        );

        hTokenFactory = new ERC20hTokenRootFactory(rootChainId, address(rootPort));

        //Initialize Root Contracts
        rootPort.initialize(address(bridgeAgentFactory), address(rootCoreRouter));

        vm.deal(address(rootPort), 1 ether);
        vm.prank(address(rootPort));
        WETH(wrappedNativeToken).deposit{value: 1 ether}();

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

        arbitrumMulticallRouter = new BaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter();

        localBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId,
            address(bridgeAgentFactory),
            WETH9(wrappedNativeToken),
            lzEndpointAddress,
            address(arbitrumCoreRouter),
            address(localPortAddress),
            owner
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

        //Sync Root with new branches

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

        //Mock calls
        vm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint16,uint160)",
                0x1FD5ad9D40e1154a91F1132C245f0480cf3deC89,
                wrappedNativeToken,
                uint16(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(wrappedNativeToken, 0x1FD5ad9D40e1154a91F1132C245f0480cf3deC89)))
        );

        RootPort(rootPort).addNewChain(
            avaxCoreBridgeAgentAddress,
            avaxChainId,
            "Avalanche",
            "AVAX",
            18,
            avaxLocalWrappedNativeTokenAddress,
            avaxUnderlyingWrappedNativeTokenAddress
        );

        //Mock calls
        vm.mockCall(
            nonFungiblePositionManagerAddress,
            abi.encodeWithSignature(
                "createAndInitializePoolIfNecessary(address,address,uint16,uint160)",
                0x1418E54090a03eA9da72C00B0B4f707181DcA8dd,
                wrappedNativeToken,
                uint16(100),
                uint160(200)
            ),
            abi.encode(address(new MockPool(wrappedNativeToken, 0x1418E54090a03eA9da72C00B0B4f707181DcA8dd)))
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

        //Ensure there are gas tokens from each chain in the system.
        vm.startPrank(address(rootPort));
        ERC20hTokenRoot(0x1FD5ad9D40e1154a91F1132C245f0480cf3deC89).mint(address(rootPort), 1 ether, avaxChainId);
        ERC20hTokenRoot(0x1418E54090a03eA9da72C00B0B4f707181DcA8dd).mint(address(rootPort), 1 ether, ftmChainId);
        vm.stopPrank();

        testToken = new ERC20hTokenRoot(
            rootChainId,
            address(bridgeAgentFactory),
            address(rootPort),
            "Hermes Global hToken 1",
            "hGT1",
            18
        );

        avaxNativeAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);

        avaxNativeToken = new MockERC20("underlying token", "UNDER", 18);

        ftmNativeAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);

        ftmNativeToken = new MockERC20("underlying token", "UNDER", 18);

        rewardToken = new MockERC20("hermes token", "HERMES", 18);
    }

    mapping(uint256 => uint32) public chainNonce;

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() internal {
        //Encode Data
        bytes memory data =
            abi.encode(address(avaxNativeToken), address(avaxNativeAssethToken), "UnderLocal Coin", "UL");

        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        uint32 _nonce = chainNonce[avaxChainId]++;

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            _nonce,
            packedData,
            gasParams,
            avaxChainId
        );

        newAvaxAssetGlobalAddress =
            RootPort(rootPort).getGlobalTokenFromLocal(address(avaxNativeAssethToken), avaxChainId);

        console2.log("New: ", newAvaxAssetGlobalAddress);

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
        //Add Local Token from Avax
        testAddLocalToken();

        GasParams memory _gasParams = GasParams(0.5 ether, 0.5 ether);

        GasParams[2] memory gasParams = [GasParams(0.5 ether, 0.5 ether), GasParams(0.5 ether, 0.5 ether)];

        //Encode Call Data
        bytes memory data = abi.encode(ftmCoreBridgeAgentAddress, newAvaxAssetGlobalAddress, ftmChainId, gasParams);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(ftmCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            chainNonce[avaxChainId]++,
            packedData,
            _gasParams,
            ftmChainId
        );
        //State change occurs in setLocalToken
    }

    address public newAvaxAssetLocalToken = address(0xFAFA);

    function testSetLocalToken() internal {
        //Add Local Token from Avax
        testAddGlobalToken();

        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Encode Data
        bytes memory data = abi.encode(newAvaxAssetGlobalAddress, newAvaxAssetLocalToken, "UnderLocal Coin", "UL");

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        //Call Deposit function
        encodeSystemCall(
            payable(avaxCoreBridgeAgentAddress),
            payable(address(coreBridgeAgent)),
            uint32(1),
            packedData,
            gasParams,
            avaxChainId
        );

        require(
            RootPort(rootPort).getGlobalTokenFromLocal(newAvaxAssetLocalToken, avaxChainId) == newAvaxAssetGlobalAddress,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, avaxChainId) == newAvaxAssetLocalToken,
            "Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(address(newAvaxAssetLocalToken), avaxChainId) == address(0),
            "Token should be added"
        );
    }

    address public mockApp = address(0xDAFA);

    function testMulticallNoOutputNoDeposit() public {
        vm.mockCall(mockApp, abi.encodeWithSignature("distro()"), abi.encode(0));

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        calls[0] =
            Multicall2.Call({target: mockApp, callData: abi.encodeWithSelector(bytes4(keccak256(bytes("distro()"))))});

        //RLP Encode Calldata
        bytes memory data = abi.encode(calls);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Call Deposit function
        encodeCallNoDeposit(
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            chainNonce[avaxChainId]++,
            packedData,
            gasParams,
            avaxChainId
        );
    }

    function testMulticallSignedNoOutputDepositSingle() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
        calls[0] = Multicall2.Call({
            target: newAvaxAssetGlobalAddress,
            callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
        });

        //RLP Encode Calldata
        bytes memory data = abi.encode(calls);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        encodeCallWithDepositSigned(
            address(this),
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            chainNonce[avaxChainId]++,
            address(newAvaxAssetLocalToken),
            address(avaxUnderlyingWrappedNativeTokenAddress),
            100 ether,
            100 ether,
            packedData,
            gasParams,
            avaxChainId
        );

        uint256 balanceAfter = MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(mockApp));

        require(balanceAfter == 100 ether, "Balance should be added");
    }

    function testMulticallSignedNoOutputDepositSingleNative() public {
        //Add Local Token from Avax
        testSetLocalToken();

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        Multicall2.Call[] memory calls = new Multicall2.Call[](1);

        //Prepare call to transfer 100 hAVAX form virtual account to Mock App (could be bribes)
        calls[0] = Multicall2.Call({
            target: newAvaxAssetGlobalAddress,
            callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 100 ether)
        });

        //RLP Encode Calldata
        bytes memory data = abi.encode(calls);

        //Pack FuncId
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Call Deposit function
        encodeCallWithDepositSigned(
            address(this),
            payable(avaxMulticallBridgeAgentAddress),
            payable(multicallBridgeAgent),
            chainNonce[avaxChainId]++,
            address(newAvaxAssetLocalToken),
            address(avaxUnderlyingWrappedNativeTokenAddress),
            100 ether,
            100 ether,
            packedData,
            gasParams,
            avaxChainId
        );
    }

    struct OutputParams {
        address recipient;
        address outputToken;
        uint256 amountOut;
        uint256 depositOut;
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
        vm.deal(address(this), _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

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
        vm.deal(address(this), _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);
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
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(address(this), _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata = abi.encodePacked(bytes1(0x02), _nonce, _hToken, _token, _amount, _deposit, _data);

        // Prank into user account
        vm.startPrank(lzEndpointAddress);

        _toBridgeAgent.call{value: _gasParams.remoteBranchExecutionGas}("");
        RootBridgeAgent(_toBridgeAgent).lzReceive{gas: _gasParams.gasLimit}(
            _fromChainId, abi.encodePacked(_fromBridgeAgent, _toBridgeAgent), 1, inputCalldata
        );

        // Prank out of user account
        vm.stopPrank();
    }

    function encodeCallWithDepositSigned(
        address _user,
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(address(this), _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data
        bytes memory inputCalldata =
            abi.encodePacked(bytes1(0x05), _user, _nonce, _hToken, _token, _amount, _deposit, _data);

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
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(address(this), _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data for cross-chain call.
        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x03), uint8(_hTokens.length), _nonce, _hTokens, _tokens, _amounts, _deposits, _data
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

    function encodeCallWithDepositMultipleSigned(
        address _user,
        address payable _fromBridgeAgent,
        address payable _toBridgeAgent,
        uint32 _nonce,
        address,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _data,
        GasParams memory _gasParams,
        uint16 _fromChainId
    ) private {
        //Get some gas
        vm.deal(address(this), _gasParams.gasLimit + _gasParams.remoteBranchExecutionGas);

        //Encode Data for cross-chain call.
        bytes memory inputCalldata = abi.encodePacked(
            bytes1(0x06), _user, uint8(_hTokens.length), _nonce, _hTokens, _tokens, _amounts, _deposits, _data
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

    function _encode(
        uint32 _nonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _data
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x05), _user, _nonce, _hToken, _token, _amount, _deposit, _data);
    }

    function _encodeMultiple(
        uint32 _nonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _data
    ) internal pure returns (bytes memory inputCalldata) {
        //Encode Data
        inputCalldata = abi.encodePacked(bytes1(0x06), _user, _nonce, _hTokens, _tokens, _amounts, _deposits, _data);
    }

    function compareDynamicArrays(bytes memory a, bytes memory b) public pure returns (bool aEqualsB) {
        assembly {
            aEqualsB := eq(a, b)
        }
    }
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
}

contract MockPool is Test {
    struct SwapCallbackData {
        address tokenIn;
    }

    address wrappedNativeTokenAddress;
    address globalGasToken;

    constructor(address _wrappedNativeTokenAddress, address _globalGasToken) {
        wrappedNativeTokenAddress = _wrappedNativeTokenAddress;
        globalGasToken = _globalGasToken;
    }

    function swap(address, bool zeroForOne, int256 amountSpecified, uint160, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1)
    {
        SwapCallbackData memory _data = abi.decode(data, (SwapCallbackData));

        address tokenOut = (_data.tokenIn == wrappedNativeTokenAddress ? globalGasToken : wrappedNativeTokenAddress);

        console2.log("GAS SWAP");
        console2.log("tokenIn:", _data.tokenIn);
        console2.log("tokenOut:", tokenOut);
        console2.log("isWrappedGasToken:");
        console2.log(_data.tokenIn != wrappedNativeTokenAddress);

        if (tokenOut == wrappedNativeTokenAddress) {
            // vm.deal(msg.sender)
            deal(address(this), uint256(amountSpecified));
            WETH(wrappedNativeTokenAddress).deposit{value: uint256(amountSpecified)}();
            MockERC20(wrappedNativeTokenAddress).transfer(msg.sender, uint256(amountSpecified));
        } else {
            deal({token: tokenOut, to: msg.sender, give: uint256(amountSpecified)});
        }
        console2.log(MockERC20(tokenOut).balanceOf(msg.sender));
        console2.log(amountSpecified);

        if (zeroForOne) {
            amount1 = amountSpecified;
        } else {
            amount0 = amountSpecified;
        }

        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
    }

    function slot0()
        external
        pure
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        )
    {
        return (100, 0, 0, 0, 0, 0, true);
    }
}
