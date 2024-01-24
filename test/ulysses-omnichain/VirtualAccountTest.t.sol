//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./helpers/ImportHelper.sol";

import {EtherSink} from "./mocks/EtherSink.t.sol";
import {MockCallee} from "./mocks/MockCallee.t.sol";

contract MockRootPort {
    /// @notice Holds the mapping from Virtual account to router address => bool.
    /// @notice Stores whether a router is approved to spend a virtual account.
    mapping(VirtualAccount acount => mapping(address router => bool allowed)) public isRouterApproved;

    function setRouterApproved(VirtualAccount account, address router, bool allowed) public {
        isRouterApproved[account][router] = allowed;
    }
}

contract VirtualAccountTest is DSTestPlus {
    using SafeTransferLib for address;

    MockCallee callee;
    EtherSink etherSink;

    /*//////////////////////////////////////////////////////////////
                             GLOBAL CONTRACTS
    //////////////////////////////////////////////////////////////*/

    address public localPortAddress = address(new MockRootPort());

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                               TEST SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Setups up the testing suite for call and payableCall
    function setUp() public {
        callee = new MockCallee();
        etherSink = new EtherSink();
    }

    function _deployVirtualAccount(address _userAddress, address _localPortAddress) internal returns (VirtualAccount) {
        hevm.prank(_localPortAddress);
        return new VirtualAccount(_userAddress);
    }

    function test_constructor(address _userAddress, address _localPortAddress)
        public
        returns (VirtualAccount virtualAccount)
    {
        virtualAccount = _deployVirtualAccount(_userAddress, _localPortAddress);

        assertEq(virtualAccount.userAddress(), _userAddress);
        assertEq(virtualAccount.localPortAddress(), _localPortAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    function test_requiresApprovedCaller_withdrawNative(address _userAddress, uint256 _withdrawAmount)
        public
        returns (VirtualAccount virtualAccount)
    {
        if (_userAddress == address(this)) _userAddress = address(1);

        virtualAccount = _deployVirtualAccount(_userAddress, localPortAddress);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.withdrawNative(_withdrawAmount);
    }

    function test_requiresApprovedCaller_withdrawERC20(address _userAddress, address _token, uint256 _withdrawAmount)
        public
        returns (VirtualAccount virtualAccount)
    {
        if (_userAddress == address(this)) _userAddress = address(1);

        virtualAccount = _deployVirtualAccount(_userAddress, localPortAddress);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.withdrawERC20(_token, _withdrawAmount);
    }

    function test_requiresApprovedCaller_withdrawERC721(address _userAddress, address _token, uint256 _tokenId)
        public
        returns (VirtualAccount virtualAccount)
    {
        if (_userAddress == address(this)) _userAddress = address(1);

        virtualAccount = _deployVirtualAccount(_userAddress, localPortAddress);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.withdrawERC721(_token, _tokenId);
    }

    function test_requiresApprovedCaller_call(address _userAddress, Call[] calldata _calls)
        public
        returns (VirtualAccount virtualAccount)
    {
        if (_userAddress == address(this)) _userAddress = address(1);

        virtualAccount = _deployVirtualAccount(_userAddress, localPortAddress);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.call(_calls);
    }

    function test_requiresApprovedCaller_payableCall(address _userAddress, PayableCall[] calldata _calls)
        public
        returns (VirtualAccount virtualAccount)
    {
        if (_userAddress == address(this)) _userAddress = address(1);

        virtualAccount = _deployVirtualAccount(_userAddress, localPortAddress);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.payableCall(_calls);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST NATIVE
    //////////////////////////////////////////////////////////////*/

    function test_receiveETH(address _userAddress, address _localPortAddress, uint256 _depositAmount)
        public
        returns (VirtualAccount virtualAccount)
    {
        virtualAccount = _deployVirtualAccount(_userAddress, _localPortAddress);

        _testSendEth(address(virtualAccount), _depositAmount);
    }

    function test_withdrawNative(address _userAddress, uint256 _depositAmount, uint256 _withdrawAmount)
        public
        returns (VirtualAccount virtualAccount)
    {
        (_depositAmount, _withdrawAmount) = _parseDepositAndWithdrawAmounts(_depositAmount, _withdrawAmount);

        virtualAccount = test_receiveETH(_userAddress, localPortAddress, _depositAmount);

        MockRootPort(localPortAddress).setRouterApproved(virtualAccount, address(this), true);
        virtualAccount.withdrawNative(_withdrawAmount);

        assertEq(address(virtualAccount).balance, _depositAmount - _withdrawAmount);
    }

    function test_withdrawNative_Unautharized(address _userAddress, uint256 _depositAmount, uint256 _withdrawAmount)
        public
        returns (VirtualAccount virtualAccount)
    {
        if (_userAddress == address(this)) _userAddress = address(1);
        (_depositAmount, _withdrawAmount) = _parseDepositAndWithdrawAmounts(_depositAmount, _withdrawAmount);

        virtualAccount = test_receiveETH(_userAddress, localPortAddress, _depositAmount);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.withdrawNative(_withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST ERC20
    //////////////////////////////////////////////////////////////*/

    function test_receiveERC20() public {
        test_receiveERC20(address(this), localPortAddress, 0, 100 ether);
    }

    function test_receiveERC20(
        address _userAddress,
        address _localPortAddress,
        bytes32 _tokenSalt,
        uint256 _depositAmount
    ) public returns (VirtualAccount virtualAccount) {
        address token = address(new MockERC20{salt: _tokenSalt}("Test Token", "TTK", 18));

        virtualAccount = _test_receiveERC20(_userAddress, _localPortAddress, token, _depositAmount);
    }

    function _test_receiveERC20(address _userAddress, address _localPortAddress, address _token, uint256 _depositAmount)
        internal
        returns (VirtualAccount virtualAccount)
    {
        virtualAccount = _deployVirtualAccount(_userAddress, _localPortAddress);

        _testSendERC20(address(virtualAccount), _token, _depositAmount);
    }

    function test_withdrawERC20(
        address _userAddress,
        bytes32 _tokenSalt,
        uint256 _depositAmount,
        uint256 _withdrawAmount
    ) public returns (VirtualAccount virtualAccount) {
        (_depositAmount, _withdrawAmount) = _parseDepositAndWithdrawAmounts(_depositAmount, _withdrawAmount);

        address token = address(new MockERC20{salt: _tokenSalt}("Test Token", "TTK", 18));

        virtualAccount = _test_receiveERC20(_userAddress, localPortAddress, token, _depositAmount);

        MockRootPort(localPortAddress).setRouterApproved(virtualAccount, address(this), true);
        virtualAccount.withdrawERC20(token, _withdrawAmount);

        assertEq(token.balanceOf(address(virtualAccount)), _depositAmount - _withdrawAmount);
    }

    function test_withdrawERC20_Unautharized(
        address _userAddress,
        bytes32 _tokenSalt,
        uint256 _depositAmount,
        uint256 _withdrawAmount
    ) public returns (VirtualAccount virtualAccount) {
        if (_userAddress == address(this)) _userAddress = address(1);
        (_depositAmount, _withdrawAmount) = _parseDepositAndWithdrawAmounts(_depositAmount, _withdrawAmount);

        address token = address(new MockERC20{salt: _tokenSalt}("Test Token", "TTK", 18));

        virtualAccount = _test_receiveERC20(_userAddress, localPortAddress, token, _depositAmount);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.withdrawERC20(token, _withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                              TEST CALLS
    //////////////////////////////////////////////////////////////*/

    function test_call() public {
        address userAddress = address(this);
        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        // Test successful call
        Call[] memory calls = new Call[](1);
        calls[0] = Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));

        bytes[] memory returnData = virtualAccount.call(calls);
        assertEq(keccak256(returnData[0]), keccak256(abi.encodePacked(blockhash(block.number))));
    }

    function test_call_unsuccessful() public {
        address userAddress = address(this);
        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        // Test unexpected revert
        Call[] memory calls = new Call[](2);
        calls[0] = Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
        calls[1] = Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.call(calls);
    }

    /*//////////////////////////////////////////////////////////////
                          TEST PAYABLE CALLS
    //////////////////////////////////////////////////////////////*/

    function test_payableCall_singleCall() public {
        address userAddress = address(this);

        address targetAddress = userAddress;

        PayableCall memory call = PayableCall(targetAddress, "", 1 ether);

        PayableCall[] memory calls = new PayableCall[](1);

        calls[0] = call;

        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        hevm.deal(userAddress, 1 ether);

        hevm.prank(userAddress);

        hevm.expectCall(targetAddress, "");

        virtualAccount.payableCall{value: 1 ether}(calls);

        require(address(virtualAccount).balance == 0, "Balance wasn't cleared!");
    }

    function test_payableCall_isEOA() public {
        address userAddress = address(this);

        address targetAddress = address(1);

        PayableCall memory call = PayableCall(targetAddress, "", 1 ether);

        PayableCall[] memory calls = new PayableCall[](1);

        calls[0] = call;

        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        hevm.deal(userAddress, 1 ether);

        hevm.startPrank(userAddress);

        hevm.expectRevert(abi.encodeWithSignature("CallFailed()"));

        virtualAccount.payableCall{value: 1 ether}(calls);
    }

    function test_payableCall_notAllSpent() public {
        address userAddress = address(this);

        address targetAddress = userAddress;

        PayableCall memory call = PayableCall(targetAddress, "", 1 ether);

        PayableCall[] memory calls = new PayableCall[](1);

        calls[0] = call;

        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        hevm.deal(userAddress, 2 ether);

        hevm.startPrank(userAddress);

        hevm.expectRevert(abi.encodeWithSignature("CallFailed()"));

        virtualAccount.payableCall{value: 2 ether}(calls);
    }

    function test_payableCall() public {
        address userAddress = address(this);
        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        PayableCall[] memory calls = new PayableCall[](2);
        calls[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls[1] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 1);
        (bytes[] memory returnData) = virtualAccount.payableCall{value: 1}(calls);

        assertEq(keccak256(returnData[0]), keccak256(abi.encodePacked(blockhash(block.number))));
        assertEq(returnData[1].length, 0);
    }

    function test_payableCall_unsuccessful() public {
        address userAddress = address(this);
        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        PayableCall[] memory calls = new PayableCall[](3);
        calls[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls[1] = PayableCall(address(callee), abi.encodeWithSignature("thisMethodReverts()"), 0);
        calls[2] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 0);

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.payableCall{value: 1}(calls);

        // Should fail if we don't provide enough value
        PayableCall[] memory calls2 = new PayableCall[](2);
        calls2[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls2[1] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 1);

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.payableCall(calls2);

        // Works if we provide enough value
        PayableCall[] memory calls3 = new PayableCall[](2);
        calls3[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls3[1] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 1);

        virtualAccount.payableCall{value: 1}(calls3);
    }

    /*//////////////////////////////////////////////////////////////
                             TEST HELPERS
    //////////////////////////////////////////////////////////////*/

    function _parseDepositAndWithdrawAmounts(uint256 depositAmount, uint256 withdrawAmount)
        internal
        pure
        returns (uint256, uint256)
    {
        // Can't withdraw 0 or more than deposited
        if (depositAmount == 0) return (0, 0);

        return (depositAmount, withdrawAmount % depositAmount);
    }

    function _testSendEth(address _to, uint256 _amount) internal {
        hevm.deal(address(this), _amount);

        uint256 oldBalance = _to.balance;

        _to.safeTransferETH(_amount);

        assertEq(_to.balance, _amount + oldBalance);
    }

    function _testSendERC20(address _to, address _token, uint256 _amount) internal {
        MockERC20(_token).mint(address(this), _amount);

        uint256 oldBalance = _token.balanceOf(_to);

        _token.safeTransfer(_to, _amount);

        assertEq(_token.balanceOf(_to), _amount + oldBalance);
    }
}
