//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./helpers/ImportHelper.sol";

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

    function _deployVirtualAccount(address _userAddress, address _localPortAddress) internal returns (VirtualAccount) {
        return new VirtualAccount(_userAddress, _localPortAddress);
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

        hevm.deal(address(this), _depositAmount);

        assertEq(address(virtualAccount).balance, 0);

        address(virtualAccount).safeTransferETH(_depositAmount);

        assertEq(address(virtualAccount).balance, _depositAmount);
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
}
