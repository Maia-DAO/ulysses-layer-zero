//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

contract RootForkPortStrategiesTest is RootForkSetupTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    //////////////////////////////////////
    //           Port Strategies        //
    //////////////////////////////////////
    MockERC20 mockFtmPortToken;

    function testAddStrategyToken() public {
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);
        mockFtmPortToken = new MockERC20("Token of the Port", "PORT TKN", 18);
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        //Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.toggleStrategyToken{value: 1 ether}(
            address(mockFtmPortToken), 7000, address(this), ftmChainId, GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(ftmPort.isStrategyToken(address(mockFtmPortToken)), "Should be added");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    function testAddStrategyTokenInvalidMinReserve() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        vm.expectRevert(abi.encodeWithSignature("InvalidMinimumReservesRatio()"));
        coreRootRouter.toggleStrategyToken{value: 1 ether}(
            address(mockFtmPortToken), 300, address(this), ftmChainId, GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(!ftmPort.isStrategyToken(address(mockFtmPortToken)), "Should note be added");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    function testRemoveStrategyToken() public {
        //Add Token
        testAddStrategyToken();

        //Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.toggleStrategyToken{value: 1 ether}(
            address(mockFtmPortToken), 10000, address(this), ftmChainId, GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(!ftmPort.isStrategyToken(address(mockFtmPortToken)), "Should be removed");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    address mockFtmPortStrategyAddress;

    function testAddPortStrategy() public {
        // Add strategy token
        testAddStrategyToken();

        // Deploy Mock Strategy
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);
        mockFtmPortStrategyAddress = address(new MockPortStrategy());
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.togglePortStrategy{value: 1 ether}(
            mockFtmPortStrategyAddress,
            address(mockFtmPortToken),
            250 ether,
            7000,
            address(this),
            ftmChainId,
            GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(ftmPort.isPortStrategy(mockFtmPortStrategyAddress, address(mockFtmPortToken)), "Should be added");

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
    }

    function testAddPortStrategyLowerRatio() public {
        // Add strategy token
        testAddStrategyToken();

        // Deploy Mock Strategy
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);
        mockFtmPortStrategyAddress = address(new MockPortStrategy());
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);

        // Get some gas
        vm.deal(address(this), 1 ether);

        coreRootRouter.togglePortStrategy{value: 1 ether}(
            mockFtmPortStrategyAddress,
            address(mockFtmPortToken),
            250 ether,
            8000,
            address(this),
            ftmChainId,
            GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(ftmPort.isPortStrategy(mockFtmPortStrategyAddress, address(mockFtmPortToken)), "Should be added");

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(rootChainId);
    }

    function testAddPortStrategyNotToken() public {
        //Get some gas
        vm.deal(address(this), 1 ether);

        //UnrecognizedStrategyToken();
        coreRootRouter.togglePortStrategy{value: 1 ether}(
            mockFtmPortStrategyAddress,
            address(mockFtmPortToken),
            300,
            7000,
            address(this),
            ftmChainId,
            GasParams(300_000, 0)
        );

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(ftmChainId);

        require(!ftmPort.isPortStrategy(mockFtmPortStrategyAddress, address(mockFtmPortToken)), "Should not be added");

        // Switch Chain and Execute Incoming Packets
        switchToLzChain(rootChainId);
    }

    function testManage() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Add token balance to port
        mockFtmPortToken.mint(address(ftmPort), 1000 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockFtmPortToken.balanceOf(address(ftmPort));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress);

        // Prank into strategy
        vm.prank(mockFtmPortStrategyAddress);

        // Request management of assets
        ftmPort.manage(address(mockFtmPortToken), 250 ether);

        // Veriy if assets have been transfered
        require(mockFtmPortToken.balanceOf(address(ftmPort)) == portBalanceBefore - 250 ether, "Should be transfered");

        require(
            mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress) == strategyBalanceBefore + 250 ether,
            "Should be transfered"
        );

        require(
            ftmPort.getPortStrategyTokenDebt(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 250 ether,
            "Should be 250 ether"
        );

        require(
            ftmPort.strategyDailyLimitAmount(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 250 ether,
            "Should be 250 ether"
        );

        require(
            ftmPort.strategyDailyLimitRemaining(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 0,
            "Should be zerod out"
        );
    }

    function testManageNotTrusted() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Add token balance to port
        mockFtmPortToken.mint(address(ftmPort), 1000 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockFtmPortToken.balanceOf(address(ftmPort));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress);

        uint256 strategyDailyLimitRemainingBefore =
            ftmPort.strategyDailyLimitRemaining(mockFtmPortStrategyAddress, address(mockFtmPortToken));

        vm.expectRevert(IBranchPort.UnrecognizedPortStrategy.selector);
        // Prank into non trusted strategy
        vm.prank(address(1));

        // Request management of assets
        ftmPort.manage(address(mockFtmPortToken), 250 ether);

        // Veriy if assets have been transfered
        assertEq(mockFtmPortToken.balanceOf(address(ftmPort)), portBalanceBefore);

        assertEq(mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress), strategyBalanceBefore);

        assertEq(ftmPort.getPortStrategyTokenDebt(mockFtmPortStrategyAddress, address(mockFtmPortToken)), 0);

        assertEq(ftmPort.strategyDailyLimitAmount(mockFtmPortStrategyAddress, address(mockFtmPortToken)), 250 ether);

        assertEq(
            ftmPort.strategyDailyLimitRemaining(mockFtmPortStrategyAddress, address(mockFtmPortToken)),
            strategyDailyLimitRemainingBefore
        );
    }

    function testManageTwoDayLimits() public {
        // Add Strategy token and Port strategy
        testManage();

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Warp 1 day
        vm.warp(block.timestamp + 1 days);

        // Add token balance to port (new deposits)
        mockFtmPortToken.mint(address(ftmPort), 1000 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockFtmPortToken.balanceOf(address(ftmPort));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress);

        // Prank into strategy
        vm.prank(mockFtmPortStrategyAddress);

        // Request management of assets
        ftmPort.manage(address(mockFtmPortToken), 250 ether);

        // Veriy if assets have been transfered
        require(mockFtmPortToken.balanceOf(address(ftmPort)) == portBalanceBefore - 250 ether, "Should be transfered");

        require(
            mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress) == strategyBalanceBefore + 250 ether,
            "Should be transfered"
        );

        require(
            ftmPort.getPortStrategyTokenDebt(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 500 ether,
            "Should be 500 ether"
        );

        require(
            ftmPort.strategyDailyLimitAmount(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 250 ether,
            "Should be 250 ether"
        );

        require(
            ftmPort.strategyDailyLimitRemaining(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 0,
            "Should be zerod out"
        );
    }

    function testManageExceedsMinimumReserves() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Add token balance to port
        mockFtmPortToken.mint(address(ftmPort), 1000 ether);

        // Prank into strategy
        vm.startPrank(mockFtmPortStrategyAddress);

        // Expect revert
        vm.expectRevert(abi.encodeWithSignature("InsufficientReserves()"));

        // Request management of assets
        ftmPort.manage(address(mockFtmPortToken), 400 ether);
    }

    function testManageExceedsDailyLimit() public {
        // Add Strategy token and Port strategy
        testAddPortStrategy();

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Add token balance to port
        mockFtmPortToken.mint(address(ftmPort), 1000 ether);

        // Prank into strategy
        vm.startPrank(mockFtmPortStrategyAddress);

        // Expect revert
        vm.expectRevert();

        // Request management of assets
        ftmPort.manage(address(mockFtmPortToken), 300 ether);
    }

    function testManageExceedsStrategyDebtLimit() public {
        // Add Strategy token and Port strategy
        testAddPortStrategyLowerRatio();

        // Switch Chain and Execute Incoming Packets
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Add token balance to port
        mockFtmPortToken.mint(address(ftmPort), 750 ether);

        // Prank into strategy
        vm.startPrank(mockFtmPortStrategyAddress);

        // Expect revert
        vm.expectRevert();

        // Request management of assets
        ftmPort.manage(address(mockFtmPortToken), 225 ether);
    }

    function testReplenishAsStrategy() public {
        // Add Strategy token and Port strategy
        testManage();

        // Switch to brnach
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Get port balance before manage
        uint256 portBalanceBefore = mockFtmPortToken.balanceOf(address(ftmPort));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress);

        // Prank into strategy
        vm.prank(mockFtmPortStrategyAddress);

        // Request management of assets
        ftmPort.replenishReserves(address(mockFtmPortToken), 250 ether);

        // Veriy if assets have been transfered
        require(mockFtmPortToken.balanceOf(address(ftmPort)) == portBalanceBefore + 250 ether, "Should be transfered");

        require(
            mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress) == strategyBalanceBefore - 250 ether,
            "Should be returned"
        );

        require(
            ftmPort.getPortStrategyTokenDebt(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 0,
            "Should be zerod"
        );

        require(
            ftmPort.strategyDailyLimitAmount(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 250 ether,
            "Should remain 250 ether"
        );

        require(
            ftmPort.strategyDailyLimitRemaining(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 0,
            "Should be zerod"
        );
    }

    function testReplenishAsStrategyNotTrusted() public {
        // Add Strategy token and Port strategy
        testManage();

        // Switch to brnach
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Prank into non-trusted strategy
        vm.prank(address(1));

        vm.expectRevert(IBranchPort.InsufficientDebt.selector);
        // Request management of assets
        ftmPort.replenishReserves(address(mockFtmPortToken), 250 ether);
    }

    function testReplenishAsUser() public {
        // Add Strategy token and Port strategy
        testManage();

        // Switch to brnach
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Fake some port withdrawals
        // vm.prank(address(ftmPort));
        MockERC20(mockFtmPortToken).burn(address(ftmPort), 500 ether);

        // Get port balance before manage
        uint256 portBalanceBefore = mockFtmPortToken.balanceOf(address(ftmPort));

        // Get Strategy balance before manage
        uint256 strategyBalanceBefore = mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress);

        // Request management of assets
        ftmPort.replenishReserves(mockFtmPortStrategyAddress, address(mockFtmPortToken));

        // Veriy if assets have been transfered up to the minimum reserves
        require(mockFtmPortToken.balanceOf(address(ftmPort)) == portBalanceBefore + 100 ether, "Should be transfered");

        require(
            mockFtmPortToken.balanceOf(mockFtmPortStrategyAddress) == strategyBalanceBefore - 100 ether,
            "Should be returned"
        );

        require(
            ftmPort.getPortStrategyTokenDebt(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 150 ether,
            "Should be decremented"
        );

        require(
            ftmPort.strategyDailyLimitAmount(mockFtmPortStrategyAddress, address(mockFtmPortToken)) == 250 ether,
            "Should remain 250 ether"
        );
    }

    function testReplenishAsUserStrategyNotTrusted() public {
        // Add Strategy token and Port strategy
        testManage();

        // Fake some port withdrawals
        MockERC20(mockFtmPortToken).burn(address(ftmPort), 500 ether);

        vm.expectRevert(IBranchPort.InsufficientDebt.selector);
        // Request management of assets
        ftmPort.replenishReserves(address(1), address(mockFtmPortToken));
    }

    function testReplenishAsStrategyNotEnoughDebtToRepay() public {
        // Add Strategy token and Port strategy
        testManage();

        // Switch to brnach
        switchToLzChainWithoutExecutePendingOrPacketUpdate(ftmChainId);

        // Prank into strategy
        vm.prank(mockFtmPortStrategyAddress);

        // Expect revert
        vm.expectRevert();

        // Request management of assets
        ftmPort.replenishReserves(address(mockFtmPortToken), 300 ether);
    }
}
