//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./helpers/ImportHelper.sol";
import {BridgeAgentConstants} from "@omni/interfaces/BridgeAgentConstants.sol";

contract BranchPortTest is Test, BridgeAgentConstants {
    MockERC20 underlyingToken;

    MockERC20 rewardToken;

    ERC20hToken testToken;

    BaseBranchRouter bRouter;

    BranchBridgeAgent bAgent;

    uint16 rootChainId = uint16(42161);

    uint16 localChainId = uint16(1088);

    address rootBridgeAgentAddress = address(0xBEEF);

    address lzEndpointAddress = address(0xCAFE);

    address localPortAddress;

    address owner = address(this);

    bytes private rootBridgeAgentPath;

    bytes private branchBridgeAgentReceivedPath;

    function setUp() public {
        underlyingToken = new MockERC20("underlying token", "UNDER", 18);

        rewardToken = new MockERC20("hermes token", "HERMES", 18);

        localPortAddress = address(new BranchPort(owner));

        testToken = new ERC20hToken(address(this), "Test Ulysses Hermes underlying token", "test-uhUNDER",18);

        bRouter = new BaseBranchRouter();

        BranchPort(payable(localPortAddress)).initialize(address(bRouter), address(this));

        bAgent = new BranchBridgeAgent(
            rootChainId,
            localChainId,
            rootBridgeAgentAddress,
            lzEndpointAddress,
            address(bRouter),
            localPortAddress
        );

        bRouter.initialize(address(bAgent));

        BranchPort(payable(localPortAddress)).addBridgeAgent(address(bAgent));

        rootBridgeAgentPath = abi.encodePacked(rootBridgeAgentAddress, address(bAgent));

        vm.mockCall(lzEndpointAddress, "", "");
    }

    receive() external payable {}

    //////////////////////////////////////
    //           Port Strategies        //
    //////////////////////////////////////

    MockERC20 mockStrategyToken;

    function testAddStrategyToken() public {
        mockStrategyToken = new MockERC20("Token of the Port", "PORT TKN", 18);

        // Prank into router
        vm.prank(address(bRouter));

        // Add strategy token to port
        BranchPort(payable(localPortAddress)).toggleStrategyToken(address(mockStrategyToken), 7000);

        require(BranchPort(payable(localPortAddress)).isStrategyToken(address(mockStrategyToken)), "Should be added");
    }

    function testAddStrategyTokenInvalidMinReserve() public {
        // Prank into router
        vm.startPrank(address(bRouter));

        // Expect revert
        vm.expectRevert(abi.encodeWithSignature("InvalidMinimumReservesRatio()"));

        // Add strategy token to port
        BranchPort(payable(localPortAddress)).toggleStrategyToken(address(mockStrategyToken), 300);
    }

    function testRemoveStrategyToken() public {
        // Add Token
        testAddStrategyToken();

        // Prank into router
        vm.prank(address(bRouter));

        // Remove strategy token from port
        BranchPort(payable(localPortAddress)).toggleStrategyToken(address(mockStrategyToken), 0);

        require(!BranchPort(payable(localPortAddress)).isStrategyToken(address(mockStrategyToken)), "Should be removed");
    }

    address mockPortStrategyAddress;

    function testAddPortStrategy() public {
        // Add strategy token
        testAddStrategyToken();

        // Deploy Mock Strategy
        mockPortStrategyAddress = address(new MockPortStrategy());

        // Prank into router
        vm.prank(address(bRouter));

        // Toggle Port Strategy
        BranchPort(payable(localPortAddress)).togglePortStrategy(
            mockPortStrategyAddress, address(mockStrategyToken), 250 ether, 7000
        );

        // check is port strategy
        require(
            BranchPort(payable(localPortAddress)).isPortStrategy(mockPortStrategyAddress, address(mockStrategyToken)),
            "Should be added"
        );

        // check daily limit
        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitAmount(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 250 ether,
            "Should be 250 ether"
        );
    }

    function testAddPortStrategyLowerRatio() public {
        // Add strategy token
        testAddStrategyToken();

        // Deploy Mock Strategy
        mockPortStrategyAddress = address(new MockPortStrategy());

        // Prank into router
        vm.prank(address(bRouter));

        BranchPort(payable(localPortAddress)).togglePortStrategy(
            mockPortStrategyAddress, address(mockStrategyToken), 250 ether, 8000
        );

        require(
            BranchPort(payable(localPortAddress)).isPortStrategy(mockPortStrategyAddress, address(mockStrategyToken)),
            "Should be added"
        );
    }

    function testAddPortStrategyNotToken() public {
        // Prank into router
        vm.startPrank(address(bRouter));

        // Expect revert
        vm.expectRevert(abi.encodeWithSignature("UnrecognizedStrategyToken()"));

        //UnrecognizedStrategyToken();
        BranchPort(payable(localPortAddress)).togglePortStrategy(
            mockPortStrategyAddress, address(mockStrategyToken), 300, 7000
        );
    }

    function testManage() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Warp to present day
        vm.warp(1700495386);

        // Add token balance to port
        mockStrategyToken.mint(address(localPortAddress), 1000 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockStrategyToken.balanceOf(address(localPortAddress));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockStrategyToken.balanceOf(mockPortStrategyAddress);

        // Prank into strategy
        vm.prank(mockPortStrategyAddress);

        // Request management of assets
        BranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 250 ether);

        // Veriy if assets have been transfered
        require(
            mockStrategyToken.balanceOf(address(localPortAddress)) == portBalanceBefore - 250 ether,
            "Should be transfered"
        );

        require(
            mockStrategyToken.balanceOf(mockPortStrategyAddress) == strategyBalanceBefore + 250 ether,
            "Should be transfered"
        );

        require(
            BranchPort(payable(localPortAddress)).getPortStrategyTokenDebt(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 250 ether,
            "Should be 250 ether"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitAmount(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 250 ether,
            "Should be 250 ether"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitRemaining(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 0,
            "Should be zerod out"
        );
    }

    function testManageTwoDayLimits() public {
        // Add Strategy token and Port strategy
        testManage();

        // Warp 1 day
        vm.warp(block.timestamp + 1 days);

        // Add token balance to port (new deposits)
        mockStrategyToken.mint(address(localPortAddress), 1000 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockStrategyToken.balanceOf(address(localPortAddress));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockStrategyToken.balanceOf(mockPortStrategyAddress);

        // Prank into strategy
        vm.prank(mockPortStrategyAddress);

        // Request management of assets
        BranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 250 ether);

        // Veriy if assets have been transfered
        require(
            mockStrategyToken.balanceOf(address(localPortAddress)) == portBalanceBefore - 250 ether,
            "Should be transfered"
        );

        require(
            mockStrategyToken.balanceOf(mockPortStrategyAddress) == strategyBalanceBefore + 250 ether,
            "Should be transfered"
        );

        require(
            BranchPort(payable(localPortAddress)).getPortStrategyTokenDebt(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 500 ether,
            "Should be 500 ether"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitAmount(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 250 ether,
            "Should be 250 ether"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitRemaining(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 0,
            "Should be zerod out"
        );
    }

    function testManageExceedsMinimumReserves() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Add token balance to port
        mockStrategyToken.mint(address(localPortAddress), 1000 ether);

        // Prank into strategy
        vm.startPrank(mockPortStrategyAddress);

        // Expect revert
        vm.expectRevert(abi.encodeWithSignature("InsufficientReserves()"));

        // Request management of assets
        BranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 400 ether);
    }

    function testManageExceedsDailyLimit() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Add token balance to port
        mockStrategyToken.mint(address(localPortAddress), 1000 ether);

        // Prank into strategy
        vm.startPrank(mockPortStrategyAddress);

        // Expect revert
        vm.expectRevert();

        // Request management of assets
        BranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 300 ether);
    }

    function testManageExceedsStrategyDebtLimit() public {
        // Add Strategy token and Port strategy
        testAddPortStrategyLowerRatio();

        // Add token balance to port
        mockStrategyToken.mint(address(localPortAddress), 750 ether);

        // Prank into strategy
        vm.startPrank(mockPortStrategyAddress);

        // Expect revert
        vm.expectRevert();

        // Request management of assets
        BranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 225 ether);
    }

    function testReplenishAsStrategy() public {
        // Add Strategy token and Port strategy
        testManage();

        // Get port balance before manage
        uint256 portBalanceBefore = mockStrategyToken.balanceOf(address(localPortAddress));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockStrategyToken.balanceOf(mockPortStrategyAddress);

        // Prank into strategy
        vm.prank(mockPortStrategyAddress);

        // Request management of assets
        BranchPort(payable(localPortAddress)).replenishReserves(address(mockStrategyToken), 250 ether);

        // Veriy if assets have been transfered
        require(
            mockStrategyToken.balanceOf(address(localPortAddress)) == portBalanceBefore + 250 ether,
            "Should be transfered"
        );

        require(
            mockStrategyToken.balanceOf(mockPortStrategyAddress) == strategyBalanceBefore - 250 ether,
            "Should be returned"
        );

        require(
            BranchPort(payable(localPortAddress)).getPortStrategyTokenDebt(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 0,
            "Should be zerod"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitAmount(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 250 ether,
            "Should remain 250 ether"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitRemaining(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 0,
            "Should be zerod"
        );
    }

    function testReplenishAsUser() public {
        // Add Strategy token and Port strategy
        testManage();

        // Fake some port withdrawals
        // vm.prank(address(localPortAddress));
        MockERC20(mockStrategyToken).burn(address(localPortAddress), 500 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockStrategyToken.balanceOf(address(localPortAddress));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockStrategyToken.balanceOf(mockPortStrategyAddress);

        // Request management of assets
        BranchPort(payable(localPortAddress)).replenishReserves(mockPortStrategyAddress, address(mockStrategyToken));

        // Veriy if assets have been transfered up to the minimum reserves
        require(
            mockStrategyToken.balanceOf(address(localPortAddress)) == portBalanceBefore + 100 ether,
            "Should be transfered"
        );

        require(
            mockStrategyToken.balanceOf(mockPortStrategyAddress) == strategyBalanceBefore - 100 ether,
            "Should be returned"
        );

        require(
            BranchPort(payable(localPortAddress)).getPortStrategyTokenDebt(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 150 ether,
            "Should be decremented"
        );

        require(
            BranchPort(payable(localPortAddress)).strategyDailyLimitAmount(
                mockPortStrategyAddress, address(mockStrategyToken)
            ) == 250 ether,
            "Should remain 250 ether"
        );
    }

    function testReplenishAsStrategyNotEnoughDebtToRepay() public {
        // Add Strategy token and Port strategy
        testManage();

        // Prank into strategy
        vm.prank(mockPortStrategyAddress);

        // Expect revert
        vm.expectRevert();

        // Request management of assets
        BranchPort(payable(localPortAddress)).replenishReserves(address(mockStrategyToken), 300 ether);
    }

    // function expectLayerZeroSend(
    //     uint256 msgValue,
    //     bytes memory data,
    //     address refundee,
    //     GasParams memory gasParams,
    //     uint256 _baseGasCost
    // ) internal {
    //     vm.expectCall(
    //         lzEndpointAddress,
    //         msgValue,
    //         abi.encodeWithSelector(
    //             // "send(uint16,bytes,bytes,address,address,bytes)",
    //             ILayerZeroEndpoint.send.selector,
    //             rootChainId,
    //             rootBridgeAgentPath,
    //             data,
    //             refundee,
    //             address(0),
    //             _getAdapterParams(gasParams.gasLimit + _baseGasCost, gasParams.remoteBranchExecutionGas)
    //         )
    //     );
    // }

    // function testCreateDeposit(
    //     uint32 _depositNonce,
    //     address _user,
    //     address[] memory _hTokens,
    //     address[] memory _tokens,
    //     uint256[] memory _amounts,
    //     uint256[] memory _deposits
    // ) private view {
    //     // Get Deposit.
    //     Deposit memory deposit = bRouter.getDepositEntry(_depositNonce);

    //     // Check deposit
    //     require(deposit.owner == _user, "Deposit owner doesn't match");

    //     require(
    //         keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(_hTokens)),
    //         "Deposit local hToken doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(_tokens)),
    //         "Deposit underlying token doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(_amounts)),
    //         "Deposit amount doesn't match"
    //     );
    //     require(
    //         keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(_deposits)),
    //         "Deposit deposit doesn't match"
    //     );

    //     require(deposit.status == 0, "Deposit status should be success");

    //     for (uint256 i = 0; i < _hTokens.length; i++) {
    //         if (_amounts[i] - _deposits[i] > 0 && _deposits[i] == 0) {
    //             require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
    //         } else if (_amounts[i] - _deposits[i] > 0 && _deposits[i] > 0) {
    //             require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
    //             require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
    //             require(MockERC20(_tokens[i]).balanceOf(localPortAddress) == _deposits[i]);
    //         } else {
    //             require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
    //             require(MockERC20(_tokens[i]).balanceOf(localPortAddress) == _deposits[i]);
    //         }
    //     }
    // }

    // function testCreateDepositSingle(
    //     uint32 _depositNonce,
    //     address _user,
    //     address _hToken,
    //     address _token,
    //     uint256 _amount,
    //     uint256 _deposit
    // ) private {
    //     delete hTokens;
    //     delete tokens;
    //     delete amounts;
    //     delete deposits;
    //     // Cast to Dynamic TODO clean up
    //     hTokens = new address[](1);
    //     hTokens[0] = _hToken;
    //     tokens = new address[](1);
    //     tokens[0] = _token;
    //     amounts = new uint256[](1);
    //     amounts[0] = _amount;
    //     deposits = new uint256[](1);
    //     deposits[0] = _deposit;

    //     // Get Deposit
    //     Deposit memory deposit = bRouter.getDepositEntry(_depositNonce);

    //     // Check deposit
    //     require(deposit.owner == _user, "Deposit owner doesn't match");

    //     if (_amount != 0 || _deposit != 0) {
    //         require(
    //             keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(hTokens)),
    //             "Deposit local hToken doesn't match"
    //         );
    //         require(
    //             keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(tokens)),
    //             "Deposit underlying token doesn't match"
    //         );
    //         require(
    //             keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(amounts)),
    //             "Deposit amount doesn't match"
    //         );
    //         require(
    //             keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(deposits)),
    //             "Deposit deposit doesn't match"
    //         );
    //     }

    //     require(deposit.status == 0, "Deposit status should be succesful.");

    //     console2.log("TEST DEPOSIT");

    //     console2.logUint(amounts[0]);
    //     console2.logUint(deposits[0]);

    //     if (hTokens[0] != address(0) || tokens[0] != address(0)) {
    //         if (amounts[0] > 0 && deposits[0] == 0) {
    //             require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");

    //             require(MockERC20(hTokens[0]).balanceOf(localPortAddress) == 0, "Deposit hToken balance doesn't match");
    //         } else if (amounts[0] - deposits[0] > 0 && deposits[0] > 0) {
    //             console2.log(_user);
    //             console2.log(localPortAddress);

    //             require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");

    //             require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
    //             require(
    //                 MockERC20(tokens[0]).balanceOf(localPortAddress) == _deposit, "Deposit token balance doesn't match"
    //             );
    //         } else {
    //             require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
    //             require(
    //                 MockERC20(tokens[0]).balanceOf(localPortAddress) == _deposit, "Deposit token balance doesn't match"
    //             );
    //         }
    //     }
    // }

    // function makeTestCallWithDeposit(
    //     address _user,
    //     address _hToken,
    //     address _token,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     GasParams memory _gasParams
    // ) private {
    //     // Prepare deposit info
    //     DepositInput memory depositInput =
    //         DepositInput({hToken: _hToken, token: _token, amount: _amount, deposit: _deposit});

    //     // Prank into user account
    //     vm.startPrank(_user);

    //     // Get some gas.
    //     vm.deal(_user, 1 ether);

    //     // Approve spend by router
    //     ERC20hToken(_hToken).approve(address(bRouter), _amount - _deposit);
    //     MockERC20(_token).approve(address(bRouter), _deposit);

    //     //Call Deposit function
    //     IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, _gasParams);

    //     // Prank out of user account
    //     vm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDepositSingle(uint32(1), _user, address(_hToken), address(_token), _amount, _deposit);
    // }

    // function makeTestCallWithDepositSigned(
    //     address _user,
    //     address _hToken,
    //     address _token,
    //     uint256 _amount,
    //     uint256 _deposit,
    //     GasParams memory _gasParams,
    //     bool _hasFallbackToggled
    // ) private {
    //     // Prepare deposit info
    //     DepositInput memory depositInput =
    //         DepositInput({hToken: _hToken, token: _token, amount: _amount, deposit: _deposit});

    //     // Prank into user account
    //     vm.startPrank(_user);

    //     // Get some gas.
    //     vm.deal(_user, 1 ether);

    //     // Approve spend by router
    //     ERC20hToken(_hToken).approve(localPortAddress, _amount - _deposit);
    //     MockERC20(_token).approve(localPortAddress, _deposit);

    //     //Call Deposit function
    //     bAgent.callOutSignedAndBridge{value: 1 ether}(bytes("testdata"), depositInput, _gasParams, _hasFallbackToggled);

    //     // Prank out of user account
    //     vm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDepositSingle(uint32(1), _user, address(_hToken), address(_token), _amount, _deposit);
    // }

    // function makeTestCallWithDepositMultiple(
    //     address _user,
    //     address[] memory _hTokens,
    //     address[] memory _tokens,
    //     uint256[] memory _amounts,
    //     uint256[] memory _deposits,
    //     GasParams memory _gasParams
    // ) private {
    //     //Prepare deposit info
    //     DepositMultipleInput memory depositInput =
    //         DepositMultipleInput({hTokens: _hTokens, tokens: _tokens, amounts: _amounts, deposits: _deposits});

    //     // Prank into user account
    //     vm.startPrank(_user);

    //     // Get some gas.
    //     vm.deal(_user, 1 ether);

    //     console2.log(_hTokens[0], _deposits[0]);

    //     // Approve spend by router
    //     MockERC20(_hTokens[0]).approve(address(bRouter), _amounts[0] - _deposits[0]);
    //     MockERC20(_tokens[0]).approve(address(bRouter), _deposits[0]);
    //     MockERC20(_hTokens[1]).approve(address(bRouter), _amounts[1] - _deposits[1]);
    //     MockERC20(_tokens[1]).approve(address(bRouter), _deposits[1]);

    //     //Call Deposit function
    //     IBranchRouter(bRouter).callOutAndBridgeMultiple{value: 1 ether}(bytes("test"), depositInput, _gasParams);

    //     // Prank out of user account
    //     vm.stopPrank();

    //     // Test If Deposit was successful
    //     testCreateDeposit(uint32(1), _user, _hTokens, _tokens, _amounts, _deposits);
    // }
}

contract MockPortStrategy {
    function withdraw(address port, address token, uint256 amount) public {
        MockERC20(token).transfer(port, amount);
    }
}
