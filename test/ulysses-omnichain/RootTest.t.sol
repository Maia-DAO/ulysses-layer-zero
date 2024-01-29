//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./helpers/ImportHelper.sol";

import "./helpers/RootForkHelper.t.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract RootTest is Test, BridgeAgentConstants {
    using SafeTransferLib for address;
    using BaseBranchRouterHelper for BaseBranchRouter;
    using BranchBridgeAgentHelper for BranchBridgeAgent;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    // Consts

    uint16 constant rootChainId = uint16(42161);

    uint16 constant avaxChainId = uint16(43114);

    uint16 constant ftmChainId = uint16(2040);

    //// System contracts

    // Root

    RootPort rootPort;

    ERC20hTokenRootFactory hTokenFactory;

    RootBridgeAgentFactory bridgeAgentFactory;

    RootBridgeAgent coreBridgeAgent;

    RootBridgeAgent multicallBridgeAgent;

    CoreRootRouter coreRootRouter;

    MulticallRootRouter rootMulticallRouter;

    // Arbitrum Branch

    ArbitrumBranchPort arbitrumPort;

    ERC20hTokenBranchFactory localHTokenFactory;

    ArbitrumBranchBridgeAgentFactory arbitrumBranchBridgeAgentFactory;

    ArbitrumBranchBridgeAgent arbitrumCoreBridgeAgent;

    ArbitrumBranchBridgeAgent arbitrumMulticallBridgeAgent;

    ArbitrumCoreBranchRouter arbitrumCoreRouter;

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

    address arbitrumWrappedNativeToken;
    address avaxWrappedNativeToken;
    address ftmWrappedNativeToken;

    address arbitrumLocalWrappedNativeToken;
    address avaxLocalWrappedNativeToken;
    address ftmLocalWrappedNativeToken;

    address multicallAddress;

    address testGasPoolAddress = address(0xFFFF);

    address nonFungiblePositionManagerAddress = address(0xABAD);

    address avaxLocalarbitrumWrappedNativeTokenAddress = address(0xBFFF);
    address avaxUnderlyingarbitrumWrappedNativeTokenAddress = address(0xFFFB);

    address ftmLocalarbitrumWrappedNativeTokenAddress = address(0xABBB);
    address ftmUnderlyingarbitrumWrappedNativeTokenAddress = address(0xAAAB);

    address avaxCoreBridgeAgentAddress = address(0xBEEF);

    address avaxMulticallBridgeAgentAddress = address(0xEBFE);

    address avaxPortAddress = address(0xFEEB);

    address ftmCoreBridgeAgentAddress = address(0xCACA);

    address ftmMulticallBridgeAgentAddress = address(0xACAC);

    address ftmPortAddressM = address(0xABAC);

    address lzEndpointAddress = address(new MockEndpoint());

    address owner = address(this);

    address dao = address(this);

    address mockEcoystemToken = address(new MockERC20("ecosystem token", "ECO", 18));

    function setUp() public {
        /////////////////////////////////
        //      Deploy Root Utils      //
        /////////////////////////////////

        arbitrumWrappedNativeToken = address(new WETH());
        avaxWrappedNativeToken = address(new WETH());
        ftmWrappedNativeToken = address(new WETH());

        multicallAddress = address(new Multicall2());

        /////////////////////////////////
        //    Deploy Root Contracts    //
        /////////////////////////////////

        rootPort = new RootPort(rootChainId);

        bridgeAgentFactory = new RootBridgeAgentFactory(rootChainId, lzEndpointAddress, address(rootPort));

        coreRootRouter = new CoreRootRouter(rootChainId, address(rootPort));

        rootMulticallRouter = new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        hTokenFactory = new ERC20hTokenRootFactory(address(rootPort));

        /////////////////////////////////
        //  Initialize Root Contracts  //
        /////////////////////////////////

        rootPort.initialize(address(bridgeAgentFactory), address(coreRootRouter));

        vm.deal(address(rootPort), 1 ether);
        vm.prank(address(rootPort));
        WETH(arbitrumWrappedNativeToken).deposit{value: 1 ether}();

        hTokenFactory.initialize(address(coreRootRouter));

        coreBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(coreRootRouter)))
        );

        multicallBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(rootMulticallRouter)))
        );

        coreRootRouter.initialize(address(coreBridgeAgent), address(hTokenFactory));

        rootMulticallRouter.initialize(address(multicallBridgeAgent));

        /////////////////////////////////
        // Deploy Local Branch Contracts//
        /////////////////////////////////

        arbitrumPort = new ArbitrumBranchPort(rootChainId, address(rootPort), owner);

        arbitrumMulticallRouter = new ArbitrumBaseBranchRouter();

        arbitrumCoreRouter = new ArbitrumCoreBranchRouter();

        arbitrumBranchBridgeAgentFactory = new ArbitrumBranchBridgeAgentFactory(
            rootChainId, address(bridgeAgentFactory), address(arbitrumCoreRouter), address(arbitrumPort), owner
        );

        arbitrumPort.initialize(address(arbitrumCoreRouter), address(arbitrumBranchBridgeAgentFactory));

        arbitrumBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        arbitrumCoreBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(0)));

        arbitrumCoreRouter.initialize(address(arbitrumCoreBridgeAgent));
        // ArbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));

        //////////////////////////////////
        // Deploy Avax Branch Contracts //
        //////////////////////////////////

        avaxPort = new BranchPort(owner);

        avaxHTokenFactory = new ERC20hTokenBranchFactory(address(avaxPort), "Avalanche Ulysses ", "avax-u");

        avaxMulticallRouter = new BaseBranchRouter();

        avaxCoreRouter = new CoreBranchRouter(address(avaxHTokenFactory));

        avaxBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            avaxChainId,
            rootChainId,
            address(bridgeAgentFactory),
            lzEndpointAddress,
            address(avaxCoreRouter),
            address(avaxPort),
            owner
        );

        avaxPort.initialize(address(avaxCoreRouter), address(avaxBranchBridgeAgentFactory));

        avaxBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        avaxCoreBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(0)));

        avaxHTokenFactory.initialize(avaxWrappedNativeToken, address(avaxCoreRouter));
        avaxLocalWrappedNativeToken = 0x386Cc0A3450d41747C05C62381320C039C65ee0d;

        avaxCoreRouter.initialize(address(avaxCoreBridgeAgent));

        //////////////////////////////////
        // Deploy Ftm Branch Contracts //
        //////////////////////////////////

        ftmPort = new BranchPort(owner);

        ftmHTokenFactory = new ERC20hTokenBranchFactory(address(ftmPort), "Fantom Ulysses ", "ftm-u");

        ftmMulticallRouter = new BaseBranchRouter();

        ftmCoreRouter = new CoreBranchRouter(address(ftmHTokenFactory));

        ftmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId,
            rootChainId,
            address(bridgeAgentFactory),
            lzEndpointAddress,
            address(ftmCoreRouter),
            address(ftmPort),
            owner
        );

        ftmPort.initialize(address(ftmCoreRouter), address(ftmBranchBridgeAgentFactory));

        ftmBranchBridgeAgentFactory.initialize(address(coreBridgeAgent));
        ftmCoreBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(0)));

        ftmHTokenFactory.initialize(ftmWrappedNativeToken, address(ftmCoreRouter));
        ftmLocalWrappedNativeToken = 0x0315E8648695243BCE3Da6a0Ce973867B75Db847;

        ftmCoreRouter.initialize(address(ftmCoreBridgeAgent));

        /////////////////////////////
        //  Add new branch chains  //
        /////////////////////////////

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

        avaxGlobalToken = RootPort(rootPort).getGlobalTokenFromLocal(avaxLocalWrappedNativeToken, avaxChainId);

        ftmGlobalToken = RootPort(rootPort).getGlobalTokenFromLocal(ftmLocalWrappedNativeToken, ftmChainId);

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

        rootPort.initializeCore(address(coreBridgeAgent), address(arbitrumCoreBridgeAgent), address(arbitrumPort));

        multicallBridgeAgent.approveBranchBridgeAgent(rootChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(avaxChainId);

        multicallBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        ///////////////////////////////////////
        //  Add new branches to  Root Agents //
        ///////////////////////////////////////

        vm.deal(address(this), 3 ether);

        coreRootRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallBridgeAgent),
            address(avaxBranchBridgeAgentFactory),
            address(avaxMulticallRouter),
            address(this),
            avaxChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        coreRootRouter.addBranchToBridgeAgent{value: 1 ether}(
            address(multicallBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(ftmMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        coreRootRouter.addBranchToBridgeAgent(
            address(multicallBridgeAgent),
            address(arbitrumBranchBridgeAgentFactory),
            address(arbitrumMulticallRouter),
            address(this),
            rootChainId,
            [GasParams(0, 0), GasParams(0, 0)]
        );

        /////////////////////////////////////
        //  Initialize new Branch Routers  //
        /////////////////////////////////////

        arbitrumMulticallBridgeAgent = ArbitrumBranchBridgeAgent(payable(arbitrumPort.bridgeAgents(1)));
        avaxMulticallBridgeAgent = BranchBridgeAgent(payable(avaxPort.bridgeAgents(1)));
        ftmMulticallBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(1)));

        arbitrumMulticallRouter.initialize(address(arbitrumMulticallBridgeAgent));
        avaxMulticallRouter.initialize(address(avaxMulticallBridgeAgent));
        ftmMulticallRouter.initialize(address(ftmMulticallBridgeAgent));

        //////////////////////////////////////
        // Deploy Underlying Tokens and Mocks//
        //////////////////////////////////////

        // avaxMockAssethToken = new MockERC20("hTOKEN-AVAX", "LOCAL hTOKEN FOR TOKEN IN AVAX", 18);
        avaxMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        // ftmMockAssethToken = new MockERC20("hTOKEN-FTM", "LOCAL hTOKEN FOR TOKEN IN FMT", 18);
        ftmMockAssetToken = new MockERC20("underlying token", "UNDER", 18);

        // ArbitrumMockAssethToken is global
        arbitrumMockToken = new MockERC20("underlying token", "UNDER", 18);
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                             TEST HELPERS
    //////////////////////////////////////////////////////////////*/

    function _parseDepositAndWithdrawAmounts(uint256 _amount, uint256 _deposit)
        internal
        pure
        returns (uint256, uint256)
    {
        // Can't withdraw 0
        if (_amount == 0) return (1, 0);

        // We want to transfer at least 1 hToken
        if (_amount <= _deposit) return (_amount, _deposit % _amount);

        return (_amount, _deposit);
    }

    //////////////////////////////////////
    //      Bridge To Chain Amounts     //
    //////////////////////////////////////

    function test_bridgeToBranch_arbMockToken_fromRemoteBranch() public {
        test_bridgeToBranch_arbMockToken(address(this), 100 ether, 50 ether, ftmChainId);
    }

    function test_bridgeToBranch_arbMockToken_fromLocalBranch() public {
        test_bridgeToBranch_arbMockToken(address(this), 100 ether, 50 ether, rootChainId);
    }

    function test_bridgeToBranch_arbMockToken(address _from, uint256 _amount, uint256 _deposit, uint256 _dstChainId)
        public
    {
        (_amount, _deposit) = _parseDepositAndWithdrawAmounts(_amount, _deposit);

        // Add arbitrumMockToken to the ecosystem as underlying
        testAddLocalTokenArbitrum();

        _test_bridgeToBranch(_from, newArbitrumAssetGlobalAddress, _amount, _deposit, _dstChainId);
    }

    function test_bridgeToBranch_ecosystemToken(address _from, uint256 _amount, uint256 _deposit, uint256 _dstChainId)
        public
    {
        (_amount, _deposit) = _parseDepositAndWithdrawAmounts(_amount, _deposit);

        // Add mockEcoystemToken as ecosystem token
        testAddEcosystemToken();

        _test_bridgeToBranch(_from, mockEcoystemToken, _amount, _deposit, _dstChainId);
    }

    function _test_bridgeToBranch(
        address _from,
        address _hToken,
        uint256 _amount,
        uint256 _deposit,
        uint256 _dstChainId
    ) internal {
        vm.prank(address(rootPort));
        MockERC20(_hToken).mint(_from, _amount);

        vm.prank(_from);
        _hToken.safeApprove(address(rootPort), _amount);

        uint256 priorBalanceOfFrom = _hToken.balanceOf(_from);
        uint256 priorBalanceOfPort = _hToken.balanceOf(address(rootPort));
        uint256 priorBalanceOfBranch = rootPort.getBalanceOfBranch(_hToken, _dstChainId);
        uint256 priorTotalSupplyBranch = rootPort.getTotalSupplyBranches(_hToken);

        vm.prank(address(multicallBridgeAgent));
        rootPort.bridgeToBranch(_from, _hToken, _amount, _deposit, _dstChainId);

        uint256 balanceDiff = _amount - _deposit;

        assertEq(_hToken.balanceOf(_from), priorBalanceOfFrom - _amount);
        assertEq(_hToken.balanceOf(address(rootPort)), priorBalanceOfPort + balanceDiff);

        if (_dstChainId != rootChainId) {
            assertEq(rootPort.getBalanceOfBranch(_hToken, _dstChainId), priorBalanceOfBranch + balanceDiff);
            assertEq(rootPort.getTotalSupplyBranches(_hToken), priorTotalSupplyBranch + balanceDiff);
        } else {
            assertEq(rootPort.getBalanceOfBranch(_hToken, _dstChainId), priorBalanceOfBranch);
            assertEq(rootPort.getTotalSupplyBranches(_hToken), priorTotalSupplyBranch);
        }
    }

    function test_bridgeToRoot_arbMockToken_fromRemoteBranch() public {
        test_bridgeToRoot_arbMockToken(address(this), 100 ether, 50 ether, ftmChainId);
    }

    function test_bridgeToRoot_arbMockToken_fromLocalBranch() public {
        test_bridgeToRoot_arbMockToken(address(this), 100 ether, 50 ether, rootChainId);
    }

    function test_bridgeToRoot_arbMockToken(address _to, uint256 _amount, uint256 _deposit, uint256 _srcChainId)
        public
    {
        (_amount, _deposit) = _parseDepositAndWithdrawAmounts(_amount, _deposit);

        test_bridgeToBranch_arbMockToken(_to, _amount, _deposit, _srcChainId);

        _test_bridgeToRoot(_to, newArbitrumAssetGlobalAddress, _amount, _deposit, _srcChainId);
    }

    function test_bridgeToRoot_ecosystemToken(address _to, uint256 _amount, uint256 _deposit, uint256 _srcChainId)
        public
    {
        (_amount, _deposit) = _parseDepositAndWithdrawAmounts(_amount, _deposit);

        // Add mockEcoystemToken as ecosystem token
        testAddEcosystemToken();

        test_bridgeToBranch_ecosystemToken(_to, _amount, _deposit, _srcChainId);

        _test_bridgeToRoot(_to, mockEcoystemToken, _amount, _deposit, _srcChainId);
    }

    function _test_bridgeToRoot(address _to, address _hToken, uint256 _amount, uint256 _deposit, uint256 _srcChainId)
        internal
    {
        uint256 priorBalanceOfTo = _hToken.balanceOf(_to);
        uint256 priorBalanceOfPort = _hToken.balanceOf(address(rootPort));
        uint256 priorBalanceOfBranch = rootPort.getBalanceOfBranch(_hToken, _srcChainId);
        uint256 priorTotalSupplyBranch = rootPort.getTotalSupplyBranches(_hToken);

        vm.prank(address(multicallBridgeAgent));
        rootPort.bridgeToRoot(_to, _hToken, _amount, _deposit, _srcChainId);

        uint256 balanceDiff = _amount - _deposit;

        assertEq(_hToken.balanceOf(address(_to)), priorBalanceOfTo + _amount);
        assertEq(_hToken.balanceOf(address(rootPort)), priorBalanceOfPort - balanceDiff);

        if (_srcChainId != rootChainId) {
            assertEq(rootPort.getBalanceOfBranch(_hToken, _srcChainId), priorBalanceOfBranch - balanceDiff);
            assertEq(rootPort.getTotalSupplyBranches(_hToken), priorTotalSupplyBranch - balanceDiff);
        } else {
            assertEq(rootPort.getBalanceOfBranch(_hToken, _srcChainId), priorBalanceOfBranch);
            assertEq(rootPort.getTotalSupplyBranches(_hToken), priorTotalSupplyBranch);
        }
    }

    function test_bridgeToRoot_arbMockToken_ChainInsufficientBalance_ftm() public {
        test_bridgeToRoot_arbMockToken_ChainInsufficientBalance(
            address(this), 100 ether, 50 ether, ftmChainId, rootChainId
        );
    }

    function test_bridgeToRoot_arbMockToken_ChainInsufficientBalance_avax() public {
        test_bridgeToRoot_arbMockToken_ChainInsufficientBalance(
            address(this), 100 ether, 50 ether, avaxChainId, rootChainId
        );
    }

    function test_bridgeToRoot_arbMockToken_ChainInsufficientBalance(
        address _to,
        uint256 _amount,
        uint256 _deposit,
        uint256 _dstChainId,
        uint256 _srcChainId
    ) public {
        if (_amount == 0) _amount = 1;
        if (_dstChainId == _srcChainId) _dstChainId = _srcChainId == 0 ? 1 : _srcChainId - 1;
        if (_to == address(rootPort)) _to = address(1);

        (_amount, _deposit) = _parseDepositAndWithdrawAmounts(_amount, _deposit);

        // Bridge to a different branch
        test_bridgeToBranch_arbMockToken(_to, _amount, _deposit, _dstChainId);

        if (_srcChainId == rootChainId) {
            vm.expectRevert(IRootPort.InsufficientBalance.selector);
        } else {
            vm.expectRevert(stdError.arithmeticError);
        }
        vm.prank(address(multicallBridgeAgent));
        rootPort.bridgeToRoot(_to, newArbitrumAssetGlobalAddress, _amount, _deposit, _srcChainId);
    }

    function test_bridgeToRoot_arbMockToken_NoDeposit() public {
        test_bridgeToRoot_arbMockToken_NoDeposit(address(this), 100 ether, 0, avaxChainId);
    }

    function test_bridgeToRoot_arbMockToken_NoDeposit(
        address _to,
        uint256 _amount,
        uint256 _deposit,
        uint256 _srcChainId
    ) public {
        if (_amount == 0) _amount = 1;

        (_amount, _deposit) = _parseDepositAndWithdrawAmounts(_amount, _deposit);

        // Add arbitrumMockToken to the ecosystem as underlying
        testAddLocalTokenArbitrum();

        if (_srcChainId == rootChainId) {
            vm.expectRevert(IRootPort.InsufficientBalance.selector);
        } else {
            vm.expectRevert(stdError.arithmeticError);
        }
        vm.prank(address(multicallBridgeAgent));
        rootPort.bridgeToRoot(_to, newArbitrumAssetGlobalAddress, _amount, _deposit, _srcChainId);
    }

    function test_bridgeToLocalBranchFromRoot_arbMockToken() public {
        test_bridgeToLocalBranchFromRoot_arbMockToken(address(this), 100 ether);
    }

    function test_bridgeToLocalBranchFromRoot_arbMockToken(address _to, uint256 _amount) public {
        // Add arbitrumMockToken to the ecosystem as underlying
        testAddLocalTokenArbitrum();

        // Mock bridgeToRootFromLocalBranch
        vm.prank(address(rootPort));
        MockERC20(newArbitrumAssetGlobalAddress).mint(address(rootPort), _amount);

        _test_bridgeToLocalBranchFromRoot(_to, newArbitrumAssetGlobalAddress, _amount);
    }

    function test_bridgeToLocalBranchFromRoot_ecosystemToken(address _to, uint256 _amount) public {
        // Add mockEcoystemToken as ecosystem token
        testAddEcosystemToken();

        MockERC20(mockEcoystemToken).mint(address(rootPort), _amount);

        _test_bridgeToLocalBranchFromRoot(_to, mockEcoystemToken, _amount);
    }

    function _test_bridgeToLocalBranchFromRoot(address _to, address _hToken, uint256 _amount) internal {
        uint256 priorBalanceOfTo = _hToken.balanceOf(_to);
        uint256 priorBalanceOfPort = _hToken.balanceOf(address(rootPort));
        uint256 priorTotalSupplyBranch = rootPort.getTotalSupplyBranches(_hToken);

        vm.prank(address(arbitrumPort));
        rootPort.bridgeToLocalBranchFromRoot(_to, _hToken, _amount);

        assertEq(_hToken.balanceOf(address(_to)), priorBalanceOfTo + _amount);
        assertEq(_hToken.balanceOf(address(rootPort)), priorBalanceOfPort - _amount);

        assertEq(rootPort.getTotalSupplyBranches(_hToken), priorTotalSupplyBranch);
    }

    function test_bridgeToLocalBranchFromRoot_arbMockToken_ChainInsufficientBalance() public {
        test_bridgeToLocalBranchFromRoot_arbMockToken_ChainInsufficientBalance(address(this), 100 ether, ftmChainId);
    }

    function test_bridgeToLocalBranchFromRoot_arbMockToken_ChainInsufficientBalance(
        address _to,
        uint128 _amount,
        uint256 _dstChainId
    ) public {
        if (_amount == 0) _amount = 1;
        if (_dstChainId == rootChainId) _dstChainId = rootChainId == 0 ? 1 : rootChainId - 1;

        // Bridge to a different branch
        test_bridgeToBranch_arbMockToken(_to, _amount, 0, _dstChainId);

        vm.expectRevert(IRootPort.InsufficientBalance.selector);
        vm.prank(address(arbitrumPort));
        rootPort.bridgeToLocalBranchFromRoot(_to, newArbitrumAssetGlobalAddress, _amount);
    }

    function test_bridgeToLocalBranchFromRoot_arbMockToken_NoDeposit(address _to, uint256 _amount) public {
        if (_amount == 0) _amount = 1;

        // Add arbitrumMockToken to the ecosystem as underlying
        testAddLocalTokenArbitrum();

        vm.expectRevert(IRootPort.InsufficientBalance.selector);
        vm.prank(address(arbitrumPort));
        rootPort.bridgeToLocalBranchFromRoot(_to, newArbitrumAssetGlobalAddress, _amount);
    }

    //////////////////////////////////////
    //         Ecosystem Tokens         //
    //////////////////////////////////////

    function testAddEcosystemToken() public {
        testAddEcosystemToken(mockEcoystemToken);
    }

    function testAddEcosystemToken_NotTokenButPasses() public {
        testAddEcosystemToken(address(0xDEAD));
    }

    function testAddEcosystemToken(address _ecosystemToken) public {
        if (rootPort.isGlobalAddress(_ecosystemToken)) {
            vm.expectRevert(IRootPort.AlreadyAddedEcosystemToken.selector);
            rootPort.addEcosystemToken(_ecosystemToken);
            return;
        }

        rootPort.addEcosystemToken(_ecosystemToken);

        require(RootPort(rootPort).isGlobalAddress(_ecosystemToken), "Eco Token should be added");
        require(
            RootPort(rootPort).getGlobalTokenFromLocal(_ecosystemToken, rootChainId) == _ecosystemToken,
            "Eco Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromGlobal(_ecosystemToken, rootChainId) == _ecosystemToken,
            "Eco Token should be added"
        );
        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(_ecosystemToken, rootChainId) == address(0),
            "Eco Token should be added"
        );
        require(
            RootPort(rootPort).getLocalTokenFromUnderlying(_ecosystemToken, rootChainId) == address(0),
            "Eco Token should be added"
        );
    }

    function testAddEcosystemToken_AlreadyAdded_NoDeposit() public {
        // Add arbitrumMockToken to the ecosystem as underlying
        testAddLocalTokenArbitrum();

        // There are no deposits so the total supply should be 0
        require(MockERC20(newArbitrumAssetGlobalAddress).totalSupply() == 0, "TotalSupply should be 0");

        // The admin can still add an ecosystem token because there were no deposits
        testAddEcosystemToken(address(arbitrumMockToken));
    }

    function testAddEcosystemToken_AlreadyAdded_WithDeposit() public {
        // Add arbitrumMockToken to the ecosystem as underlying and make a deposit
        testCallOutWithDeposit();

        // The admin can no longer add an ecosystem token because there were deposits
        vm.expectRevert(IRootPort.AlreadyAddedEcosystemToken.selector);
        rootPort.addEcosystemToken(address(arbitrumMockToken));
    }

    function testAddEcosystemToken_AlreadyAdded_RootLocalToken() public {
        testAddEcosystemToken_AlreadyAdded_RootLocalToken(address(1), address(2), address(3));
    }

    function testAddEcosystemToken_AlreadyAdded_RootLocalToken(
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress
    ) public {
        // Addresses can't be zero and global and local addresses can't be the same
        address nonZeroAddress = address(0xCAFE);
        if (_globalAddress == address(0)) _globalAddress = nonZeroAddress;
        if (_localAddress == address(0)) _localAddress = nonZeroAddress;
        if (_underlyingAddress == address(0)) _underlyingAddress = nonZeroAddress;
        if (_globalAddress == _localAddress) {
            _localAddress = _globalAddress == nonZeroAddress ? address(0xDEAD) : nonZeroAddress;
        }

        // This should never happen, but testing adding an ecosystem token in case it does
        vm.prank(address(coreRootRouter));
        rootPort.setAddresses(_globalAddress, _localAddress, _underlyingAddress, rootChainId);

        assertFalse(rootPort.isGlobalAddress(_localAddress));
        assertNotEq(rootPort.getUnderlyingTokenFromLocal(_localAddress, rootChainId), address(0));

        // The admin can no longer add an ecosystem token because there were deposits
        vm.expectRevert(IRootPort.AlreadyAddedEcosystemToken.selector);
        rootPort.addEcosystemToken(_localAddress);
    }

    //////////////////////////////////////
    //           Bridge Agents          //
    //////////////////////////////////////

    function testAddBridgeAgent() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        // Get some gas
        vm.deal(address(this), 1 ether);

        // Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter =
            new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        // Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        // Create Branch Router
        BaseBranchRouter ftmTestRouter = new BaseBranchRouter();

        // Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        // Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        BranchBridgeAgent ftmTestBranchBridgeAgent = BranchBridgeAgent(payable(ftmPort.bridgeAgents(2)));

        ftmTestRouter.initialize(address(ftmTestBranchBridgeAgent));

        require(testRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == address(ftmTestBranchBridgeAgent));
    }

    function testAddBridgeAgentAlreadyAdded() public {
        testAddBridgeAgent();

        // Get some gas
        vm.deal(address(this), 1 ether);

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("AlreadyAddedBridgeAgent()"));

        // Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);
    }

    function testAddBridgeAgentAlreadyAddedOnSync() public {
        testAddBridgeAgent();

        vm.deal(address(this), 1 ether);

        vm.startPrank(address(coreRootRouter));

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("AlreadyAddedBridgeAgent()"));

        rootPort.syncBranchBridgeAgentWithRoot(address(9), address(testRootBridgeAgent), ftmChainId);
    }

    function testAddBridgeAgentNotAllowedOnSync() public {
        testAddBridgeAgent();

        vm.deal(address(this), 1 ether);

        vm.startPrank(address(coreRootRouter));

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("BridgeAgentNotAllowed()"));

        rootPort.syncBranchBridgeAgentWithRoot(address(9), address(testRootBridgeAgent), avaxChainId);
    }

    function testAddBridgeAgentTwice() public {
        testAddBridgeAgent();

        // Get some gas
        vm.deal(address(this), 1 ether);

        // Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter =
            new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(payable(rootPort.bridgeAgents(2)));

        vm.expectRevert(abi.encodeWithSignature("InvalidChainId()"));

        // Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );
    }

    function testAddBridgeAgentNotApproved() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        // Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter =
            new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        // Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        vm.expectRevert(abi.encodeWithSignature("UnauthorizedChainId()"));

        // Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );
    }

    function testAddBridgeAgentNotManager() public {
        // Get some gas
        vm.deal(address(89), 1 ether);

        // Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter =
            new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        // Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        vm.startPrank(address(89));

        vm.expectRevert(abi.encodeWithSignature("UnauthorizedCallerNotManager()"));
        // Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(ftmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );
    }

    function testAddBridgeAgentWrongBranchFactory() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        //Create Root Router
        MulticallRootRouter testMulticallRouter =
            new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        // Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        // Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        // Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(32),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    //////////////////////////////////////
    //        Bridge Agent Factory     //
    //////////////////////////////////////

    BranchBridgeAgentFactory public newFtmBranchBridgeAgentFactory;

    function testAddBridgeAgentFactory() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        newFtmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId, rootChainId, address(80), lzEndpointAddress, address(ftmCoreRouter), address(ftmPort), owner
        );

        coreRootRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(bridgeAgentFactory),
            address(newFtmBranchBridgeAgentFactory),
            address(this),
            ftmChainId,
            GasParams(0.05 ether, 0.05 ether)
        );

        require(ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Factory not enabled");
    }

    function testAddBridgeAgentFactoryUnrecognizedBridgeAgentFactory() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        newFtmBranchBridgeAgentFactory = new BranchBridgeAgentFactory(
            ftmChainId, rootChainId, address(80), lzEndpointAddress, address(ftmCoreRouter), address(ftmPort), owner
        );

        vm.expectRevert(abi.encodeWithSignature("UnrecognizedBridgeAgentFactory()"));
        coreRootRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(1),
            address(newFtmBranchBridgeAgentFactory),
            address(this),
            ftmChainId,
            GasParams(0.05 ether, 0.05 ether)
        );

        require(!ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Factory enabled");
    }

    function testAddBridgeAgentWrongRootFactory() public {
        testAddBridgeAgentFactory();

        // Get some gas
        vm.deal(address(this), 1 ether);

        // Create Root Bridge Agent
        MulticallRootRouter testMulticallRouter =
            new MulticallRootRouter(rootChainId, address(rootPort), multicallAddress);

        // Create Bridge Agent
        RootBridgeAgent testRootBridgeAgent = RootBridgeAgent(
            payable(RootBridgeAgentFactory(bridgeAgentFactory).createBridgeAgent(address(testMulticallRouter)))
        );

        // Initialize Router
        testMulticallRouter.initialize(address(testRootBridgeAgent));

        // Allow new branch
        testRootBridgeAgent.approveBranchBridgeAgent(ftmChainId);

        // Create Branch Bridge Agent
        coreRootRouter.addBranchToBridgeAgent{value: 0.05 ether}(
            address(testRootBridgeAgent),
            address(newFtmBranchBridgeAgentFactory),
            address(testMulticallRouter),
            address(this),
            ftmChainId,
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.02 ether, 0)]
        );

        require(
            RootBridgeAgent(testRootBridgeAgent).getBranchBridgeAgent(ftmChainId) == address(0),
            "Branch Bridge Agent should not be created"
        );
    }

    function testRemoveBridgeAgentFactory() public {
        // Add Factory
        testAddBridgeAgentFactory();

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.toggleBranchBridgeAgentFactory{value: 0.05 ether}(
            address(bridgeAgentFactory),
            address(newFtmBranchBridgeAgentFactory),
            address(this),
            ftmChainId,
            GasParams(0.05 ether, 0.05 ether)
        );

        require(!ftmPort.isBridgeAgentFactory(address(newFtmBranchBridgeAgentFactory)), "Should be disabled");
    }

    //////////////////////////////////////
    //    Root Bridge Agent Factory     //
    //////////////////////////////////////

    RootBridgeAgentFactory newRootBridgeAgentFactory;

    function testAddRootBridgeAgentFactory() public {
        // Add new Root Bridge Agent Factory
        newRootBridgeAgentFactory = newRootBridgeAgentFactory._deploy(rootChainId, lzEndpointAddress, rootPort);

        // Enable new Factory in Root
        rootPort.toggleBridgeAgentFactory(address(newRootBridgeAgentFactory));

        // Check addition to root port
        require(rootPort.isBridgeAgentFactory(address(newRootBridgeAgentFactory)), "Factory not enabled");
    }

    //////////////////////////////////////
    //           Port Strategies        //
    //////////////////////////////////////

    function testAddStrategyToken() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.toggleStrategyToken{value: 0.05 ether}(
            address(102), 7000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        assertTrue(ftmPort.isStrategyToken(address(102)));
        assertEq(ftmPort.getMinimumTokenReserveRatio(address(102)), 7000);
    }

    function testUpdateStrategyToken() public {
        testAddStrategyToken();

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.updateStrategyToken{value: 0.05 ether}(
            address(102), 8000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        assertTrue(ftmPort.isStrategyToken(address(102)));
        assertEq(ftmPort.getMinimumTokenReserveRatio(address(102)), 8000);
    }

    function testUpdateStrategyTokenUnrecognizedStrategyToken() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        // UnrecognizedStrategyToken();
        coreRootRouter.updateStrategyToken{value: 0.05 ether}(
            address(102), 8000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        assertFalse(ftmPort.isStrategyToken(address(102)));
        assertEq(ftmPort.getMinimumTokenReserveRatio(address(102)), 0);
    }

    function testAddStrategyTokenInvalidMinReserve() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InvalidMinimumReservesRatio()"));
        coreRootRouter.toggleStrategyToken{value: 0.05 ether}(
            address(102), 30000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        assertFalse(ftmPort.isStrategyToken(address(102)));
        assertEq(ftmPort.getMinimumTokenReserveRatio(address(102)), 0);
    }

    function testRemoveStrategyToken() public {
        // Add Token
        testAddStrategyToken();

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.toggleStrategyToken{value: 0.05 ether}(
            address(102), 10000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        assertFalse(ftmPort.isStrategyToken(address(102)));
        assertEq(ftmPort.getMinimumTokenReserveRatio(address(102)), 10000);
    }

    function testAddPortStrategy() public {
        // Add strategy token
        testAddStrategyToken();

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.togglePortStrategy{value: 0.05 ether}(
            address(50), address(102), 7000, 7000, address(this), ftmChainId, GasParams(0.05 ether, 0)
        );

        assertTrue(ftmPort.isPortStrategy(address(50), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(50), address(102)), 7000);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(50), address(102)), 7000);
    }

    function testRemovePortStrategy() public {
        // Add port strategy
        testAddPortStrategy();

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.togglePortStrategy{value: 0.05 ether}(
            address(50), address(102), 7000, 7000, address(this), ftmChainId, GasParams(0.05 ether, 0)
        );

        assertFalse(ftmPort.isPortStrategy(address(50), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(50), address(102)), 0);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(50), address(102)), 10000);
    }

    function testAddPortStrategyNotToken() public {
        // Get some gas
        vm.deal(address(this), 1 ether);

        // UnrecognizedStrategyToken();
        coreRootRouter.togglePortStrategy{value: 0.1 ether}(
            address(50), address(102), 7000, 7000, address(this), ftmChainId, GasParams(0.05 ether, 0.05 ether)
        );

        assertFalse(ftmPort.isPortStrategy(address(50), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(50), address(102)), 0);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(50), address(102)), 0);
    }

    function testUpdatePortStrategy() public {
        // Add port strategy
        testAddPortStrategy();

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.updatePortStrategy{value: 0.05 ether}(
            address(50), address(102), 8000, 8000, address(this), ftmChainId, GasParams(0.05 ether, 0)
        );

        assertTrue(ftmPort.isPortStrategy(address(50), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(50), address(102)), 8000);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(50), address(102)), 8000);
    }

    function testUpdatePortStrategyUnrecognizedStrategyToken() public {
        // Add port strategy
        testAddPortStrategy();

        // Get some gas
        vm.deal(address(this), 1 ether);

        // UnrecognizedStrategyToken();
        coreRootRouter.updatePortStrategy{value: 0.05 ether}(
            address(1), address(102), 8000, 8000, address(this), ftmChainId, GasParams(0.05 ether, 0)
        );

        assertTrue(ftmPort.isPortStrategy(address(50), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(50), address(102)), 7000);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(50), address(102)), 7000);

        assertFalse(ftmPort.isPortStrategy(address(1), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(1), address(102)), 0);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(1), address(102)), 0);
    }

    function testUpdatePortStrategyUnrecognizedPortStrategy() public {
        // Add port strategy
        testAddPortStrategy();

        // Get some gas
        vm.deal(address(this), 1 ether);

        // UnrecognizedStrategyToken();
        coreRootRouter.updatePortStrategy{value: 0.05 ether}(
            address(50), address(1), 8000, 8000, address(this), ftmChainId, GasParams(0.05 ether, 0)
        );

        assertTrue(ftmPort.isPortStrategy(address(50), address(102)));
        assertEq(ftmPort.strategyDailyLimitAmount(address(50), address(102)), 7000);
        assertEq(ftmPort.strategyReserveRatioManagementLimit(address(50), address(102)), 7000);
    }

    //////////////////////////////////////
    //            Core Setters          //
    //////////////////////////////////////

    CoreRootRouter newCoreRootRouter;
    RootBridgeAgent newCoreRootBridgeAgent;
    ERC20hTokenRootFactory newHTokenRootFactory;

    CoreBranchRouter newFtmCoreBranchRouter;
    BranchBridgeAgent newFtmCoreBranchBridgeAgent;
    ERC20hTokenBranchFactory newFtmHTokenFactory;

    function testSetBranchRouter() public {
        vm.deal(address(this), 1000 ether);

        // Deploy new root core

        newHTokenRootFactory = new ERC20hTokenRootFactory(address(rootPort));

        newCoreRootRouter = new CoreRootRouter(rootChainId, address(rootPort));

        newCoreRootBridgeAgent =
            RootBridgeAgent(payable(bridgeAgentFactory.createBridgeAgent(address(newCoreRootRouter))));

        // Init new root core

        newCoreRootRouter.initialize(address(newCoreRootBridgeAgent), address(newHTokenRootFactory));

        newHTokenRootFactory.initialize(address(newCoreRootRouter));

        // Deploy new Branch Core

        newFtmHTokenFactory = new ERC20hTokenBranchFactory(address(ftmPort), "Fantom", "FTM");

        newFtmCoreBranchRouter = new CoreBranchRouter(address(newFtmHTokenFactory));

        newFtmCoreBranchBridgeAgent = new BranchBridgeAgent(
            rootChainId,
            ftmChainId,
            address(newCoreRootBridgeAgent),
            lzEndpointAddress,
            address(newFtmCoreBranchRouter),
            address(ftmPort)
        );

        // Init new branch core

        newFtmCoreBranchRouter.initialize(address(newFtmCoreBranchBridgeAgent));

        newFtmHTokenFactory.initialize(address(ftmWrappedNativeToken), address(newFtmCoreBranchRouter));

        rootPort.setCoreBranchRouter{value: 1000 ether}(
            address(this),
            address(newFtmCoreBranchRouter),
            address(newFtmCoreBranchBridgeAgent),
            ftmChainId,
            GasParams(200_000, 0)
        );

        require(ftmPort.coreBranchRouterAddress() == address(newFtmCoreBranchRouter));
        require(ftmPort.isBridgeAgent(address(newFtmCoreBranchBridgeAgent)));

        ftmCoreRouter = newFtmCoreBranchRouter;
        ftmCoreBridgeAgent = newFtmCoreBranchBridgeAgent;
    }

    function testSetCoreRootRouter() public {
        testSetBranchRouter();

        // @dev Once all branches have been migrated we are ready to set the new root router
        rootPort.setCoreRootRouter(address(newCoreRootRouter), address(newCoreRootBridgeAgent));

        require(rootPort.coreRootRouterAddress() == address(newCoreRootRouter));
        require(rootPort.coreRootBridgeAgentAddress() == address(newCoreRootBridgeAgent));

        coreRootRouter = newCoreRootRouter;
        coreBridgeAgent = newCoreRootBridgeAgent;
    }

    function testSyncNewCoreBranchRouter() public {
        testSetCoreRootRouter();

        // @dev after setting the new root core we can sync each new branch one by one
        rootPort.syncNewCoreBranchRouter(
            address(newFtmCoreBranchRouter), address(newFtmCoreBranchBridgeAgent), ftmChainId
        );

        require(newCoreRootBridgeAgent.getBranchBridgeAgent(ftmChainId) == address(newFtmCoreBranchBridgeAgent));
    }

    //////////////////////////////////////
    //               Sweep              //
    //////////////////////////////////////

    function testSweepRootPort(uint128 amount) public {
        // Save previous balance
        uint256 prevBalance = address(this).balance;

        // Mock accumulated balance
        vm.deal(address(rootPort), amount);

        // Reques sweep to address(this)
        rootPort.sweep(address(this));

        // Check root port balance
        assertEq(address(rootPort).balance, 0);

        // Check this balance
        assertEq(address(this).balance, prevBalance + amount);
    }

    function testSweepBranchPort(uint128 amount) public {
        vm.deal(address(this), 1 ether);

        // Save previous balance
        uint256 prevBalance = address(this).balance - 0.05 ether;

        // Mock accumulated balance
        vm.deal(address(ftmPort), amount);

        // Reques sweep to address(this)
        coreRootRouter.sweep{value: 0.05 ether}(address(this), address(this), ftmChainId, GasParams(0.05 ether, 0));

        // Check root port balance
        assertEq(address(ftmPort).balance, 0, "Branch Port balance should be 0");

        // Check this balance
        assertEq(address(this).balance, prevBalance + amount, "This balance should be increased");
    }

    //////////////////////////////////////
    //          TOKEN MANAGEMENT        //
    //////////////////////////////////////

    address public newAvaxAssetGlobalAddress;

    function testAddLocalToken() public {
        vm.deal(address(this), 1 ether);

        avaxCoreRouter.addLocalToken{value: 0.1 ether}(address(avaxMockAssetToken), GasParams(0.5 ether, 0.5 ether));

        avaxMockAssethToken = RootPort(rootPort).getLocalTokenFromUnderlying(address(avaxMockAssetToken), avaxChainId);

        newAvaxAssetGlobalAddress = RootPort(rootPort).getGlobalTokenFromLocal(avaxMockAssethToken, avaxChainId);

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
        // Add Local Token from Avax
        testAddLocalToken();

        GasParams[3] memory gasParams =
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.05 ether, 0.0025 ether), GasParams(0.002 ether, 0)];

        avaxCoreRouter.addGlobalToken{value: 0.15 ether}(newAvaxAssetGlobalAddress, ftmChainId, gasParams);

        newAvaxAssetLocalToken = RootPort(rootPort).getLocalTokenFromGlobal(newAvaxAssetGlobalAddress, ftmChainId);

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
        // Set up
        testAddGlobalToken();

        // Get some gas.
        vm.deal(address(this), 1 ether);

        //Add new localToken
        arbitrumCoreRouter.addLocalToken{value: 0.0005 ether}(
            address(arbitrumMockToken), GasParams(0.5 ether, 0.5 ether)
        );

        newArbitrumAssetGlobalAddress =
            RootPort(rootPort).getLocalTokenFromUnderlying(address(arbitrumMockToken), rootChainId);

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

    address newArbitrumAssetLocalTokenAvax;

    function testAddGlobalTokenArbitrum() public {
        // Add Local Token from Arb
        testAddLocalTokenArbitrum();

        GasParams[3] memory gasParams =
            [GasParams(0.05 ether, 0.05 ether), GasParams(0.05 ether, 0.0025 ether), GasParams(0.002 ether, 0)];

        arbitrumCoreRouter.addGlobalToken{value: 0.15 ether}(newArbitrumAssetGlobalAddress, avaxChainId, gasParams);

        newArbitrumAssetLocalTokenAvax =
            RootPort(rootPort).getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress, avaxChainId);

        require(
            RootPort(rootPort).getLocalTokenFromGlobal(newArbitrumAssetGlobalAddress, avaxChainId)
                == newArbitrumAssetLocalTokenAvax,
            "Token should be added"
        );

        require(
            RootPort(rootPort).getUnderlyingTokenFromLocal(newArbitrumAssetLocalTokenAvax, avaxChainId) == address(0),
            "Underlying should not be added"
        );
    }

    function testGetUnderlyingTokenFromGlobal(
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _srcChainId
    ) public {
        // Set non-zero addresses and different global and local addresses
        address nonZeroAddress = address(0xCAFE);
        if (_globalAddress == address(0)) _globalAddress = nonZeroAddress;
        if (_localAddress == address(0)) _localAddress = nonZeroAddress;
        if (_underlyingAddress == address(0)) _underlyingAddress = nonZeroAddress;
        if (_globalAddress == _localAddress) _localAddress = address(0xDEAD);

        // Setup the mapping using setAddresses
        vm.prank(address(coreRootRouter));
        rootPort.setAddresses(_globalAddress, _localAddress, _underlyingAddress, _srcChainId);

        // Assert that the returned address matches the expected underlying address
        address returnedAddress = rootPort.getUnderlyingTokenFromGlobal(_globalAddress, _srcChainId);
        assertEq(returnedAddress, _underlyingAddress, "Underlying token address does not match expected value");
    }

    function testIsLocalToken() public {
        testIsLocalToken(address(0xBEEF), address(0xCAFE), address(0xDEAD), 10, 11);
    }

    function testIsLocalTokenSameChain() public {
        testIsLocalToken(address(0xBEEF), address(0xCAFE), address(0xDEAD), 10, 10);
    }

    function testIsLocalToken(
        address _srcChainLocalAddress,
        address _dstChainLocalAddress,
        address _globalAddress,
        uint256 _srcChainId,
        uint256 _dstChainId
    ) public {
        // Set non-zero addresses and different global and local addresses
        address nonZeroAddress = address(0xCAFE);
        if (_srcChainLocalAddress < address(2)) _srcChainLocalAddress = nonZeroAddress;
        if (_dstChainLocalAddress < address(2)) _dstChainLocalAddress = nonZeroAddress;
        if (_globalAddress < address(2)) _globalAddress = nonZeroAddress;
        if (_srcChainId == _dstChainId) _srcChainLocalAddress = _dstChainLocalAddress;

        // Setup the mappings using setAddresses and setLocalAddress
        vm.startPrank(address(coreRootRouter));
        rootPort.setAddresses(_globalAddress, _srcChainLocalAddress, address(1), _srcChainId);
        rootPort.setLocalAddress(_globalAddress, _dstChainLocalAddress, _dstChainId);
        vm.stopPrank();

        // Assert that isLocalToken returns true for a valid origin local token
        assertTrue(
            rootPort.isLocalToken(_srcChainLocalAddress, _srcChainId, _srcChainId), "Expected to be a valid local token"
        );

        // Assert that isLocalToken returns true for a valid destination local token
        assertTrue(
            rootPort.isLocalToken(_dstChainLocalAddress, _dstChainId, _srcChainId), "Expected to be a valid local token"
        );

        // Test with an invalid local address
        assertFalse(
            rootPort.isLocalToken(address(1), _srcChainId, _srcChainId), "Expected to be an invalid local token"
        );
    }

    //////////////////////////////////////
    //          TOKEN TRANSFERS         //
    //////////////////////////////////////

    function testCallOutWithDeposit() public {
        testFuzzCallOutWithDeposit(address(this), 100 ether, 100 ether, 100 ether, 50 ether);
    }

    function testFuzzCallOutWithDeposit(
        address _user,
        uint256 _amount,
        uint256 _deposit,
        uint256 _amountOut,
        uint256 _depositOut
    ) internal {
        // Set up
        testAddLocalTokenArbitrum();

        (_user, _amount, _deposit, _amountOut, _depositOut) =
            BranchBridgeAgentHelper.adjustValues(_user, _amount, _deposit, _amountOut, _depositOut);

        // Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
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
            arbitrumMockToken.mint(address(arbitrumPort), _amount - _deposit);
        }

        // Mint Underlying Token.
        if (_deposit > 0) arbitrumMockToken.mint(_user, _deposit);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: _amount,
            deposit: _deposit
        });

        // Call Deposit function
        vm.startPrank(_user);
        arbitrumMockToken.approve(address(arbitrumPort), _deposit);
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), _amount - _deposit);
        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(
            packedData, depositInput, GasParams(0.5 ether, 0.5 ether), true
        );
        vm.stopPrank();

        BranchBridgeAgent(arbitrumMulticallBridgeAgent)._testCreateDepositSingle(
            uint32(1), _user, address(newArbitrumAssetGlobalAddress), address(arbitrumMockToken), _amount, _deposit
        );

        address userAccount = address(RootPort(rootPort).getUserAccount(_user));

        require(
            MockERC20(arbitrumMockToken).balanceOf(address(arbitrumPort)) == _amount - _deposit + _deposit - _depositOut,
            "LocalPort tokens"
        );

        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(address(rootPort)) == 0, "RootPort tokens");

        require(MockERC20(arbitrumMockToken).balanceOf(_user) == _depositOut, "User tokens");

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == _amountOut - _depositOut, "User Global tokens"
        );

        require(
            MockERC20(newArbitrumAssetGlobalAddress).balanceOf(userAccount) == _amount - _amountOut,
            "User Account tokens"
        );
    }

    function testCallOutWithDepositFailed() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Prepare data that will make the callOutWithDeposit fail
        bytes memory packedData = "";

        address _user = address(0x420);

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
        vm.prank(address(avaxPort));
        ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
        rootPort.bridgeToBranch(
            address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
        );
        vm.stopPrank();

        // Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.startPrank(_user);

        // Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, false);

        vm.stopPrank();
    }

    function testRetrieveDeposit() public {
        testCallOutWithDepositFailed();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        avaxMulticallBridgeAgent.retrieveDeposit(depositNonce, GasParams(0.5 ether, 0.5 ether));

        Deposit memory deposit = avaxMulticallBridgeAgent.getDepositEntry(depositNonce);

        assertEq(deposit.status, STATUS_FAILED);
        assertEq(deposit.owner, _user);
    }

    function testRetrieveDepositAlreadyRetrieved() public {
        testRetrieveDeposit();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        vm.expectRevert(abi.encodeWithSignature("DepositAlreadyRetrieved()"));
        avaxMulticallBridgeAgent.retrieveDeposit(depositNonce, GasParams(0.5 ether, 0.5 ether));
    }

    function testRetrieveDepositAlreadyExecuted() public {
        testSettlementFailed();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        avaxMulticallBridgeAgent.retrieveDeposit(depositNonce, GasParams(0.5 ether, 0.5 ether));

        Deposit memory deposit = avaxMulticallBridgeAgent.getDepositEntry(depositNonce);

        assertEq(deposit.status, STATUS_SUCCESS);
        assertEq(deposit.owner, _user);

        assertEq(multicallBridgeAgent.executionState(avaxChainId, depositNonce), STATUS_DONE);
    }

    function testRetrieveDepositDoesNotExist() public {
        testCallOutWithDepositFailed();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.expectRevert(IBranchBridgeAgent.NotDepositOwner.selector);

        vm.prank(_user);
        avaxMulticallBridgeAgent.retrieveDeposit(10_000_000, GasParams(0.5 ether, 0.5 ether));

        Deposit memory deposit = avaxMulticallBridgeAgent.getDepositEntry(depositNonce);

        assertEq(deposit.status, STATUS_SUCCESS);
        assertEq(deposit.owner, _user);
    }

    function testRetrieveDepositMultipleAlreadyExecuted() public {
        testSettlementMultipleFailed();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        avaxMulticallBridgeAgent.retrieveDeposit(depositNonce, GasParams(0.5 ether, 0.5 ether));

        Deposit memory deposit = avaxMulticallBridgeAgent.getDepositEntry(depositNonce);

        assertEq(deposit.status, STATUS_SUCCESS);
        assertEq(deposit.owner, _user);

        assertEq(multicallBridgeAgent.executionState(avaxChainId, depositNonce), STATUS_DONE);
    }

    function testRedeemDeposit() public {
        testRetrieveDeposit();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        avaxMulticallBridgeAgent.redeemDeposit(depositNonce, _user, address(avaxMockAssethToken));

        Deposit memory deposit = avaxMulticallBridgeAgent.getDepositEntry(depositNonce);

        assertEq(deposit.status, 0);
        assertEq(deposit.owner, address(0));
    }

    function testRedeemDepositSingle() public {
        testRetrieveDeposit();

        address _user = address(0x420);

        uint32 depositNonce = avaxMulticallBridgeAgent.depositNonce() - 1;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        avaxMulticallBridgeAgent.redeemDeposit(depositNonce, _user);

        Deposit memory deposit = avaxMulticallBridgeAgent.getDepositEntry(depositNonce);

        assertEq(deposit.status, 0);
        assertEq(deposit.owner, address(0));
    }

    uint32 previousNonce;

    function testSettlementFailed() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Prepare data
        bytes memory packedData;

        address _user = address(0x420);

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            // Output Params
            OutputParams memory outputParams = OutputParams(_user, _user, newAvaxAssetGlobalAddress, 150 ether, 0);

            // RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, avaxChainId, GasParams(0, 0));

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }
        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
        vm.prank(address(avaxPort));
        ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
        rootPort.bridgeToBranch(
            address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
        );
        vm.stopPrank();

        // Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        //GasParams
        GasParams memory gasParams = GasParams(20_000_000, 0.5 ether);

        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        vm.startPrank(_user);

        // Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, false);

        vm.stopPrank();

        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

        previousNonce = settlementNonce;
    }

    function testSettlementMultipleFailed() public {
        // Set up
        testAddGlobalTokenArbitrum();

        // Prepare data
        bytes memory packedData;

        address _user = address(0x420);

        // Prepare output info arrays
        address[] memory outputTokens = new address[](2);
        uint256[] memory amountsOut = new uint256[](2);
        uint256[] memory depositsOut = new uint256[](2);

        // Prepare input token arrays
        address[] memory inputHTokenAddresses = new address[](2);
        address[] memory inputTokenAddresses = new address[](2);
        uint256[] memory inputTokenAmounts = new uint256[](2);
        uint256[] memory inputTokenDeposits = new uint256[](2);

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            outputTokens[0] = newAvaxAssetGlobalAddress;
            outputTokens[1] = newArbitrumAssetGlobalAddress;
            amountsOut[0] = 150 ether;
            amountsOut[1] = 150 ether;
            depositsOut[0] = 50 ether;
            depositsOut[1] = 0;

            // Output Params
            OutputMultipleParams memory outputParams =
                OutputMultipleParams(_user, _user, outputTokens, amountsOut, depositsOut);

            // RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, avaxChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x03), data);

            inputHTokenAddresses[0] = address(avaxMockAssethToken);
            inputTokenAddresses[0] = address(avaxMockAssetToken);
            inputTokenAmounts[0] = 150 ether;
            inputTokenDeposits[0] = 100 ether;

            inputHTokenAddresses[1] = address(avaxMockAssethToken);
            inputTokenAddresses[1] = address(avaxMockAssetToken);
            inputTokenAmounts[1] = 150 ether;
            inputTokenDeposits[1] = 100 ether;
        }

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 300 ether);
        vm.prank(address(avaxPort));
        ERC20hToken(avaxMockAssethToken).mint(_user, 100 ether);

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 100 ether);
        rootPort.bridgeToBranch(
            address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 300 ether, 200 ether, avaxChainId
        );

        address virtualAccount = address(rootPort.fetchVirtualAccount(_user));

        vm.stopPrank();

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newArbitrumAssetGlobalAddress).mint(virtualAccount, 150 ether);

        // Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 200 ether);

        // Prepare deposit info
        DepositMultipleInput memory depositInput = DepositMultipleInput({
            hTokens: inputHTokenAddresses,
            tokens: inputTokenAddresses,
            amounts: inputTokenAmounts,
            deposits: inputTokenDeposits
        });

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        vm.startPrank(_user);

        // Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 200 ether);

        avaxMulticallBridgeAgent.callOutSignedAndBridgeMultiple{value: 1 ether}(
            packedData, depositInput, gasParams, false
        );

        vm.stopPrank();

        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

        previousNonce = settlementNonce;
    }

    function testRetrySettlement() public {
        testSettlementFailed();

        address _user = address(0x420);

        uint32 settlementNonce = previousNonce;

        // Get some gas.
        vm.deal(_user, 1 ether);

        vm.prank(_user);
        //Retry Settlement
        rootMulticallRouter.retrySettlement{value: 1 ether}(
            settlementNonce, address(this), "", GasParams(0.5 ether, 0.5 ether), true
        );

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

        require(avaxMulticallBridgeAgent.executionState(settlementNonce) == 1, "Settelement Executed in branch");
    }

    function testRetrySettlementMultiple() public {
        testSettlementMultipleFailed();

        address _user = address(0x420);

        uint32 settlementNonce = previousNonce;

        // Get some gas.
        vm.deal(_user, 1 ether);

        vm.prank(_user);
        //Retry Settlement
        rootMulticallRouter.retrySettlement{value: 1 ether}(
            settlementNonce, address(this), "", GasParams(0.5 ether, 0.5 ether), true
        );

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

        require(avaxMulticallBridgeAgent.executionState(settlementNonce) == 1, "Settelement Executed in branch");
    }

    function testRetrySettlementFromBranch() public {
        testSettlementFailed();

        address _user = address(0x420);

        uint32 settlementNonce = previousNonce;

        GasParams[2] memory gParams = [GasParams(0.5 ether, 1 ether), GasParams(0.5 ether, 0.5 ether)];

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        //Retry Settlement
        avaxMulticallBridgeAgent.retrySettlement{value: 1 ether}(settlementNonce, "", gParams, true);

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

        require(avaxMulticallBridgeAgent.executionState(settlementNonce) == 1, "Settelement Executed in branch");
    }

    function testRetrieveSettlement() public {
        testSettlementFailed();

        address _user = address(0x420);

        uint32 settlementNonce = previousNonce;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.prank(_user);
        //Retry Settlement
        multicallBridgeAgent.retrieveSettlement{value: 1 ether}(settlementNonce, GasParams(0.5 ether, 0.5 ether));

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_FAILED, "Settlement status should be failed.");

        require(
            avaxMulticallBridgeAgent.executionState(settlementNonce) == STATUS_RETRIEVE,
            "Settelement Executed in branch"
        );
    }

    function testAlreadyRetrieveSettlement() public {
        testRetrieveSettlement();

        address _user = address(0x420);

        uint32 settlementNonce = previousNonce;

        // Get some gas.
        vm.deal(_user, 10 ether);

        vm.expectRevert(IRootBridgeAgent.SettlementRedeemUnavailable.selector);
        vm.prank(_user);
        //Retry Settlement
        multicallBridgeAgent.retrieveSettlement{value: 1 ether}(settlementNonce, GasParams(0.5 ether, 0.5 ether));

        vm.stopPrank();

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_FAILED, "Settlement status should be failed.");

        require(
            avaxMulticallBridgeAgent.executionState(settlementNonce) == STATUS_RETRIEVE,
            "Settelement Executed in branch"
        );
    }

    function testRetryTwoSettlements() public {
        // Set up
        testAddLocalTokenArbitrum();

        address _user = address(0x420);

        {
            // Prepare data
            bytes memory _packedData;

            {
                Multicall2.Call[] memory calls = new Multicall2.Call[](1);

                // Mock Omnichain dApp call
                calls[0] = Multicall2.Call({
                    target: newAvaxAssetGlobalAddress,
                    callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
                });

                // Output Params
                OutputParams memory outputParams = OutputParams(_user, _user, newAvaxAssetGlobalAddress, 150 ether, 0);

                // RLP Encode Calldata Call with no gas to bridge out and we top up.
                bytes memory data = abi.encode(calls, outputParams, avaxChainId);

                // Pack FuncId
                _packedData = abi.encodePacked(bytes1(0x02), data);
            }

            // Get some gas.
            vm.deal(_user, 1 ether);

            // Assure there is enough balance for mock action
            vm.prank(address(rootPort));
            ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
            vm.prank(address(avaxPort));
            ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

            vm.startPrank(address(multicallBridgeAgent));
            ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
            rootPort.bridgeToBranch(
                address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
            );
            vm.stopPrank();

            // Mint Underlying Token.
            avaxMockAssetToken.mint(_user, 100 ether);

            // Prepare deposit info
            DepositInput memory depositInput = DepositInput({
                hToken: address(avaxMockAssethToken),
                token: address(avaxMockAssetToken),
                amount: 150 ether,
                deposit: 100 ether
            });

            //Set MockEndpoint _fallback mode ON
            MockEndpoint(lzEndpointAddress).toggleFallback(1);

            //GasParams
            GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

            vm.startPrank(_user);

            // Call Deposit function
            avaxMockAssetToken.approve(address(avaxPort), 100 ether);

            avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(_packedData, depositInput, gasParams, false);

            //Set MockEndpoint _fallback mode OFF
            MockEndpoint(lzEndpointAddress).toggleFallback(0);

            uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

            Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

            require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

            // Get some gas.
            vm.deal(_user, 1 ether);

            //Retry Settlement
            rootMulticallRouter.retrySettlement{value: 1 ether}(
                settlementNonce, address(_user), "", GasParams(0.5 ether, 0.5 ether), true
            );

            vm.stopPrank();

            settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

            require(settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

            require(avaxMulticallBridgeAgent.executionState(settlementNonce) == 1, "Settelement Executed in branch");
        }

        // Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            // Output Params
            OutputParams memory outputParams = OutputParams(_user, _user, newAvaxAssetGlobalAddress, 150 ether, 0);

            // RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, avaxChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
        vm.prank(address(avaxPort));
        ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
        rootPort.bridgeToBranch(
            address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
        );
        vm.stopPrank();

        // Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        // Prepare deposit info
        DepositInput memory _depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        //Set MockEndpoint _fallback mode ON
        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        //GasParams
        GasParams memory _gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.startPrank(_user);

        // Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, _depositInput, _gasParams, false);

        //Set MockEndpoint _fallback mode OFF
        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        uint32 _settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory _settlement = multicallBridgeAgent.getSettlementEntry(_settlementNonce);

        require(_settlement.status == STATUS_SUCCESS, "Settlement status should be success.");

        // Get some gas.
        vm.deal(_user, 1 ether);

        //Retry Settlement
        rootMulticallRouter.retrySettlement{value: 1 ether}(
            _settlementNonce, address(_user), "", GasParams(0.5 ether, 0.5 ether), true
        );

        vm.stopPrank();

        _settlement = multicallBridgeAgent.getSettlementEntry(_settlementNonce);

        require(_settlement.status == STATUS_SUCCESS, "_settlement status should be success.");

        require(avaxMulticallBridgeAgent.executionState(_settlementNonce) == 1, "Settelement Executed in branch");
    }

    function testRedeemSettlement() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

            // RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, avaxChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address _user = address(this);

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
        vm.prank(address(avaxPort));
        ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
        rootPort.bridgeToBranch(
            address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
        );
        vm.stopPrank();

        // Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        //Set MockEndpoint _fallback mode ON
        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        // Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);

        //Set MockEndpoint _fallback mode OFF
        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        //Perform _fallback transaction back to root bridge agent
        MockEndpoint(lzEndpointAddress).sendFallback();

        uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_FAILED, "Settlement status should be failed.");

        // Save port balance before
        uint256 portBalanceBefore = ERC20hToken(newAvaxAssetGlobalAddress).balanceOf(address(rootPort));

        uint256 tokenBranchBalanceBefore = rootPort.getBalanceOfBranch(newAvaxAssetGlobalAddress, avaxChainId);

        // Retry Settlement
        multicallBridgeAgent.redeemSettlement(settlementNonce, address(this));

        settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.owner == address(0), "Settlement should cease to exist.");

        require(
            MockERC20(newAvaxAssetGlobalAddress).balanceOf(address(rootPort)) == portBalanceBefore - 150 ether,
            "Port balance should decrease"
        );

        require(
            rootPort.getBalanceOfBranch(newAvaxAssetGlobalAddress, avaxChainId) == tokenBranchBalanceBefore - 150 ether,
            "Chain balance should decrease"
        );

        require(MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user) == 150 ether, "User balance should increase");
    }

    function testRedeemSettlementDestinationArbitrum() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Prepare data
        bytes memory packedData;

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
            calls[0] = Multicall2.Call({
                target: newArbitrumAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            // Output Params with wrong recipient for settlement failure
            OutputParams memory outputParams = OutputParams(
                address(this), address(newArbitrumAssetGlobalAddress), newArbitrumAssetGlobalAddress, 150 ether, 0
            );

            // RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, rootChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        address _user = address(this);

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        // vm.prank(address(rootPort));
        // ERC20hToken(newArbitrumAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
        vm.prank(address(rootPort));
        ERC20hToken(newArbitrumAssetGlobalAddress).mint(_user, 50 ether);

        // vm.startPrank(address(multicallBridgeAgent));
        // ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
        // rootPort.bridgeToBranch(
        // address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
        // );
        // vm.stopPrank();

        // Mint Underlying Token.
        arbitrumMockToken.mint(_user, 100 ether);

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(newArbitrumAssetGlobalAddress),
            token: address(arbitrumMockToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        // //Set MockEndpoint _fallback mode ON
        // MockEndpoint(lzEndpointAddress).toggleFallback(1);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        // Call Deposit function
        ERC20hToken(newArbitrumAssetGlobalAddress).approve(address(rootPort), 50 ether);
        arbitrumMockToken.approve(address(arbitrumPort), 100 ether);

        arbitrumMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);

        // //Set MockEndpoint _fallback mode OFF
        // MockEndpoint(lzEndpointAddress).toggleFallback(0);

        // //Perform _fallback transaction back to root bridge agent
        // MockEndpoint(lzEndpointAddress).sendFallback();

        // Retrieve Settlement since it was in retry mode

        uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;
        
        multicallBridgeAgent.retrieveSettlement(settlementNonce, GasParams(0, 0));

        Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.status == STATUS_FAILED, "Settlement status should be failed.");

        // Redeem Settlement
        multicallBridgeAgent.redeemSettlement(settlementNonce, address(this));

        settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

        require(settlement.owner == address(0), "Settlement should cease to exist.");

        require(MockERC20(newArbitrumAssetGlobalAddress).balanceOf(_user) == 150 ether, "User balance should increase");
    }

    function testRedeemSettlementRedeemUnavailable() public {
        // Save Nonce
        uint32 settlementNonce = multicallBridgeAgent.settlementNonce();

        // Expect Revert
        vm.expectRevert(IRootBridgeAgent.SettlementRedeemUnavailable.selector);

        // Retry Settlement
        multicallBridgeAgent.redeemSettlement(settlementNonce, address(this));
    }

    function testRedeemTwoSettlements() public {
        // Set up
        testAddLocalTokenArbitrum();

        // Prepare data
        bytes memory packedData;
        address _user = address(this);

        {
            {
                Multicall2.Call[] memory calls = new Multicall2.Call[](1);

                // Mock Omnichain dApp call
                calls[0] = Multicall2.Call({
                    target: newAvaxAssetGlobalAddress,
                    callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
                });

                // Output Params
                OutputParams memory outputParams =
                    OutputParams(address(this), address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

                // RLP Encode Calldata Call with no gas to bridge out and we top up.
                bytes memory data = abi.encode(calls, outputParams, avaxChainId);

                // Pack FuncId
                packedData = abi.encodePacked(bytes1(0x02), data);
            }

            // Get some gas.
            vm.deal(_user, 1 ether);

            // Assure there is enough balance for mock action
            vm.prank(address(rootPort));
            ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
            vm.prank(address(avaxPort));
            ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

            vm.startPrank(address(multicallBridgeAgent));
            ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
            rootPort.bridgeToBranch(
                address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
            );
            vm.stopPrank();

            // Mint Underlying Token.
            avaxMockAssetToken.mint(_user, 100 ether);

            // Prepare deposit info
            DepositInput memory depositInput = DepositInput({
                hToken: address(avaxMockAssethToken),
                token: address(avaxMockAssetToken),
                amount: 150 ether,
                deposit: 100 ether
            });

            //Set MockEndpoint _fallback mode ON
            MockEndpoint(lzEndpointAddress).toggleFallback(1);

            //GasParams
            GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

            // Call Deposit function
            avaxMockAssetToken.approve(address(avaxPort), 100 ether);

            avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, depositInput, gasParams, true);

            //Set MockEndpoint _fallback mode OFF
            MockEndpoint(lzEndpointAddress).toggleFallback(0);

            //Perform _fallback transaction back to root bridge agent
            MockEndpoint(lzEndpointAddress).sendFallback();

            uint32 settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

            Settlement memory settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

            require(settlement.status == STATUS_FAILED, "Settlement status should be failed.");

            // Retry Settlement
            multicallBridgeAgent.redeemSettlement(settlementNonce, _user);

            settlement = multicallBridgeAgent.getSettlementEntry(settlementNonce);

            require(settlement.owner == address(0), "Settlement should cease to exist.");

            require(
                MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user) == 150 ether,
                "Settlement should have been redeemed"
            );
        }

        {
            Multicall2.Call[] memory calls = new Multicall2.Call[](1);

            // Mock Omnichain dApp call
            calls[0] = Multicall2.Call({
                target: newAvaxAssetGlobalAddress,
                callData: abi.encodeWithSelector(bytes4(0xa9059cbb), mockApp, 0 ether)
            });

            // Output Params
            OutputParams memory outputParams =
                OutputParams(address(this), address(this), newAvaxAssetGlobalAddress, 150 ether, 0);

            // RLP Encode Calldata Call with no gas to bridge out and we top up.
            bytes memory data = abi.encode(calls, outputParams, avaxChainId);

            // Pack FuncId
            packedData = abi.encodePacked(bytes1(0x02), data);
        }

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Assure there is enough balance for mock action
        vm.prank(address(rootPort));
        ERC20hToken(newAvaxAssetGlobalAddress).mint(address(multicallBridgeAgent), 150 ether);
        vm.prank(address(avaxPort));
        ERC20hToken(avaxMockAssethToken).mint(_user, 50 ether);

        vm.startPrank(address(multicallBridgeAgent));
        ERC20hToken(newAvaxAssetGlobalAddress).approve(address(rootPort), 50 ether);
        rootPort.bridgeToBranch(
            address(multicallBridgeAgent), newAvaxAssetGlobalAddress, 150 ether, 100 ether, avaxChainId
        );
        vm.stopPrank();

        // Mint Underlying Token.
        avaxMockAssetToken.mint(_user, 100 ether);

        // Prepare deposit info
        DepositInput memory _depositInput = DepositInput({
            hToken: address(avaxMockAssethToken),
            token: address(avaxMockAssetToken),
            amount: 150 ether,
            deposit: 100 ether
        });

        //Set MockEndpoint _fallback mode ON
        MockEndpoint(lzEndpointAddress).toggleFallback(1);

        //GasParams
        GasParams memory _gasParams = GasParams(0.5 ether, 0.5 ether);

        // Call Deposit function
        avaxMockAssetToken.approve(address(avaxPort), 100 ether);

        avaxMulticallBridgeAgent.callOutSignedAndBridge{value: 1 ether}(packedData, _depositInput, _gasParams, true);

        //Set MockEndpoint _fallback mode OFF
        MockEndpoint(lzEndpointAddress).toggleFallback(0);

        //Perform _fallback transaction back to root bridge agent
        MockEndpoint(lzEndpointAddress).sendFallback();

        uint32 _settlementNonce = multicallBridgeAgent.settlementNonce() - 1;

        Settlement memory _settlement = multicallBridgeAgent.getSettlementEntry(_settlementNonce);

        require(_settlement.status == STATUS_FAILED, "Settlement status should be failed.");

        // Retry Settlement
        multicallBridgeAgent.redeemSettlement(_settlementNonce, _user);

        _settlement = multicallBridgeAgent.getSettlementEntry(_settlementNonce);

        require(_settlement.owner == address(0), "Settlement should cease to exist.");

        require(
            MockERC20(newAvaxAssetGlobalAddress).balanceOf(_user) == 300 ether, "Settlement should have been redeemed"
        );
    }

    function testAddChain() public {
        // Number of tokens before
        uint256 tokensLength = hTokenFactory.getHTokens().length;

        // Add new chain
        rootPort.addNewChain(address(0xBABA), 123, "GasToken", "GTKN", 18, address(0xFAFA), address(0xDADA));

        require(rootPort.isChainId(123), "new chain not added");

        require(hTokenFactory.getHTokens().length == tokensLength + 1);
    }

    function testAddChainAlreadyAdded() public {
        vm.expectRevert(abi.encodeWithSignature("AlreadyAddedChain()"));

        // Add new chain
        rootPort.addNewChain(address(0xBABA), 42161, "GasToken", "GTKN", 18, address(0xFAFA), address(0xDADA));
    }

    function test_transferManagementRole() public {
        _test_fuzz_transferManagementRole(multicallBridgeAgent, address(this), address(0xBEEF), address(0xBEEF));
    }

    function test_fuzz_transferManagementRole(address _newManager) public {
        _test_fuzz_transferManagementRole(multicallBridgeAgent, address(this), _newManager, _newManager);
    }

    function test_transferManagementRole_invalidOwner() public {
        _test_fuzz_transferManagementRole(multicallBridgeAgent, address(0xBEEF), address(0), address(0));
    }

    function test_transferManagementRole_newManagerIsZero() public {
        _test_fuzz_transferManagementRole(multicallBridgeAgent, address(this), address(0), address(0));
    }

    function test_transferManagementRole_callerIsNotPendingManager() public {
        _test_fuzz_transferManagementRole(multicallBridgeAgent, address(this), address(this), address(0xBEEF));
    }

    function test_transferManagementRole_invalidRootBridgeAgent() public {
        RootBridgeAgent rootBridgeAgent = new RootBridgeAgent(100, address(1), address(rootPort), address(1));

        _test_fuzz_transferManagementRole(rootBridgeAgent, address(0), address(0xBEEF), address(0xBEEF));
    }

    function _test_fuzz_transferManagementRole(
        RootBridgeAgent _rootBridgeAgent,
        address _transferCaller,
        address _acceptCaller,
        address _newManager
    ) internal {
        bool hasReverted;

        if (rootPort.getBridgeAgentManager(address(_rootBridgeAgent)) != _transferCaller) {
            hasReverted = true;
            // If invalid owner, revert
            vm.expectRevert(IRootBridgeAgent.UnrecognizedBridgeAgentManager.selector);
        } else if (_newManager == address(0)) {
            hasReverted = true;
            // If new manager is zero, revert
            vm.expectRevert(IRootBridgeAgent.InvalidInputParams.selector);
        }

        vm.prank(_transferCaller);
        _rootBridgeAgent.transferManagementRole(_newManager);

        if (!rootPort.isBridgeAgent(address(_rootBridgeAgent))) {
            hasReverted = true;
            // If invalid root bridge agent, revert
            vm.expectRevert(IRootPort.UnrecognizedBridgeAgent.selector);
        } else if (_rootBridgeAgent.pendingBridgeAgentManagerAddress() != _acceptCaller) {
            hasReverted = true;
            // If invalid pending manager, revert
            vm.expectRevert(IRootBridgeAgent.UnrecognizedBridgeAgentManager.selector);
        }

        vm.prank(_acceptCaller);
        _rootBridgeAgent.acceptManagementRole();

        if (!hasReverted) {
            assertEq(
                rootPort.getBridgeAgentManager(address(_rootBridgeAgent)), _newManager, "Manager should be updated"
            );
        }
    }

    function test_renounceOwnership() public {
        _test_renounceOwnership(address(this), rootPort);
    }

    function test_fuzz_renounceOwnership(bytes32 _salt, address _deployer, uint256 _localChainId) public {
        vm.prank(_deployer);
        _test_renounceOwnership(_deployer, new RootPort{salt: _salt}(_localChainId));
    }

    function _test_renounceOwnership(address _deployer, RootPort _rootPort) public {
        if (_deployer == address(this)) {
            vm.expectRevert(IRootPort.RenounceOwnershipNotAllowed.selector);
        } else {
            vm.expectRevert(Ownable.Unauthorized.selector);
        }
        _rootPort.renounceOwnership();
    }

    function test_getLocalToken() public {
        testAddGlobalToken();

        _test_getLocalToken(rootPort, newAvaxAssetLocalToken, ftmChainId, avaxChainId);
    }

    function test_getLocalToken(address _localAddress, uint256 _srcChainId, uint256 _dstChainId) public {
        testAddGlobalToken();

        _test_getLocalToken(rootPort, _localAddress, _srcChainId, _dstChainId);
    }

    function _test_getLocalToken(RootPort _rootPort, address _localAddress, uint256 _srcChainId, uint256 _dstChainId)
        public
    {
        assertEq(
            _rootPort.getLocalTokenFromGlobal(
                _rootPort.getGlobalTokenFromLocal(_localAddress, _srcChainId), _dstChainId
            ),
            _rootPort.getLocalToken(_localAddress, _srcChainId, _dstChainId)
        );
    }

    //////////////////////////////////////
    //         VIRTUAL ACCOUNTS         //
    //////////////////////////////////////

    function test_fetchVirtualAccount() public {
        _test_fetchVirtualAccount(rootPort, address(this));
    }

    function test_fetchVirtualAccount_twice() public {
        _test_fetchVirtualAccount(rootPort, address(this));
        _test_fetchVirtualAccount(rootPort, address(this));
    }

    function test_fuzz_fetchVirtualAccount(address _user) public {
        _test_fetchVirtualAccount(rootPort, _user);
    }

    function test_fuzz_fetchVirtualAccount_twice(address _user) public {
        if (_user == address(0)) _user = address(0xCAFE);
        _test_fetchVirtualAccount(rootPort, _user);
        _test_fetchVirtualAccount(rootPort, _user);
    }

    function test_fuzz_fetchVirtualAccount_twice(address _user1, address _user2) public {
        if (_user1 == address(0) && _user2 == address(0)) _user1 = address(0xCAFE);
        _test_fetchVirtualAccount(rootPort, _user1);
        _test_fetchVirtualAccount(rootPort, _user2);
    }

    function _test_fetchVirtualAccount(RootPort _rootPort, address _user) public {
        // Get virtual account (exists or is zero address)
        VirtualAccount virtualAccount = _rootPort.getUserAccount(_user);

        if (_user == address(0)) {
            assertEq(address(virtualAccount), address(0));

            vm.expectRevert(IRootPort.InvalidUserAddress.selector);
            virtualAccount = _rootPort.fetchVirtualAccount(_user);

            assertEq(address(virtualAccount), address(0));
            return;
        } else if (address(virtualAccount) != address(0)) {
            // If not zero address, should be equal to computed address
            assertEq(address(virtualAccount), ComputeVirtualAccount.computeAddress(address(_rootPort), _user));
        } else {
            vm.expectEmit(true, true, true, true);
            emit VirtualAccountCreated(_user, ComputeVirtualAccount.computeAddress(address(_rootPort), _user));
        }

        // Fetch virtual account, will create if not exists
        virtualAccount = _rootPort.fetchVirtualAccount(_user);

        // Check virtual account
        assertEq(address(virtualAccount), ComputeVirtualAccount.computeAddress(address(_rootPort), _user));
    }

    /// @notice Emitted when a new Virtual Account is created.
    event VirtualAccountCreated(address indexed user, address indexed account);
}

