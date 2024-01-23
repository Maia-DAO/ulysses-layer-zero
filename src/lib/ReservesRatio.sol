// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library ReservesRatio {
    uint256 private constant DIVISIONER = 100;
    uint256 private constant MIN_RESERVE_RATIO = 70;

    function checkReserveRatioLimit(uint256 _reserveRatioManagementLimit) internal pure {
        // Check if reserveRatioManagementLimit is less or equal to 100%
        if (_reserveRatioManagementLimit > DIVISIONER) {
            revert InvalidMinimumReservesRatio();
        }
        // Check if reserveRatioManagementLimit is greater than or equal to 70%
        if (_reserveRatioManagementLimit < MIN_RESERVE_RATIO) {
            revert InvalidMinimumReservesRatio();
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when minimum reserves ratio is set too low.
    error InvalidMinimumReservesRatio();
}
