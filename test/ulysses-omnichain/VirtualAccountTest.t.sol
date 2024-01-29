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

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

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
                              TEST ERC721
    //////////////////////////////////////////////////////////////*/
    function test_receiveERC721(address _userAddress, bytes32 _tokenSalt, uint256 _tokenId) public {
        _testReceiveERC721(_userAddress, _tokenSalt, localPortAddress, _tokenId);
    }

    function test_withdrawERC721(address _userAddress, bytes32 _tokenSalt, uint256 _tokenId) public {
        (VirtualAccount virtualAccount, MockERC721 mockERC721) =
            _testReceiveERC721(_userAddress, _tokenSalt, localPortAddress, _tokenId);

        MockRootPort(localPortAddress).setRouterApproved(virtualAccount, address(this), true);
        virtualAccount.withdrawERC721(address(mockERC721), _tokenId);

        assertEq(mockERC721.ownerOf(_tokenId), address(this));
    }

    function test_withdrawERC721_Unauthorized(address _userAddress, bytes32 _tokenSalt, uint256 _tokenId) public {
        if (_userAddress == address(this)) _userAddress = address(1);

        (VirtualAccount virtualAccount, MockERC721 mockERC721) =
            _testReceiveERC721(_userAddress, _tokenSalt, localPortAddress, _tokenId);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        virtualAccount.withdrawERC721(address(mockERC721), _tokenId);
    }

    function test_OnERC721Received() public {
        VirtualAccount virtualAccount = _deployVirtualAccount(address(this), localPortAddress);

        assertEq(
            virtualAccount.onERC721Received(address(0), address(0), 0, ""),
            bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))
        );
    }

    /*//////////////////////////////////////////////////////////////
                             TEST ERC1155
    //////////////////////////////////////////////////////////////*/

    function test_receiveERC1155(address _userAddress, bytes32 _tokenSalt, uint256 _tokenId, uint256 _amount) public {
        _testReceiveERC1155(_userAddress, _tokenSalt, localPortAddress, _tokenId, _amount);
    }

    function test_receiveERC1155_Batch(address _userAddress, bytes32 _tokenSalt) public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);

        // Define token IDs and amounts for batch transfer
        tokenIds[0] = 1; // First token ID
        tokenIds[1] = 2; // Second token ID
        amounts[0] = 10; // Amount for the first token
        amounts[1] = 20; // Amount for the second token

        _testReceiveERC1155Batch(_userAddress, _tokenSalt, localPortAddress, tokenIds, amounts);
    }

    function test_withdrawERC1155(address _userAddress, bytes32 _tokenSalt, uint256 _tokenId, uint256 _amount) public {
        (VirtualAccount virtualAccount, MockERC1155 mockERC1155) =
            _testReceiveERC1155(_userAddress, _tokenSalt, localPortAddress, _tokenId, _amount);

        MockRootPort(localPortAddress).setRouterApproved(virtualAccount, address(this), true);

        _withdrawERC1155UsingCall(virtualAccount, address(mockERC1155), _tokenId, _amount, address(this));

        // Verify the balance after withdrawal
        assertEq(mockERC1155.balanceOf(address(this), _tokenId), _amount);
    }

    function test_withdrawERC1155_Unauthorized(
        address _userAddress,
        bytes32 _tokenSalt,
        uint256 _tokenId,
        uint256 _amount
    ) public {
        if (_userAddress == address(this)) _userAddress = address(1);

        (VirtualAccount virtualAccount, MockERC1155 mockERC1155) =
            _testReceiveERC1155(_userAddress, _tokenSalt, localPortAddress, _tokenId, _amount);

        hevm.expectRevert(IVirtualAccount.UnauthorizedCaller.selector);
        _withdrawERC1155UsingCall(virtualAccount, address(mockERC1155), _tokenId, _amount, address(this));
    }

    function test_OnERC1155Received() public {
        VirtualAccount virtualAccount = _deployVirtualAccount(address(this), localPortAddress);

        assertEq(
            virtualAccount.onERC1155Received(address(0), address(0), 0, 0, ""),
            bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))
        );
    }

    function test_OnERC1155BatchReceived() public {
        VirtualAccount virtualAccount = _deployVirtualAccount(address(this), localPortAddress);

        assertEq(
            virtualAccount.onERC1155BatchReceived(address(0), address(0), new uint256[](0), new uint256[](0), ""),
            bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))
        );
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

    function test_call_two_calls() public {
        address userAddress = address(this);
        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        // Test successful call
        Call[] memory calls = new Call[](2);
        calls[0] = Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
        calls[1] = Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));

        bytes[] memory returnData = virtualAccount.call(calls);
        assertEq(keccak256(returnData[0]), keccak256(abi.encodePacked(blockhash(block.number))));
        assertEq(keccak256(returnData[1]), keccak256(abi.encodePacked(blockhash(block.number))));
    }


    function test_call_unsuccessful() public {
        address userAddress = address(this);
        VirtualAccount virtualAccount = _deployVirtualAccount(userAddress, localPortAddress);

        // Should fail due to "thisMethodReverts()"
        Call[] memory calls = new Call[](2);
        calls[0] = Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
        calls[1] = Call(address(callee), abi.encodeWithSignature("thisMethodReverts()"));

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.call(calls);

        // Should fail if we call a non-contract address
        Call[] memory calls2 = new Call[](2);
        calls2[0] = Call(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number));
        calls2[1] = Call(address(1), "");

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.call(calls2);
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

        // Should fail due to "thisMethodReverts()"
        PayableCall[] memory calls = new PayableCall[](3);
        calls[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls[1] = PayableCall(address(callee), abi.encodeWithSignature("thisMethodReverts()"), 0);
        calls[2] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 0);

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.payableCall{value: 1}(calls);

        // Should fail if we call a non-contract address
        PayableCall[] memory calls2 = new PayableCall[](3);
        calls[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls[1] = PayableCall(address(1), "", 0);
        calls[2] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 0);

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.payableCall{value: 1}(calls2);

        // Should fail if we don't provide enough value
        PayableCall[] memory calls3 = new PayableCall[](2);
        calls3[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls3[1] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 1);

        hevm.expectRevert(IVirtualAccount.CallFailed.selector);
        virtualAccount.payableCall(calls3);

        // Works if we provide enough value
        PayableCall[] memory calls4 = new PayableCall[](2);
        calls4[0] = PayableCall(address(callee), abi.encodeWithSignature("getBlockHash(uint256)", block.number), 0);
        calls4[1] =
            PayableCall(address(callee), abi.encodeWithSignature("sendBackValue(address)", address(etherSink)), 1);

        virtualAccount.payableCall{value: 1}(calls4);
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

    function _deployMockERC721(bytes32 _tokenSalt) internal returns (MockERC721) {
        return new MockERC721{salt: _tokenSalt}("Test Token", "TTK");
    }

    function _testReceiveERC721(address _userAddress, bytes32 _tokenSalt, address _localPortAddress, uint256 _tokenId)
        internal
        returns (VirtualAccount virtualAccount, MockERC721 mockERC721)
    {
        virtualAccount = _deployVirtualAccount(_userAddress, _localPortAddress);
        mockERC721 = _deployMockERC721(_tokenSalt);

        // Mint and send the ERC721 token to the VirtualAccount
        mockERC721.mint(address(this), _tokenId);
        mockERC721.safeTransferFrom(address(this), address(virtualAccount), _tokenId, "");

        // Check if the VirtualAccount is now the owner of the token
        assertEq(mockERC721.ownerOf(_tokenId), address(virtualAccount));
    }

    function _deployMockERC1155(bytes32 _tokenSalt) internal returns (MockERC1155) {
        return new MockERC1155{salt: _tokenSalt}();
    }

    function _testSendERC1155(address _to, MockERC1155 _token, uint256 _tokenId, uint256 _amount) internal {
        uint256 oldBalance = _token.balanceOf(_to, _tokenId);

        // Minting the token to the sender first
        _token.mint(address(this), _tokenId, _amount, "");

        _token.safeTransferFrom(address(this), _to, _tokenId, _amount, "");

        assertEq(_token.balanceOf(_to, _tokenId), _amount + oldBalance);
    }

    function _testReceiveERC1155(
        address _userAddress,
        bytes32 _tokenSalt,
        address _localPortAddress,
        uint256 _tokenId,
        uint256 _amount
    ) internal returns (VirtualAccount virtualAccount, MockERC1155 mockERC1155) {
        virtualAccount = _deployVirtualAccount(_userAddress, _localPortAddress);
        mockERC1155 = _deployMockERC1155(_tokenSalt);

        // Mint and send the ERC1155 tokens to the VirtualAccount
        mockERC1155.mint(address(this), _tokenId, _amount, "");
        mockERC1155.safeTransferFrom(address(this), address(virtualAccount), _tokenId, _amount, "");

        // Check if the VirtualAccount has the correct balance of the token
        assertEq(mockERC1155.balanceOf(address(virtualAccount), _tokenId), _amount);
    }

    function _testReceiveERC1155Batch(
        address _userAddress,
        bytes32 _tokenSalt,
        address _localPortAddress,
        uint256[] memory _tokenIds,
        uint256[] memory _amounts
    ) internal returns (VirtualAccount virtualAccount, MockERC1155 mockERC1155) {
        virtualAccount = _deployVirtualAccount(_userAddress, _localPortAddress);
        mockERC1155 = _deployMockERC1155(_tokenSalt);

        // Mint and send the ERC1155 tokens to the VirtualAccount
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            mockERC1155.mint(address(this), _tokenIds[i], _amounts[i], "");
        }
        mockERC1155.batchMint(address(this), _tokenIds, _amounts, "");
        mockERC1155.safeBatchTransferFrom(address(this), address(virtualAccount), _tokenIds, _amounts, "");

        // Check if the VirtualAccount has the correct balances of the tokens
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            assertEq(mockERC1155.balanceOf(address(virtualAccount), _tokenIds[i]), _amounts[i]);
        }
    }

    function _withdrawERC1155UsingCall(
        VirtualAccount virtualAccount,
        address erc1155Token,
        uint256 tokenId,
        uint256 amount,
        address recipient
    ) internal {
        // Construct call data for ERC1155 safeTransferFrom function
        bytes memory callData = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            address(virtualAccount),
            recipient,
            tokenId,
            amount,
            ""
        );

        // Construct the Call struct
        Call[] memory calls = new Call[](1);
        calls[0] = Call({target: erc1155Token, callData: callData});

        // Execute the call
        virtualAccount.call(calls);
    }
}