contract MockEndpoint is Test {
    uint256 constant rootChain = 42161;

    address public sourceBridgeAgent;
    address public destinationBridgeAgent;
    bytes public data;
    uint32 public nonce;
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
        console2.log("sourceBridgeAgent:", sourceBridgeAgent);
        console2.log("destinationBridgeAgent:", destinationBridgeAgent);
        console2.log("srcChainId:", BranchBridgeAgent(payable(sourceBridgeAgent)).localChainId());

        bytes memory fallbackData = abi.encodePacked(
            BranchBridgeAgent(payable(sourceBridgeAgent)).localChainId() == rootChain ? 0x09 : 0x04, nonce
        );

        // Perform Call
        RootBridgeAgent(payable(sourceBridgeAgent)).lzReceive{gas: 200_000}(
            BranchBridgeAgent(payable(destinationBridgeAgent)).localChainId(),
            abi.encodePacked(destinationBridgeAgent, sourceBridgeAgent),
            1,
            fallbackData
        );
    }

    /// @notice send a LayerZero message to the specified address at a LayerZero endpoint.
    /// @param _dstChainId - the destination chain identifier
    /// @param _destination - the address on destination chain (in bytes). address length/format may vary by chains
    /// @param _payload - a custom bytes payload to send to the destination contract
    /// @param  - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    /// @param  - the address of the ZRO token holder who would pay for the transaction
    /// @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
    function send(
        uint16 _dstChainId,
        bytes calldata _destination,
        bytes calldata _payload,
        address payable,
        address,
        bytes calldata _adapterParams
    ) external payable {
        sourceBridgeAgent = msg.sender;
        destinationBridgeAgent = address(bytes20(_destination[:20]));
        bytes memory path = abi.encodePacked(msg.sender, destinationBridgeAgent);
        data = _payload;

        nonce = _dstChainId == uint16(42161)
            ? BranchBridgeAgent(payable(msg.sender)).depositNonce() - 1
            : RootBridgeAgent(payable(msg.sender)).settlementNonce() - 1;

        console2.log("Mocking lzSends...");
        console2.log("sourceBridgeAgent:", msg.sender);
        console2.log("destinationBridgeAgent:", destinationBridgeAgent);
        console2.log("srcChainId:", BranchBridgeAgent(payable(msg.sender)).localChainId());

        // Decode adapter params
        if (_adapterParams.length > 0) {
            if (uint16(bytes2(_adapterParams[:2])) == 2) {
                gasLimit = uint256(bytes32(_adapterParams[2:34]));
                remoteBranchExecutionGas = uint256(bytes32(_adapterParams[34:66]));
                receiver = address(bytes20(_adapterParams[66:86]));
            } else if (uint16(bytes2(_adapterParams[:2])) == 1) {
                gasLimit = uint256(bytes32(_adapterParams[2:34]));
                remoteBranchExecutionGas = 0;
                receiver = address(0);
            } else {
                revert("Incorrect Adapter Params");
            }
        } else {
            gasLimit = 200_000;
            remoteBranchExecutionGas = 0;
            receiver = address(0);
        }

        if (!forceFallback) {
            // Perform Call
            destinationBridgeAgent.call{value: remoteBranchExecutionGas}("");

            RootBridgeAgent(payable(destinationBridgeAgent)).lzReceive{gas: gasLimit}(
                BranchBridgeAgent(payable(msg.sender)).localChainId(), path, 1, data
            );
        } else if (fallbackCountdown > 0) {
            console2.log("Execute LayerZero request...", fallbackCountdown--);
            // Perform Call
            destinationBridgeAgent.call{value: remoteBranchExecutionGas}("");
            RootBridgeAgent(payable(destinationBridgeAgent)).lzReceive{gas: gasLimit}(
                BranchBridgeAgent(payable(msg.sender)).localChainId(), path, 1, data
            );
        }
    }
}
