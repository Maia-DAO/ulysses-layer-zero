//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./RootForkSetup.t.sol";

contract RootForkRequiresEndpointTest is RootForkSetupTest {
    using BaseBranchRouterHelper for BaseBranchRouter;
    using BranchBridgeAgentHelper for BranchBridgeAgent;
    using CoreRootRouterHelper for CoreRootRouter;
    using MulticallRootRouterHelper for MulticallRootRouter;
    using RootBridgeAgentHelper for RootBridgeAgent;
    using RootBridgeAgentFactoryHelper for RootBridgeAgentFactory;
    using RootPortHelper for RootPort;

    /*///////////////////////////////////////////////////////////////
                        BRANCH BRIDGE AGENT TESTS
    ///////////////////////////////////////////////////////////////*/

    // Internal Notation because we only do an external call for easier bytes handling
    function _testRequiresEndpointBranch(
        BranchBridgeAgent _branchBridgeAgent,
        RootBridgeAgent _rootBridgeAgent,
        address _lzEndpointAddress,
        uint16 _rootChainId,
        address _endpoint,
        uint16 _srcChainId,
        bytes calldata _path,
        bytes calldata _payload
    ) external {
        if (_endpoint != _lzEndpointAddress) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        } else if (_path.length != 40) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (address(_rootBridgeAgent) != address(uint160(bytes20(_path[:20])))) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_srcChainId != _rootChainId) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_payload[0] == 0xFF) {
            vm.expectRevert(IBranchBridgeAgent.UnknownFlag.selector);
        }

        // Call lzReceiveNonBlocking because lzReceive should never fail
        vm.prank(address(_branchBridgeAgent));
        _branchBridgeAgent.lzReceiveNonBlocking(_endpoint, _srcChainId, _path, _payload);
    }

    function testRequiresEndpointBranch() public {
        switchToLzChain(avaxChainId);

        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            rootChainId,
            abi.encodePacked(multicallRootBridgeAgent, avaxMulticallBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_NotCallingItself() public {
        switchToLzChain(avaxChainId);

        vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        avaxMulticallBridgeAgent.lzReceiveNonBlocking(
            lzEndpointAddress,
            rootChainId,
            abi.encodePacked(multicallRootBridgeAgent, avaxMulticallBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_srcAddress() public {
        switchToLzChain(avaxChainId);

        bytes memory _pathData = abi.encodePacked(address(0), address(0));
        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            rootChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_srcAddress(address _srcAddress) public {
        switchToLzChain(avaxChainId);

        bytes memory _pathData = abi.encodePacked(_srcAddress, address(0));
        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            rootChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_pathData() public {
        switchToLzChain(avaxChainId);

        bytes memory _pathData = abi.encodePacked(multicallRootBridgeAgent);

        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            rootChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_pathData(bytes memory _pathData) public {
        switchToLzChain(avaxChainId);

        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            rootChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_srcChainId() public {
        switchToLzChain(avaxChainId);

        uint16 _srcChainId = 0;

        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            _srcChainId,
            abi.encodePacked(multicallRootBridgeAgent, avaxMulticallBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_srcChainId(uint16 _srcChainId) public {
        switchToLzChain(avaxChainId);

        this._testRequiresEndpointBranch(
            avaxMulticallBridgeAgent,
            multicallRootBridgeAgent,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            _srcChainId,
            abi.encodePacked(multicallRootBridgeAgent, avaxMulticallBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    /*///////////////////////////////////////////////////////////////
                        ROOT BRIDGE AGENT TESTS
    ///////////////////////////////////////////////////////////////*/

    // Internal Notation because we only do an external call for easier bytes handling
    function _testRequiresEndpointRoot(
        RootBridgeAgent _rootBridgeAgent,
        BranchBridgeAgent _branchBridgeAgent,
        address _lzEndpointAddress,
        uint16 _branchChainId,
        address _endpoint,
        uint16 _srcChainId,
        bytes calldata _path,
        bytes calldata _payload
    ) external {
        if (_endpoint != _lzEndpointAddress) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        } else if (_path.length != 40) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (address(_branchBridgeAgent) != address(uint160(bytes20(_path[:20])))) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_srcChainId != _branchChainId) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_payload[0] == 0xFF) {
            vm.expectRevert(IBranchBridgeAgent.UnknownFlag.selector);
        }

        // Call lzReceiveNonBlocking because lzReceive should never fail
        vm.prank(address(_rootBridgeAgent));
        _rootBridgeAgent.lzReceiveNonBlocking(_endpoint, _srcChainId, _path, _payload);
    }

    function testRequiresEndpointRoot() public {
        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            avaxChainId,
            abi.encodePacked(avaxMulticallBridgeAgent, multicallRootBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_NotCallingItself() public {
        vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        multicallRootBridgeAgent.lzReceiveNonBlocking(
            lzEndpointAddress,
            avaxChainId,
            abi.encodePacked(avaxMulticallBridgeAgent, multicallRootBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_srcAddress() public {
        bytes memory _pathData = abi.encodePacked(address(0), address(0));
        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            avaxChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_srcAddress(address _srcAddress) public {
        bytes memory _pathData = abi.encodePacked(_srcAddress, address(0));
        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            avaxChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_pathData() public {
        bytes memory _pathData = abi.encodePacked(avaxMulticallBridgeAgent);

        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            avaxChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_pathData(bytes memory _pathData) public {
        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            avaxChainId,
            _pathData,
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_srcChainId() public {
        uint16 _srcChainId = 0;

        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            _srcChainId,
            abi.encodePacked(avaxMulticallBridgeAgent, multicallRootBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_srcChainId(uint16 _srcChainId) public {
        this._testRequiresEndpointRoot(
            multicallRootBridgeAgent,
            avaxMulticallBridgeAgent,
            lzEndpointAddress,
            avaxChainId,
            lzEndpointAddress,
            _srcChainId,
            abi.encodePacked(avaxMulticallBridgeAgent, multicallRootBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }
}
