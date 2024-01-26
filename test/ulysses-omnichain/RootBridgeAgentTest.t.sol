//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./helpers/ImportHelper.sol";

contract RootBridgeAgentTest is Test, BridgeAgentConstants {
    using AddressCodeSize for address;

    uint16 rootChainId = 100;

    MockRootBridgeAgent mockRootBridgeAgent;
    RootPort rootPort;

    address user = address(0xBEEF);
    address endpoint = address(0xCAFE);
    address router = address(0xDEAD);

    uint16 branchChainId = 200;
    address branchBridgeAgent = address(0xBABE);

    function setUp() public {
        rootPort = new RootPort(rootChainId);

        mockRootBridgeAgent = new MockRootBridgeAgent(rootChainId, endpoint, address(rootPort), router);
    }

    /*///////////////////////////////////////////////////////////////
                               HELPERS
    ///////////////////////////////////////////////////////////////*/

    function syncBranchBridgeAgent(address _branchBridgeAgent, uint256 _branchChainId)
        public
        returns (bytes memory path)
    {
        vm.prank(address(rootPort));
        mockRootBridgeAgent.syncBranchBridgeAgent(_branchBridgeAgent, _branchChainId);

        return abi.encodePacked(_branchBridgeAgent, mockRootBridgeAgent);
    }

    /*///////////////////////////////////////////////////////////////
                       TEST COMPUTE ADDRESS HELPER
    ///////////////////////////////////////////////////////////////*/

    function test_computeAddress(address owner) public {
        if (owner == address(0)) owner = address(1);

        assertEq(
            ComputeVirtualAccount.computeAddress(address(rootPort), owner), address(rootPort.fetchVirtualAccount(owner))
        );
    }

    /*///////////////////////////////////////////////////////////////
                              TEST FUZZ
    ///////////////////////////////////////////////////////////////*/

    function test_fuzz_checkSettlementOwner(address caller, address settlementOwner) public {
        // Caller cannot be zero address
        if (caller == address(0)) caller = address(1);

        if (settlementOwner == address(0)) {
            // If settlementOwner is zero address, the settlement has already been redeemed
            vm.expectRevert(IRootBridgeAgent.NotSettlementOwner.selector);
        } else if (caller != settlementOwner) {
            if (settlementOwner.isContract()) {
                // If the caller and settlementOwner are not the same, the owner cannot be a contract
                vm.expectRevert(IRootBridgeAgent.ContractsVirtualAccountNotAllowed.selector);
            } else if (caller != ComputeVirtualAccount.computeAddress(address(rootPort), settlementOwner)) {
                // If the caller is not the settlementOwner, the caller must be the computed virtual account
                vm.expectRevert(IRootBridgeAgent.NotSettlementOwner.selector);
            } else {
                // If caller is the virtual account, deploy the virtual account if it does not exist
                rootPort.fetchVirtualAccount(settlementOwner);
            }
        }

        mockRootBridgeAgent.checkSettlementOwner(caller, settlementOwner);
    }

    function test_fuzz_lzReceive_UnknownFlag(bytes1 _depositFlag) public {
        // If the deposit flag is larger than 0x00
        if (_depositFlag > 0x00) {
            // If the deposit flag is less than 0x0A, set it to 0x0A
            if (_depositFlag < 0x0A) {
                _depositFlag = 0x0A;
            }
            // If the fallback flag is set, set the third bit to 0 to ensure the flag is unknown
            // Acceptable fallback deposit flags are 0x85, 0x86 and 0x87
            else if (
                _depositFlag & 0x80 == 0x80 && (_depositFlag == 0x85 || _depositFlag == 0x86 || _depositFlag == 0x87)
            ) {
                _depositFlag = _depositFlag | 0x8b;
            }
        }

        bytes memory path = syncBranchBridgeAgent(branchBridgeAgent, branchChainId);

        vm.expectRevert(IRootBridgeAgent.UnknownFlag.selector);
        vm.prank(address(mockRootBridgeAgent));
        mockRootBridgeAgent.lzReceiveNonBlocking(endpoint, branchChainId, path, abi.encodePacked(_depositFlag));
    }

    function test_fuzz_forceResumeReceive(uint16 _srcChainId, bytes memory _srcAddress) public {
        vm.expectCall(
            endpoint,
            0,
            abi.encodeWithSelector(
                // "forceResumeReceive(uint16,bytes)",
                ILayerZeroUserApplicationConfig.forceResumeReceive.selector,
                _srcChainId,
                _srcAddress
            )
        );
        vm.mockCall(
            endpoint,
            abi.encodeWithSelector(
                // "forceResumeReceive(uint16,bytes)",
                ILayerZeroUserApplicationConfig.forceResumeReceive.selector,
                _srcChainId,
                _srcAddress
            ),
            ""
        );

        RootBridgeAgent(mockRootBridgeAgent).forceResumeReceive(_srcChainId, _srcAddress);
    }

    /*///////////////////////////////////////////////////////////////
                        TEST FORCE RESUME RECEIVE
    ///////////////////////////////////////////////////////////////*/

    function test_forceResumeReceive() public {
        test_fuzz_forceResumeReceive(0, abi.encodePacked(address(0)));
    }

    /*///////////////////////////////////////////////////////////////
                           TEST SAME ADDRESS
    ///////////////////////////////////////////////////////////////*/

    // The following tests should all pass because the caller and settlementOwner are the same address

    function test_fuzz_checkSettlementOwner_sameAddress(address owner) public {
        if (owner == address(0)) owner = address(1);

        test_fuzz_checkSettlementOwner(owner, owner);
    }

    function test_checkSettlementOwner_sameAddress_EOA() public {
        test_fuzz_checkSettlementOwner(user, user);
    }

    function test_checkSettlementOwner_sameAddress_contract() public {
        test_fuzz_checkSettlementOwner(address(this), address(this));
    }

    function test_checkSettlementOwner_sameAddress_virtualAccount() public {
        address virtualAccount = address(rootPort.fetchVirtualAccount(user));
        test_fuzz_checkSettlementOwner(virtualAccount, virtualAccount);
    }

    /*///////////////////////////////////////////////////////////////
                          TEST ALREADY REDEEMED
    ///////////////////////////////////////////////////////////////*/

    // The following tests should all fail because the settlement has already been redeemed

    function test_fuzz_checkSettlementOwner_alreadyRedeemed(address owner) public {
        test_fuzz_checkSettlementOwner(owner, address(0));
    }

    function test_checkSettlementOwner_alreadyRedeemed_EOA() public {
        test_fuzz_checkSettlementOwner(user, address(0));
    }

    function test_checkSettlementOwner_alreadyRedeemed_Contract() public {
        test_fuzz_checkSettlementOwner(address(this), address(0));
    }

    function test_checkSettlementOwner_alreadyRedeemed_VirtualAccount() public {
        address virtualAccount = address(rootPort.fetchVirtualAccount(user));
        test_fuzz_checkSettlementOwner(virtualAccount, address(0));
    }

    /*///////////////////////////////////////////////////////////////
                            TEST IS CONTRACT
    ///////////////////////////////////////////////////////////////*/

    // The following tests should all fail because the settlementOwner is not the caller and is a contract

    function test_fuzz_checkSettlementOwner_isContract(address owner) public {
        test_fuzz_checkSettlementOwner(owner, address(this));
    }

    function test_checkSettlementOwner_isContract_EOA() public {
        test_fuzz_checkSettlementOwner(user, address(this));
    }

    function test_checkSettlementOwner_isContract_Contract() public {
        test_fuzz_checkSettlementOwner(address(this), address(rootPort));
    }

    function test_checkSettlementOwner_isContract_VirtualAccount() public {
        address virtualAccount = address(rootPort.fetchVirtualAccount(address(this)));
        test_fuzz_checkSettlementOwner(virtualAccount, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                          TEST DIFFERENT ADDRESS
    ///////////////////////////////////////////////////////////////*/

    // The following tests should all fail because the settlementOwner is not the caller and is not a contract

    function test_fuzz_checkSettlementOwner_differentAddress(address owner) public {
        if (owner == user) owner = address(1);

        test_fuzz_checkSettlementOwner(owner, user);
    }

    function test_checkSettlementOwner_differentAddress_EOA() public {
        test_fuzz_checkSettlementOwner(address(1), user);
    }

    function test_checkSettlementOwner_differentAddress_Contract() public {
        test_fuzz_checkSettlementOwner(address(this), user);
    }

    function test_checkSettlementOwner_differentAddress_VirtualAccount() public {
        address virtualAccount = address(rootPort.fetchVirtualAccount(address(1)));
        test_fuzz_checkSettlementOwner(virtualAccount, user);
    }

    /*///////////////////////////////////////////////////////////////
                          TEST VIRTUAL ACCOUNT
    ///////////////////////////////////////////////////////////////*/

    // The following tests should all pass because the caller is the settlementOwner's virtual account

    function test_fuzz_checkSettlementOwner_virtualAccount(address owner) public {
        if (owner == address(0)) owner = address(1);

        address virtualAccount = address(rootPort.fetchVirtualAccount(owner));
        test_fuzz_checkSettlementOwner(virtualAccount, owner);
    }

    function test_checkSettlementOwner_virtualAccount_EOA() public {
        address virtualAccount = address(rootPort.fetchVirtualAccount(user));
        test_fuzz_checkSettlementOwner(virtualAccount, user);
    }

    /*///////////////////////////////////////////////////////////////
                          TEST GAS LIMITS
    ///////////////////////////////////////////////////////////////*/

    function test_gasLimits(bytes memory payload) public {
        vm.assume(payload.length < 10_000);

        mockRootBridgeAgent.lzReceive{gas: 16_000}(1, abi.encodePacked(address(this), address(this)), 0, payload);

        //Should not fail.
    }

    function testFail_gasLimits(bytes memory payload) public {
        vm.assume(payload.length < 10_000);

        mockRootBridgeAgent.lzReceive{gas: 14_000}(1, abi.encodePacked(address(this), address(this)), 0, payload);

        //Should fail.
    }

    /*///////////////////////////////////////////////////////////////
                          TEST ALREADY EXECUTED
    ///////////////////////////////////////////////////////////////*/

    function test_alreadyExecutedTransaction0x01(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x01, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x02(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x02, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x03(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x03, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x04(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x04, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x05(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x05, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x85(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x85, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x06(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x06, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x08(bytes4 _nonce) public {
        test_alreadyExecutedTransaction(_nonce, 0x08, false, 1024);
    }

    /// @notice This test should always revert with AlreadyExecutedTransaction error
    function test_alreadyExecutedTransaction(
        bytes4 _nonce,
        bytes1 _depositFlag,
        bool _setStatusRetrieved,
        uint16 _payloadLength
    ) public {
        // Remove the deposit flag from the payload
        bytes1 depositFlag = _depositFlag & 0x7F;

        // If the deposit flag does not set this check, set it to 0x85 (Signed call with deposit with fallback)
        if (depositFlag == 0x00 || depositFlag == 0x07 || depositFlag > 0x08) {
            _depositFlag = 0x85;
            depositFlag = _depositFlag & 0x7F;
        }

        uint256 start;

        if (depositFlag == 0x01 || depositFlag == 0x02) {
            // _payload[PARAMS_START:PARAMS_TKN_START] = _nonce;
            start = PARAMS_START;
            _depositFlag = depositFlag;
        } else if (depositFlag == 0x03) {
            // _payload[2:6] = _nonce;
            start = 2;
            _depositFlag = depositFlag;
        } else if (depositFlag == 0x04 || depositFlag == 0x05 || depositFlag == 0x08) {
            // _payload[PARAMS_START_SIGNED:PARAMS_TKN_START_SIGNED] = _nonce;
            start = PARAMS_START_SIGNED;
            if (depositFlag != 0x05) {
                _depositFlag = depositFlag;

                if (depositFlag == 0x08) {
                    _setStatusRetrieved = false;
                }
            }
        } else if (depositFlag == 0x06) {
            // _payload[PARAMS_START_SIGNED + PARAMS_START:PARAMS_START_SIGNED + PARAMS_TKN_START] = _nonce;
            start = PARAMS_START_SIGNED + PARAMS_START;
        }

        uint256 end = start + 4;
        bytes memory payload = new bytes(end > _payloadLength ? end : _payloadLength);
        payload[0] = _depositFlag;

        setBytes4(payload, _nonce, start);

        bytes memory path = syncBranchBridgeAgent(branchBridgeAgent, branchChainId);

        mockRootBridgeAgent.setExecutionState(
            branchChainId, uint32(_nonce), _setStatusRetrieved ? STATUS_RETRIEVE : STATUS_DONE
        );

        vm.expectRevert(IRootBridgeAgent.AlreadyExecutedTransaction.selector);
        vm.prank(address(mockRootBridgeAgent));
        mockRootBridgeAgent.lzReceiveNonBlocking(endpoint, branchChainId, path, payload);
    }

    function setBytes4(bytes memory _bytes, bytes4 _value, uint256 _offset) internal pure {
        for (uint256 i = 0; i < 4; i++) {
            _bytes[_offset + i] = _value[i];
        }
    }

    /*///////////////////////////////////////////////////////////////
                          TEST REQUIRES ENDPOINT
    ///////////////////////////////////////////////////////////////*/

    // Internal Notation because we only do an external call for easier bytes handling
    function _testRequiresEndpointRoot(
        RootBridgeAgent _rootBridgeAgent,
        address _branchBridgeAgent,
        address _lzEndpointAddress,
        uint16 _branchChainId,
        address _endpoint,
        uint16 _srcChainId,
        bytes calldata _path
    ) external {
        if (_lzEndpointAddress != _endpoint) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        } else if (_path.length != 40) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (address(_branchBridgeAgent) != address(uint160(bytes20(_path[:20])))) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_srcChainId != _branchChainId) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else {
            // _payload[0] == 0xFF is always true
            vm.expectRevert(IBranchBridgeAgent.UnknownFlag.selector);
        }

        // Call lzReceiveNonBlocking because lzReceive should never fail
        vm.prank(address(_rootBridgeAgent));
        _rootBridgeAgent.lzReceiveNonBlocking(_endpoint, _srcChainId, _path, abi.encodePacked(bytes1(0xFF)));
    }

    function testRequiresEndpointRoot() public {
        this._testRequiresEndpointRoot(
            mockRootBridgeAgent,
            branchBridgeAgent,
            endpoint,
            branchChainId,
            endpoint,
            branchChainId,
            abi.encodePacked(branchBridgeAgent, mockRootBridgeAgent)
        );
    }

    function testRequiresEndpointRoot_NotCallingItself() public {
        vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        mockRootBridgeAgent.lzReceiveNonBlocking(
            endpoint,
            branchChainId,
            abi.encodePacked(branchBridgeAgent, mockRootBridgeAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointRoot_srcAddress() public {
        bytes memory _pathData = abi.encodePacked(address(1), address(1));

        testRequiresEndpointRoot_pathData(_pathData);
    }

    function testRequiresEndpointRoot_srcAddress(address _srcAddress) public {
        bytes memory _pathData = abi.encodePacked(_srcAddress, address(1));

        testRequiresEndpointRoot_pathData(_pathData);
    }

    function testRequiresEndpointRoot_pathData() public {
        bytes memory _pathData = abi.encodePacked(branchBridgeAgent);

        testRequiresEndpointRoot_pathData(_pathData);
    }

    function testRequiresEndpointRoot_pathData(bytes memory _pathData) public {
        this._testRequiresEndpointRoot(
            mockRootBridgeAgent, branchBridgeAgent, endpoint, branchChainId, endpoint, branchChainId, _pathData
        );
    }

    function testRequiresEndpointRoot_srcChainId() public {
        testRequiresEndpointRoot_srcChainId(0);
    }

    function testRequiresEndpointRoot_srcChainId(uint16 _srcChainId) public {
        this._testRequiresEndpointRoot(
            mockRootBridgeAgent,
            branchBridgeAgent,
            endpoint,
            branchChainId,
            endpoint,
            _srcChainId,
            abi.encodePacked(branchBridgeAgent, mockRootBridgeAgent)
        );
    }
}
