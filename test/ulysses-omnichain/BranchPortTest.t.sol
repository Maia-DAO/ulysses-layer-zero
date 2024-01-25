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

        testToken = new ERC20hToken(address(this), "Test Ulysses Hermes underlying token", "test-uhUNDER", 18);

        bRouter = new BaseBranchRouter();

        BranchPort(payable(localPortAddress)).initialize(address(bRouter), address(this));

        bAgent = new BranchBridgeAgent(
            rootChainId, localChainId, rootBridgeAgentAddress, lzEndpointAddress, address(bRouter), localPortAddress
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
        BranchPort(payable(localPortAddress)).toggleStrategyToken(address(mockStrategyToken), 10000);

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

    function testReplenishAsStrategyNotTrusted() public {
        // Add Strategy token and Port strategy
        testManage();

        // Get port balance before manage
        uint256 portBalanceBefore = mockStrategyToken.balanceOf(address(localPortAddress));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockStrategyToken.balanceOf(mockPortStrategyAddress);

        // Prank into non-trusted strategy
        vm.prank(address(1));

        vm.expectRevert(IBranchPort.InsufficientDebt.selector);
        // Request management of assets
        BranchPort(payable(localPortAddress)).replenishReserves(address(mockStrategyToken), 250 ether);
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

    function testReplenishAsUserStrategyNotTrusted() public {
        // Add Strategy token and Port strategy
        testManage();

        // Fake some port withdrawals
        MockERC20(mockStrategyToken).burn(address(localPortAddress), 500 ether);

        vm.expectRevert(IBranchPort.InsufficientDebt.selector);
        // Request management of assets
        BranchPort(payable(localPortAddress)).replenishReserves(address(1), address(mockStrategyToken));
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

    function testReentrancy() public {
        testAddStrategyToken();

        // Deploy Mock Reentrancy Strategy
        mockPortStrategyAddress = address(new MockPortStrategyReentrancy(localPortAddress, address(mockStrategyToken)));

        vm.prank(address(bRouter));
        BranchPort(payable(localPortAddress)).togglePortStrategy(
            mockPortStrategyAddress, address(mockStrategyToken), 250 ether, 7000
        );
        vm.warp(1700495386);
        mockStrategyToken.mint(address(localPortAddress), 1000 ether);

        vm.startPrank(mockPortStrategyAddress);
        // 1. Perform first manage call
        BranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 150 ether);

        // 2. Skip a day to update daily limits
        vm.warp(1700495386 + 86400);

        // Will revert due to reeantrancy lock added in "withdraw" function
        vm.expectRevert("REENTRANCY");
        // 3. Return debt -> see MockPortStrategyReentrancy.withdraw()
        BranchPort(payable(localPortAddress)).replenishReserves(address(mockStrategyToken), 150 ether);
    }
}

contract MockPortStrategyReentrancy {
    address localPortAddress;
    address mockStrategyToken;

    constructor(address _localPortAddress, address _mockStrategyToken) {
        localPortAddress = _localPortAddress;
        mockStrategyToken = _mockStrategyToken;
    }

    function withdraw(address port, address token, uint256 amount) public {
        // 4. Before transferring the debt to the BranchPort contract, call manage again to obtain more debt tokens with updated getStrategyTokenDebt and getPortStrategyTokenDebt to exceed the debt limit
        IBranchPort(payable(localPortAddress)).manage(address(mockStrategyToken), 100 ether);

        // 5. Perform some actions

        // 6. Return all debt funds to the BranchPort contract
        MockERC20(token).transfer(port, amount + 100 ether);
    }
}
