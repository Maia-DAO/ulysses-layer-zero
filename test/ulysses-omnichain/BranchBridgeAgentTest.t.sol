//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "./helpers/ImportHelper.sol";

contract BranchBridgeAgentTest is Test, BridgeAgentConstants {
    MockERC20 underlyingToken;

    MockERC20 rewardToken;

    ERC20hToken testToken;

    ERC20hToken testToken2;

    BaseBranchRouter bRouter;

    MockBranchBridgeAgent bAgent;

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

        testToken2 = new ERC20hToken(address(this), "Test Ulysses Hermes underlying token 2", "test-uhUNDER2", 18);

        bRouter = new BaseBranchRouter();

        BranchPort(payable(localPortAddress)).initialize(address(bRouter), address(this));

        bAgent = new MockBranchBridgeAgent(
            rootChainId, localChainId, rootBridgeAgentAddress, lzEndpointAddress, address(bRouter), localPortAddress
        );

        bRouter.initialize(address(bAgent));

        BranchPort(payable(localPortAddress)).addBridgeAgent(address(bAgent));

        rootBridgeAgentPath = abi.encodePacked(rootBridgeAgentAddress, address(bAgent));

        vm.mockCall(lzEndpointAddress, "", "");
    }

    receive() external payable {}

    function test_fuzz_lzReceive_UnknownFlag(bytes1 _depositFlag) public {
        // If the deposit flag is larger than 0x00
        if (_depositFlag > 0x00) {
            // If the deposit flag is less than 0x0A, set it to 0x0A
            if (_depositFlag < 0x06) {
                _depositFlag = 0x06;
            }
            // If the fallback flag is set, set the second bit to 0 to ensure the flag is unknown
            // Acceptable fallback deposit flags are 0x82 and 0x83
            else if (_depositFlag & 0x80 == 0x80 && (_depositFlag == 0x82 || _depositFlag == 0x83)) {
                _depositFlag = _depositFlag | 0x8d;
            }
        }

        vm.expectRevert(IBranchBridgeAgent.UnknownFlag.selector);
        vm.prank(address(bAgent));
        bAgent.lzReceiveNonBlocking(lzEndpointAddress, rootChainId, rootBridgeAgentPath, abi.encodePacked(_depositFlag));
    }

    function test_fuzz_forceResumeReceive(uint16 _srcChainId, bytes memory _srcAddress) public {
        vm.expectCall(
            lzEndpointAddress,
            0,
            abi.encodeWithSelector(
                // "forceResumeReceive(uint16,bytes)",
                ILayerZeroUserApplicationConfig.forceResumeReceive.selector,
                _srcChainId,
                _srcAddress
            )
        );
        vm.mockCall(
            lzEndpointAddress,
            abi.encodeWithSelector(
                // "forceResumeReceive(uint16,bytes)",
                ILayerZeroUserApplicationConfig.forceResumeReceive.selector,
                _srcChainId,
                _srcAddress
            ),
            ""
        );

        bAgent.forceResumeReceive(_srcChainId, _srcAddress);
    }

    function test_forceResumeReceive() public {
        test_fuzz_forceResumeReceive(0, abi.encodePacked(address(0)));
    }

    function _getAdapterParams(uint256 _gasLimit, uint256 _remoteBranchExecutionGas)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(2), _gasLimit, _remoteBranchExecutionGas, rootBridgeAgentAddress);
    }

    function expectLayerZeroSend(
        uint256 msgValue,
        bytes memory data,
        address refundee,
        GasParams memory gasParams,
        uint256 _baseGasCost
    ) internal {
        vm.expectCall(
            lzEndpointAddress,
            msgValue,
            abi.encodeWithSelector(
                // "send(uint16,bytes,bytes,address,address,bytes)",
                ILayerZeroEndpoint.send.selector,
                rootChainId,
                rootBridgeAgentPath,
                data,
                refundee,
                address(0),
                _getAdapterParams(gasParams.gasLimit + _baseGasCost, gasParams.remoteBranchExecutionGas)
            )
        );
    }

    function testCallOut() public {
        testFuzzCallOut(address(this));
    }

    function testFuzzCallOut(address _user) public {
        // Input restrictions
        if (_user < address(3)) _user = address(3);

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        uint32 depositNonce = bAgent.depositNonce();

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(bytes1(0x01), depositNonce, "testdata"),
            _user,
            gasParams,
            BRANCH_BASE_CALL_OUT_GAS
        );

        //Call Deposit function
        IBranchRouter(bRouter).callOut{value: 1 ether}("testdata", gasParams);

        // Prank out of user account
        vm.stopPrank();

        assertEq(bAgent.depositNonce(), depositNonce + 1);
    }

    function testCallOutAndBridge() public {
        testFuzzCallOutAndBridge(address(this), 100 ether);
    }

    function testFuzzCallOutAndBridge(address _user, uint256 _amount) public {
        // Input restrictions
        if (_user < address(3)) _user = address(3);
        else if (_user == localPortAddress) _user = address(uint160(_user) - 10);

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Mint Test tokens.
        underlyingToken.mint(_user, _amount);

        //Approve spend by router
        underlyingToken.approve(address(bRouter), _amount);

        console2.log("Test CallOut Addresses:");
        console2.log(address(testToken), address(underlyingToken));

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: _amount,
            deposit: _amount
        });

        uint32 depositNonce = bAgent.depositNonce();

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(
                bytes1(0x02),
                depositNonce,
                depositInput.hToken,
                depositInput.token,
                depositInput.amount,
                depositInput.deposit,
                "testdata"
            ),
            _user,
            gasParams,
            BRANCH_BASE_CALL_OUT_DEPOSIT_SINGLE_GAS
        );

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}("testdata", depositInput, gasParams);

        // Prank out of user account
        vm.stopPrank();

        assertEq(bAgent.depositNonce(), depositNonce + 1);

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(testToken), address(underlyingToken), _amount, _amount);
    }

    function testCallOutAndBridgeMultiple() public {
        testFuzzCallOutAndBridge(address(this), 100 ether);
    }

    function testFuzzCallOutAndBridgeMultiple(address _user, uint256 _amount) public {
        // Input restrictions
        if (_user < address(3)) _user = address(3);
        else if (_user == localPortAddress) _user = address(uint160(_user) - 10);

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Mint Test tokens.
        underlyingToken.mint(_user, _amount);

        //Approve spend by router
        underlyingToken.approve(address(bRouter), _amount);

        console2.log("Test CallOut Addresses:");
        console2.log(address(testToken), address(underlyingToken));

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: _amount,
            deposit: _amount
        });

        uint32 depositNonce = bAgent.depositNonce();

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(
                bytes1(0x02),
                depositNonce,
                depositInput.hToken,
                depositInput.token,
                depositInput.amount,
                depositInput.deposit,
                "testdata"
            ),
            _user,
            gasParams,
            BRANCH_BASE_CALL_OUT_DEPOSIT_SINGLE_GAS
        );

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}("testdata", depositInput, gasParams);

        // Prank out of user account
        vm.stopPrank();

        assertEq(bAgent.depositNonce(), depositNonce + 1);

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(testToken), address(underlyingToken), _amount, _amount);
    }

    function testCallOutSigned() public {
        testFuzzCallOutSigned(address(this));
    }

    function testFuzzCallOutSigned(address _user) public {
        // Input restrictions
        if (_user < address(3)) _user = address(3);
        else if (_user == localPortAddress) _user = address(uint160(_user) - 10);

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        uint32 depositNonce = bAgent.depositNonce();

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(bytes1(0x04), _user, depositNonce, "testdata"),
            _user,
            gasParams,
            BRANCH_BASE_CALL_OUT_SIGNED_GAS
        );

        //Call Deposit function
        bAgent.callOutSigned{value: 1 ether}("testdata", gasParams);

        // Prank out of user account
        vm.stopPrank();

        assertEq(bAgent.depositNonce(), depositNonce + 1);
    }

    address storedFallbackUser;

    function testCallOutSignedAndBridge(address _user, uint256 _amount) public {
        // Input restrictions
        if (_user < address(3)) _user = address(3);
        else if (_user == localPortAddress) _user = address(uint160(_user) - 10);

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Mint Test tokens.
        underlyingToken.mint(_user, _amount);

        //Approve spend by router
        underlyingToken.approve(localPortAddress, _amount);

        console2.log("Test CallOut Addresses:");
        console2.log(address(testToken), address(underlyingToken));

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: _amount,
            deposit: _amount
        });

        uint32 depositNonce = bAgent.depositNonce();

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(
                bytes1(0x85),
                _user,
                depositNonce,
                depositInput.hToken,
                depositInput.token,
                depositInput.amount,
                depositInput.deposit,
                "testdata"
            ),
            _user,
            gasParams,
            BRANCH_BASE_CALL_OUT_SIGNED_DEPOSIT_SINGLE_GAS + BASE_FALLBACK_GAS
        );

        //Call Deposit function
        bAgent.callOutSignedAndBridge{value: 1 ether}("testdata", depositInput, gasParams, true);

        // Prank out of user account
        vm.stopPrank();

        assertEq(bAgent.depositNonce(), depositNonce + 1);

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(testToken), address(underlyingToken), _amount, _amount);

        // Store user for usage in other tests
        storedFallbackUser = _user;
    }

    function testCallOutSignedAndBridgeMultiple(address _user, uint256 _amount1, uint256 _amount2)
        public
        returns (MockERC20 underToken0, MockERC20 underToken1)
    {
        // Input restrictions
        if (_user < address(3)) _user = address(3);
        else if (_user == localPortAddress) _user = address(uint160(_user) - 10);

        if (_amount1 == 0) _amount1 = 1;
        if (_amount2 == 0) _amount2 = 1;

        // Get some gas.
        vm.deal(_user, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        // Mint Test tokens.
        vm.startPrank(localPortAddress);

        underToken0 = new MockERC20("u0 token", "U0", 18);
        underToken1 = new MockERC20("u1 token", "U1", 18);

        underToken0.mint(_user, _amount1);
        underToken1.mint(_user, _amount2);

        // Prepare Input Arrays
        address[] memory _hTokens = new address[](2);
        address[] memory _tokens = new address[](2);
        uint256[] memory _amounts = new uint256[](2);
        uint256[] memory _deposits = new uint256[](2);

        _hTokens[0] = address(testToken);
        _hTokens[1] = address(testToken2);

        _tokens[0] = address(underToken0);
        _tokens[1] = address(underToken1);

        _amounts[0] = _amount1;
        _amounts[1] = _amount2;

        _deposits[0] = _amount1;
        _deposits[1] = _amount2;

        vm.stopPrank();

        // Perform deposit
        uint32 depositNonce = bAgent.depositNonce();

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(
                bytes1(0x86), _user, uint8(2), depositNonce, _hTokens, _tokens, _amounts, _deposits, "test"
            ),
            _user,
            gasParams,
            BRANCH_BASE_CALL_OUT_SIGNED_DEPOSIT_MULTIPLE_GAS + BASE_FALLBACK_GAS
        );

        makeTestCallAndBridgeMultipleSigned(_user, _hTokens, _tokens, _amounts, _deposits, gasParams);

        assertEq(bAgent.depositNonce(), depositNonce + 1);

        // Store user for usage in other tests
        storedFallbackUser = _user;
    }

    function testCallOutAndBridgeInsufficientAmount() public {
        // Get some gas.
        vm.deal(address(this), 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Mint Test tokens.
        underlyingToken.mint(address(this), 90 ether);

        //Approve spend by router
        underlyingToken.approve(address(bRouter), 100 ether);

        console2.log("Test CallOut TokenAddresses:");
        console2.log(address(testToken), address(underlyingToken));

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 100 ether,
            deposit: 100 ether
        });

        vm.expectRevert(abi.encodeWithSignature("TransferFromFailed()"));

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, gasParams);
    }

    function testCallOutAndBridgeIncorrectAmount() public {
        // Get some gas.
        vm.deal(address(this), 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        //Mint Test tokens.
        underlyingToken.mint(address(this), 100 ether);

        //Approve spend by router
        underlyingToken.approve(address(bRouter), 100 ether);

        console2.logUint(1);
        console2.log(address(testToken), address(underlyingToken));

        // Prepare deposit info
        DepositInput memory depositInput = DepositInput({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 90 ether,
            deposit: 100 ether
        });

        vm.expectRevert(stdError.arithmeticError);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, gasParams);
    }

    function testCallOutAndBridgeDecimals() public {
        testFuzzCallOutAndBridgeDecimals(address(this), 1 ether, 0.5 ether, 18);
    }

    function testFuzzCallOutAndBridgeDecimals(address _user, uint256 _amount, uint256 _deposit, uint8 _decimals)
        public
    {
        // Input restrictions
        if (_user < address(3)) _user = address(3);
        if (_amount == 0) _amount = 1;
        if (_amount < _deposit) _deposit %= _amount;

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Prank into Port
        vm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hToken fuzzToken = new ERC20hToken(localPortAddress, "Test Ulysses fuzz token", "test-uFUZZ", _decimals);
        fuzzToken.mint(_user, _amount - _deposit);

        // Mint under tokens.
        MockERC20 uunderToken = new MockERC20("Test Ulysses ", "test-u", _decimals);
        uunderToken.mint(_user, _deposit);

        vm.stopPrank();

        //Prepare deposit info
        DepositInput memory depositInput =
            DepositInput({hToken: address(fuzzToken), token: address(uunderToken), amount: _amount, deposit: _deposit});

        // Prank into user account
        vm.startPrank(_user);

        // Approve spend by router
        fuzzToken.approve(address(bRouter), _amount);
        uunderToken.approve(address(bRouter), _deposit);

        uint32 depositNonce = bAgent.depositNonce();

        address _userCache = _user;

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        expectLayerZeroSend(
            1 ether,
            abi.encodePacked(
                bytes1(0x02),
                depositNonce,
                depositInput.hToken,
                depositInput.token,
                depositInput.amount,
                depositInput.deposit,
                "testdata"
            ),
            _userCache,
            gasParams,
            BRANCH_BASE_CALL_OUT_DEPOSIT_SINGLE_GAS
        );

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, gasParams);

        // Prank out of user account
        vm.stopPrank();

        assertEq(bAgent.depositNonce(), depositNonce + 1);

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(fuzzToken), address(uunderToken), _amount, _deposit);
    }

    function testRedeemDeposit() public {
        // Create Test Deposit
        testCallOutSignedAndBridge(address(this), 100 ether);

        vm.deal(localPortAddress, 1 ether);

        // Encode Fallback message
        bytes memory fallbackData = abi.encodePacked(bytes1(0x05), uint32(1));

        // Call 'Fallback'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        // Call redeemDeposit
        bAgent.redeemDeposit(1, address(this));

        // Check deposit state
        require(bAgent.getDepositEntry(1).owner == address(0), "Deposit should be deleted");

        // Check balances
        require(testToken.balanceOf(address(this)) == 0);
        require(underlyingToken.balanceOf(address(this)) == 100 ether);
        require(testToken.balanceOf(localPortAddress) == 0);
        require(underlyingToken.balanceOf(localPortAddress) == 0);
    }

    function testRedeemDepositMultiple() public {
        // Create Test Deposit
        (MockERC20 underlyingToken1, MockERC20 underlyingToken2) =
            testCallOutSignedAndBridgeMultiple(address(this), 100 ether, 100 ether);

        vm.deal(localPortAddress, 1 ether);

        // Encode Fallback message
        bytes memory fallbackData = abi.encodePacked(bytes1(0x05), uint32(1));

        // Call 'Fallback'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        // Call redeemDeposit
        bAgent.redeemDeposit(1, address(this));

        // Check deposit state
        require(bAgent.getDepositEntry(1).owner == address(0), "Deposit should be deleted");

        // Check balances
        require(underlyingToken1.balanceOf(address(this)) == 100 ether);
        require(underlyingToken2.balanceOf(address(this)) == 100 ether);
        require(underlyingToken1.balanceOf(localPortAddress) == 0);
        require(underlyingToken2.balanceOf(localPortAddress) == 0);
    }

    function testRedeemDepositMultipleSpecifyToken()
        public
        returns (MockERC20 underlyingToken1, MockERC20 underlyingToken2)
    {
        // Create Test Deposit
        (underlyingToken1, underlyingToken2) = testCallOutSignedAndBridgeMultiple(address(this), 100 ether, 100 ether);

        vm.deal(localPortAddress, 1 ether);

        // Encode Fallback message
        bytes memory fallbackData = abi.encodePacked(bytes1(0x05), uint32(1));

        // Call 'Fallback'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        // Call redeemDeposit
        bAgent.redeemDeposit(1, address(this), address(testToken));

        // Check deposit state
        require(bAgent.getDepositEntry(1).owner == address(this), "Deposit should not be deleted");

        // Check if hToken was cleared from state
        require(bAgent.getDepositEntry(1).hTokens[0] == address(0), "hToken should be address 0");

        // Check balances
        require(underlyingToken1.balanceOf(address(this)) == 100 ether);
        require(underlyingToken2.balanceOf(address(this)) == 0);
        require(underlyingToken1.balanceOf(localPortAddress) == 0);
        require(underlyingToken2.balanceOf(localPortAddress) == 100 ether);
    }

    function testRedeemDepositMultipleSpecifyEveryToken() public {
        // Create Test Deposit
        (MockERC20 underlyingToken1, MockERC20 underlyingToken2) = testRedeemDepositMultipleSpecifyToken();

        // Call redeemDeposit
        bAgent.redeemDeposit(1, address(this), address(testToken2));

        // Check deposit state
        require(bAgent.getDepositEntry(1).owner == address(0), "Deposit should be deleted");
        require(bAgent.getDepositEntry(1).status == 0, "Status should be 0 so no more redeems");

        // Check balances
        require(underlyingToken1.balanceOf(address(this)) == 100 ether);
        require(underlyingToken2.balanceOf(address(this)) == 100 ether);
        require(underlyingToken1.balanceOf(localPortAddress) == 0);
        require(underlyingToken2.balanceOf(localPortAddress) == 0);
    }

    function testRedeemDepositAlreadyRedeemed() public {
        // Redeem once
        testRedeemDeposit();

        vm.expectRevert(abi.encodeWithSignature("DepositRedeemUnavailable()"));

        // Call redeemDeposit again
        bAgent.redeemDeposit(1, address(this));
    }

    function testRedeemDepositDoubleFallback() public {
        // Create Test Deposit
        testCallOutSignedAndBridge(address(this), 100 ether);

        // Encode fallback message
        bytes memory fallbackData = abi.encodePacked(bytes1(0x05), uint32(1));

        // Call 'Fallback'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        // Call redeemDeposit
        bAgent.redeemDeposit(1, address(this));

        // Call 'Fallback' again
        vm.startPrank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        // Call redeemDeposit again
        vm.expectRevert(abi.encodeWithSignature("DepositRedeemUnavailable()"));
        bAgent.redeemDeposit(1, address(this));
    }

    function testFuzzRedeemDeposit(address _user, uint256 _amount, uint256 _deposit, uint16 _dstChainId) public {
        _amount %= type(uint256).max / 1 ether;

        // Input restrictions
        vm.assume(_user != address(0) && _amount > 0 && _deposit <= _amount && _dstChainId > 0);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hToken fuzzToken = new ERC20hToken(localPortAddress, "Test Ulysses Hermes omni token", "test-uhUNDER", 18);
        fuzzToken.mint(_user, _amount - _deposit);
        MockERC20 underToken = new MockERC20("u token", "U", 18);
        underToken.mint(_user, _deposit);

        vm.stopPrank();

        // Perform deposit
        makeTestCallAndBridgeSigned(_user, address(fuzzToken), address(underToken), _amount, _deposit, gasParams, true);

        // Prepare deposit info
        DepositParams memory depositParams = DepositParams({
            hToken: address(fuzzToken),
            token: address(underlyingToken),
            amount: _amount - _deposit,
            deposit: _deposit,
            depositNonce: 1
        });

        // Encode Fallback message
        bytes memory fallbackData = abi.encodePacked(bytes1(0x05), depositParams.depositNonce);

        // Call 'Fallback'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        // Call redeemDeposit
        vm.prank(_user);
        bAgent.redeemDeposit(1, _user);

        // Check balances
        require(fuzzToken.balanceOf(address(_user)) == _amount - _deposit);
        require(underToken.balanceOf(address(_user)) == _deposit);
        require(fuzzToken.balanceOf(localPortAddress) == 0);
        require(underToken.balanceOf(localPortAddress) == 0);
    }

    function testRetryDeposit() public {
        // Create Test Deposit
        testCallOutAndBridge();

        vm.deal(localPortAddress, 1 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.deal(address(this), 1 ether);

        // Call retry Deposit
        bRouter.retryDeposit{value: 1 ether}(1, "", gasParams);

        // Get Deposit
        Deposit memory deposit = bRouter.getDepositEntry(1);

        // Test If Deposit was successful
        testCreateDeposit(1, address(this), deposit.hTokens, deposit.tokens, deposit.amounts, deposit.deposits);
    }

    function testRetryDepositSigned() public {
        // Create Test Deposit
        testCallOutSignedAndBridge(address(this), 100 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.deal(address(this), 1 ether);

        // Call retry Deposit
        bAgent.retryDepositSigned{value: 1 ether}(1, "", gasParams, true);

        // Get Deposit
        Deposit memory deposit = bRouter.getDepositEntry(1);

        // Test If Deposit was successful
        testCreateDeposit(1, address(this), deposit.hTokens, deposit.tokens, deposit.amounts, deposit.deposits);
    }

    function testRetryDepositMultiple() public {
        // Create Test Deposit
        testCallOutAndBridgeMultiple();

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.deal(address(this), 1 ether);

        // Call retry Deposit
        bRouter.retryDeposit{value: 1 ether}(1, "", gasParams);

        // Get Deposit
        Deposit memory deposit = bRouter.getDepositEntry(1);

        // Test If Deposit was successful
        testCreateDeposit(1, address(this), deposit.hTokens, deposit.tokens, deposit.amounts, deposit.deposits);
    }

    function testRetryDepositMultipleSigned() public {
        // Create Test Deposit
        testCallOutSignedAndBridgeMultiple(address(this), 100 ether, 100 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.deal(address(this), 1 ether);

        // Call retry Deposit
        bAgent.retryDepositSigned{value: 1 ether}(1, "", gasParams, true);

        // Get Deposit
        Deposit memory deposit = bRouter.getDepositEntry(1);

        // Test If Deposit was successful
        testCreateDeposit(1, address(this), deposit.hTokens, deposit.tokens, deposit.amounts, deposit.deposits);
    }

    function testRetryDepositWrongDepositType() public {
        // Create Test Deposit
        (MockERC20 underlyingToken1, MockERC20 underlyingToken2) =
            testCallOutSignedAndBridgeMultiple(address(this), 100 ether, 100 ether);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        vm.deal(address(this), 1 ether);

        // Expect "WrongDepositType()" error.
        vm.expectRevert(abi.encodeWithSignature("WrongDepositType()"));

        // Call retry Deposit
        bRouter.retryDeposit{value: 1 ether}(1, "", gasParams);
    }

    function testRetryDepositFailNotOwner() public {
        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        // Create Test Deposit
        testCallOutAndBridge();

        vm.deal(localPortAddress, 1 ether);

        vm.deal(localPortAddress, 1 ether);

        vm.deal(address(42), 1 ether);

        vm.startPrank(address(42));

        vm.expectRevert(abi.encodeWithSignature("NotDepositOwner()"));

        // Call retry Deposit
        bRouter.retryDeposit{value: 1 ether}(1, "", gasParams);
    }

    function testRetryDepositFailedCannotRetry() public {
        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        // Create Test Deposit
        testCallOutSignedAndBridge(address(this), 100 ether);

        //Prepare deposit info
        DepositParams memory depositParams = DepositParams({
            hToken: address(testToken),
            token: address(underlyingToken),
            amount: 100 ether,
            deposit: 100 ether,
            depositNonce: 1
        });

        // Encode Fallback message
        bytes memory fallbackData = abi.encodePacked(bytes1(0x05), depositParams.depositNonce);

        // Call 'fallback'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, fallbackData);

        vm.deal(address(this), 1 ether);

        // Call retry Deposit should fail
        vm.expectRevert(IBranchBridgeAgent.DepositRedeemUnavailable.selector);
        bAgent.retryDepositSigned{value: 1 ether}(1, "", gasParams, true);
    }

    function testFuzzExecuteWithSettlement(address, uint256 _amount, uint256 _deposit, uint16 _dstChainId) public {
        // Input restrictions
        vm.assume(_amount > 0 && _deposit <= _amount && _dstChainId > 0);

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        address _recipient = address(this);

        vm.deal(localPortAddress, 1 ether);

        vm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hToken fuzzToken = new ERC20hToken(localPortAddress, "Test Ulysses Hermes omni token", "test-uhUNDER", 18);
        fuzzToken.mint(_recipient, _amount - _deposit);

        MockERC20 underToken = new MockERC20("u token", "U", 18);
        underToken.mint(_recipient, _deposit);

        vm.stopPrank();

        console2.log("testFuzzClearToken Data:");
        console2.log(_recipient);
        console2.log(address(fuzzToken));
        console2.log(address(underToken));
        console2.log(_amount);
        console2.log(_deposit);
        console2.log(_dstChainId);

        // Perform deposit
        makeTestCallAndBridge(_recipient, address(fuzzToken), address(underToken), _amount, _deposit, gasParams);

        // Encode Settlement Data for Clear Token Execution
        bytes memory settlementData = abi.encodePacked(
            bytes1(0x02), _recipient, uint32(1), address(fuzzToken), address(underToken), _amount, _deposit, bytes("")
        );

        // Call 'clearToken'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, settlementData);

        require(fuzzToken.balanceOf(_recipient) == _amount - _deposit);
        require(underToken.balanceOf(_recipient) == _deposit);
        require(fuzzToken.balanceOf(localPortAddress) == 0);
        require(underToken.balanceOf(localPortAddress) == 0);
    }

    address[] public hTokens;
    address[] public tokens;
    uint256[] public amounts;
    uint256[] public deposits;

    function testFuzzExecuteWithSettlementMultiple(
        uint256 _amount0,
        uint256 _amount1,
        uint256 _deposit0,
        uint256 _deposit1,
        uint16 _dstChainId
    ) public {
        _amount0 %= type(uint256).max / 1 ether;
        _amount1 %= type(uint256).max / 1 ether;

        //GasParams
        GasParams memory gasParams = GasParams(0.5 ether, 0.5 ether);

        address _recipient = address(this);

        // Input restrictions
        vm.assume(_amount0 > 0 && _deposit0 <= _amount0 && _amount1 > 0 && _deposit1 <= _amount1 && _dstChainId > 0);

        vm.startPrank(localPortAddress);

        // Mint Test tokens.
        ERC20hToken fuzzToken0 =
            new ERC20hToken(localPortAddress, "Test Ulysses Hermes omni token 0", "test-uhToken0", 18);
        ERC20hToken fuzzToken1 =
            new ERC20hToken(localPortAddress, "Test Ulysses Hermes omni token 1", "test-uhToken1", 18);

        fuzzToken0.mint(_recipient, _amount0 - _deposit0);
        fuzzToken1.mint(_recipient, _amount1 - _deposit1);

        MockERC20 underToken0 = new MockERC20("u0 token", "U0", 18);
        MockERC20 underToken1 = new MockERC20("u1 token", "U1", 18);
        underToken0.mint(_recipient, _deposit0);
        underToken1.mint(_recipient, _deposit1);

        console2.log("testFuzzExecuteWithSettlementMultiple DATA:");
        console2.log(_recipient);
        console2.log(address(fuzzToken0));
        console2.log(address(fuzzToken1));
        console2.log(address(underToken0));
        console2.log(address(underToken1));
        console2.log(_amount0);
        console2.log(_amount1);
        console2.log(_deposit0);
        console2.log(_deposit1);
        console2.log(_dstChainId);

        vm.stopPrank();

        // Cast to Dynamic
        hTokens.push(address(fuzzToken0));
        hTokens.push(address(fuzzToken1));
        tokens.push(address(underToken0));
        tokens.push(address(underToken1));
        amounts.push(_amount0);
        amounts.push(_amount1);
        deposits.push(_deposit0);
        deposits.push(_deposit1);

        // Perform deposit
        makeTestCallAndBridgeMultiple(_recipient, hTokens, tokens, amounts, deposits, gasParams);

        // Encode Settlement Data for Clear Token Execution
        bytes memory settlementData = abi.encodePacked(
            bytes1(0x03), _recipient, uint8(2), uint32(1), hTokens, tokens, amounts, deposits, bytes("")
        );

        // Call 'clearToken'
        vm.prank(lzEndpointAddress);
        bAgent.lzReceive(rootChainId, abi.encodePacked(rootBridgeAgentAddress, bAgent), 1, settlementData);

        assertEq(fuzzToken0.balanceOf(localPortAddress), 0);
        assertEq(fuzzToken1.balanceOf(localPortAddress), 0);
        assertEq(fuzzToken0.balanceOf(_recipient), _amount0 - _deposit0);
        assertEq(fuzzToken1.balanceOf(_recipient), _amount1 - _deposit1);
        assertEq(underToken0.balanceOf(localPortAddress), 0);
        assertEq(underToken1.balanceOf(localPortAddress), 0);
        assertEq(underToken0.balanceOf(_recipient), _deposit0);
        assertEq(underToken1.balanceOf(_recipient), _deposit1);
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

    function test_alreadyExecutedTransaction0x82(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x82, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x03(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x03, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x83(bytes4 _nonce, bool _setStatusRetrieved) public {
        test_alreadyExecutedTransaction(_nonce, 0x83, _setStatusRetrieved, 1024);
    }

    function test_alreadyExecutedTransaction0x04(bytes4 _nonce) public {
        test_alreadyExecutedTransaction(_nonce, 0x04, false, 1024);
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

        // If the deposit flag does not set this check, set it to 0x82 (Call with deposit with fallback)
        if (depositFlag == 0x00 || depositFlag > 0x04) {
            _depositFlag = 0x82;
            depositFlag = _depositFlag & 0x7F;
        }

        uint256 start;

        if (depositFlag == 0x03) {
            // _payload[22:26] = _nonce;
            start = 22;
        } else {
            // _payload[PARAMS_START_SIGNED:PARAMS_TKN_START_SIGNED] = _nonce;
            start = PARAMS_START_SIGNED;

            if (depositFlag != 0x02) {
                _depositFlag = depositFlag;

                if (depositFlag == 0x04) {
                    _setStatusRetrieved = false;
                }
            }
        }

        uint256 end = start + 4;
        bytes memory payload = new bytes(end > _payloadLength ? end : _payloadLength);
        payload[0] = _depositFlag;

        setBytes4(payload, _nonce, start);

        bAgent.setExecutionState(uint32(_nonce), _setStatusRetrieved ? STATUS_RETRIEVE : STATUS_DONE);

        vm.expectRevert(IRootBridgeAgent.AlreadyExecutedTransaction.selector);
        vm.prank(address(bAgent));
        bAgent.lzReceiveNonBlocking(lzEndpointAddress, rootChainId, rootBridgeAgentPath, payload);
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
    function _testRequiresEndpointBranch(
        BranchBridgeAgent _branchBridgeAgent,
        address _rootBridgeAgent,
        address _lzEndpointAddress,
        uint16 _rootChainId,
        address _endpoint,
        uint16 _srcChainId,
        bytes calldata _path
    ) external {
        if (_endpoint != _lzEndpointAddress) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        } else if (_path.length != 40) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_rootBridgeAgent != address(uint160(bytes20(_path[:20])))) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else if (_srcChainId != _rootChainId) {
            vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedCaller.selector);
        } else {
            // _payload[0] == 0xFF is always true
            vm.expectRevert(IBranchBridgeAgent.UnknownFlag.selector);
        }

        // Call lzReceiveNonBlocking because lzReceive should never fail
        vm.prank(address(_branchBridgeAgent));
        _branchBridgeAgent.lzReceiveNonBlocking(_endpoint, _srcChainId, _path, abi.encodePacked(bytes1(0xFF)));
    }

    function testRequiresEndpointBranch() public {
        this._testRequiresEndpointBranch(
            bAgent,
            rootBridgeAgentAddress,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            rootChainId,
            abi.encodePacked(rootBridgeAgentAddress, bAgent)
        );
    }

    function testRequiresEndpointBranch_NotCallingItself() public {
        vm.expectRevert(IBranchBridgeAgent.LayerZeroUnauthorizedEndpoint.selector);
        bAgent.lzReceiveNonBlocking(
            lzEndpointAddress,
            rootChainId,
            abi.encodePacked(rootBridgeAgentAddress, bAgent),
            abi.encodePacked(bytes1(0xFF))
        );
    }

    function testRequiresEndpointBranch_srcAddress() public {
        bytes memory _pathData = abi.encodePacked(address(1), address(1));
        testRequiresEndpointBranch_pathData(_pathData);
    }

    function testRequiresEndpointBranch_srcAddress(address _srcAddress) public {
        bytes memory _pathData = abi.encodePacked(_srcAddress, address(1));
        testRequiresEndpointBranch_pathData(_pathData);
    }

    function testRequiresEndpointBranch_pathData() public {
        bytes memory _pathData = abi.encodePacked(rootBridgeAgentAddress);
        testRequiresEndpointBranch_pathData(_pathData);
    }

    function testRequiresEndpointBranch_pathData(bytes memory _pathData) public {
        this._testRequiresEndpointBranch(
            bAgent, rootBridgeAgentAddress, lzEndpointAddress, rootChainId, lzEndpointAddress, rootChainId, _pathData
        );
    }

    function testRequiresEndpointBranch_srcChainId() public {
        testRequiresEndpointBranch_srcChainId(0);
    }

    function testRequiresEndpointBranch_srcChainId(uint16 _srcChainId) public {
        this._testRequiresEndpointBranch(
            bAgent,
            rootBridgeAgentAddress,
            lzEndpointAddress,
            rootChainId,
            lzEndpointAddress,
            _srcChainId,
            abi.encodePacked(rootBridgeAgentAddress, bAgent)
        );
    }

    //////////////////////////////////////   HELPERS   //////////////////////////////////////

    function testCreateDeposit(
        uint32 _depositNonce,
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) private view {
        // Get Deposit.
        Deposit memory deposit = bRouter.getDepositEntry(_depositNonce);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        require(
            keccak256(abi.encodePacked(deposit.hTokens)) == keccak256(abi.encodePacked(_hTokens)),
            "Deposit local hToken doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.tokens)) == keccak256(abi.encodePacked(_tokens)),
            "Deposit underlying token doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.amounts)) == keccak256(abi.encodePacked(_amounts)),
            "Deposit amount doesn't match"
        );
        require(
            keccak256(abi.encodePacked(deposit.deposits)) == keccak256(abi.encodePacked(_deposits)),
            "Deposit deposit doesn't match"
        );

        require(deposit.status == 0, "Deposit status should be success");

        for (uint256 i = 0; i < _hTokens.length; i++) {
            if (_amounts[i] - _deposits[i] > 0 && _deposits[i] == 0) {
                require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
            } else if (_amounts[i] - _deposits[i] > 0 && _deposits[i] > 0) {
                require(MockERC20(_hTokens[i]).balanceOf(_user) == 0);
                require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
                require(MockERC20(_tokens[i]).balanceOf(localPortAddress) == _deposits[i]);
            } else {
                require(MockERC20(_tokens[i]).balanceOf(_user) == 0);
                require(MockERC20(_tokens[i]).balanceOf(localPortAddress) == _deposits[i]);
            }
        }
    }

    function testCreateDepositSingle(
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit
    ) private {
        delete hTokens;
        delete tokens;
        delete amounts;
        delete deposits;
        // Cast to Dynamic
        hTokens = new address[](1);
        hTokens[0] = _hToken;
        tokens = new address[](1);
        tokens[0] = _token;
        amounts = new uint256[](1);
        amounts[0] = _amount;
        deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Get Deposit
        Deposit memory deposit = bRouter.getDepositEntry(_depositNonce);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

        if (_amount != 0 || _deposit != 0) {
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
        }

        require(deposit.status == 0, "Deposit status should be succesful.");

        console2.log("TEST DEPOSIT");

        console2.logUint(amounts[0]);
        console2.logUint(deposits[0]);

        if (hTokens[0] != address(0) || tokens[0] != address(0)) {
            if (amounts[0] > 0 && deposits[0] == 0) {
                require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");

                require(MockERC20(hTokens[0]).balanceOf(localPortAddress) == 0, "Deposit hToken balance doesn't match");
            } else if (amounts[0] - deposits[0] > 0 && deposits[0] > 0) {
                console2.log(_user);
                console2.log(localPortAddress);

                require(MockERC20(hTokens[0]).balanceOf(_user) == 0, "Deposit hToken balance doesn't match");

                require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
                require(
                    MockERC20(tokens[0]).balanceOf(localPortAddress) == _deposit, "Deposit token balance doesn't match"
                );
            } else {
                require(MockERC20(tokens[0]).balanceOf(_user) == 0, "Deposit token balance doesn't match");
                require(
                    MockERC20(tokens[0]).balanceOf(localPortAddress) == _deposit, "Deposit token balance doesn't match"
                );
            }
        }
    }

    function makeTestCallAndBridge(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        GasParams memory _gasParams
    ) private {
        // Prepare deposit info
        DepositInput memory depositInput =
            DepositInput({hToken: _hToken, token: _token, amount: _amount, deposit: _deposit});

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Approve spend by router
        ERC20hToken(_hToken).approve(address(bRouter), _amount - _deposit);
        MockERC20(_token).approve(address(bRouter), _deposit);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridge{value: 1 ether}(bytes("testdata"), depositInput, _gasParams);

        // Prank out of user account
        vm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(_hToken), address(_token), _amount, _deposit);
    }

    function makeTestCallAndBridgeSigned(
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        GasParams memory _gasParams,
        bool _hasFallbackToggled
    ) private {
        // Prepare deposit info
        DepositInput memory depositInput =
            DepositInput({hToken: _hToken, token: _token, amount: _amount, deposit: _deposit});

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        // Approve spend by router
        ERC20hToken(_hToken).approve(localPortAddress, _amount - _deposit);
        MockERC20(_token).approve(localPortAddress, _deposit);

        //Call Deposit function
        bAgent.callOutSignedAndBridge{value: 1 ether}(bytes("testdata"), depositInput, _gasParams, _hasFallbackToggled);

        // Prank out of user account
        vm.stopPrank();

        // Test If Deposit was successful
        testCreateDepositSingle(uint32(1), _user, address(_hToken), address(_token), _amount, _deposit);
    }

    function makeTestCallAndBridgeMultiple(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        GasParams memory _gasParams
    ) private {
        //Prepare deposit info
        DepositMultipleInput memory depositInput =
            DepositMultipleInput({hTokens: _hTokens, tokens: _tokens, amounts: _amounts, deposits: _deposits});

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        console2.log(_hTokens[0], _deposits[0]);

        // Approve spend by router
        MockERC20(_hTokens[0]).approve(address(bRouter), _amounts[0] - _deposits[0]);
        MockERC20(_tokens[0]).approve(address(bRouter), _deposits[0]);
        MockERC20(_hTokens[1]).approve(address(bRouter), _amounts[1] - _deposits[1]);
        MockERC20(_tokens[1]).approve(address(bRouter), _deposits[1]);

        //Call Deposit function
        IBranchRouter(bRouter).callOutAndBridgeMultiple{value: 1 ether}(bytes("test"), depositInput, _gasParams);

        // Prank out of user account
        vm.stopPrank();

        // Test If Deposit was successful
        testCreateDeposit(uint32(1), _user, _hTokens, _tokens, _amounts, _deposits);
    }

    function makeTestCallAndBridgeMultipleSigned(
        address _user,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        GasParams memory _gasParams
    ) private {
        //Prepare deposit info
        DepositMultipleInput memory depositInput =
            DepositMultipleInput({hTokens: _hTokens, tokens: _tokens, amounts: _amounts, deposits: _deposits});

        // Prank into user account
        vm.startPrank(_user);

        // Get some gas.
        vm.deal(_user, 1 ether);

        console2.log(_hTokens[0], _deposits[0]);

        // Approve spend by router
        MockERC20(_hTokens[0]).approve(address(localPortAddress), _amounts[0] - _deposits[0]);
        MockERC20(_tokens[0]).approve(address(localPortAddress), _deposits[0]);
        MockERC20(_hTokens[1]).approve(address(localPortAddress), _amounts[1] - _deposits[1]);
        MockERC20(_tokens[1]).approve(address(localPortAddress), _deposits[1]);

        //Call Deposit function
        bAgent.callOutSignedAndBridgeMultiple{value: 1 ether}(bytes("test"), depositInput, _gasParams, true);

        // Prank out of user account
        vm.stopPrank();

        // Test If Deposit was successful
        testCreateDeposit(uint32(1), _user, _hTokens, _tokens, _amounts, _deposits);
    }
}
