//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "./ImportHelper.sol";

library BranchBridgeAgentHelper {
    using BranchBridgeAgentHelper for BranchBridgeAgent;

    /*//////////////////////////////////////////////////////////////
                        CREATE DEPOSIT HELPERS
    //////////////////////////////////////////////////////////////*/

    function _testCreateDepositSingle(
        BranchBridgeAgent _bridgeAgent,
        uint32 _depositNonce,
        address _user,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit
    ) internal view {
        // Cast to Dynamic TODO clean up
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Get Deposit
        Deposit memory deposit = _bridgeAgent.getDepositEntry(_depositNonce);

        // Check deposit
        require(deposit.owner == _user, "Deposit owner doesn't match");

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

        require(deposit.status == 0, "Deposit status should be succesful.");
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE DEPOSIT HELPERS
    //////////////////////////////////////////////////////////////*/

    address private constant CONSOLE2_ADDRESS = 0x000000000000000000636F6e736F6c652e6c6f67;

    function adjustValues(address _user, uint256 _amount, uint256 _deposit, uint256 _amountOut, uint256 _depositOut)
        public
        view
        returns (address, uint256, uint256, uint256, uint256)
    {
        // Input max restrictions
        _amount %= type(uint224).max;
        _deposit %= type(uint224).max;
        _amountOut %= type(uint224).max;
        _depositOut %= type(uint224).max;

        /**
         * Should be equivalent to:
         *
         * uint256 size;
         * assembly ("memory-safe") {
         *     size := extcodesize(_user)
         * }
         *
         * hevm.assume(
         *     _user != address(0) && size == 0 && _amount > _deposit && _amount >= _amountOut
         *         && _amount - _amountOut >= _depositOut && _depositOut < _amountOut
         * );
         */
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(_user)
        }

        // Can't be zero address and avoid any precompiles or cheatcodes that would revert when sending eth
        if (_user < address(100) || size > 0 || _user == CONSOLE2_ADDRESS) {
            _user = address(0xDEAD);
        }

        if (_amount <= _deposit) {
            _amount = _deposit + 1;
        }

        if (_amount < _amountOut || _amountOut == 0) {
            _amountOut = _amount;
        }

        if (_amount - _amountOut < _depositOut) {
            _depositOut = _amount - _amountOut;
        }

        if (_depositOut >= _amountOut) {
            _depositOut = _amountOut - 1;
        }

        return (_user, _amount, _deposit, _amountOut, _depositOut);
    }
}
