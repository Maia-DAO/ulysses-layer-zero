//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract MockPortStrategy {
    using SafeTransferLib for address;

    function withdraw(address port, address token, uint256 amount) public {
        token.safeTransfer(port, amount);
    }
}
