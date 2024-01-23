//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "../helpers/ImportHelper.sol";

contract ReservesRatioTest is DSTestPlus {
    using DecodeBridgeInMultipleParams for bytes;

    uint256 private constant DIVISIONER = 100;
    uint256 private constant MIN_RESERVE_RATIO = 70;

    function test_checkReserveRatioLimit() public {
        test_fuzz_checkReserveRatioLimit(80);
    }

    function test_checkReserveRatioLimitTooHigh() public {
        test_fuzz_checkReserveRatioLimit(101);
    }

    function test_checkReserveRatioLimitTooLow() public {
        test_fuzz_checkReserveRatioLimit(69);
    }

    function test_fuzz_checkReserveRatioLimit(uint256 _reserveRatioManagementLimit) public {
        // Check if reserveRatioManagementLimit is less or equal to 100% or greater than or equal to 70%
        if (_reserveRatioManagementLimit > DIVISIONER || _reserveRatioManagementLimit < MIN_RESERVE_RATIO) {
            hevm.expectRevert(ReservesRatio.InvalidMinimumReservesRatio.selector);
        }

        ReservesRatio.checkReserveRatioLimit(_reserveRatioManagementLimit);
    }

    function test_fuzz_checkReserveRatioLimit_smallerSpace(uint8 _reserveRatioManagementLimit) public {
        // Check if reserveRatioManagementLimit is less or equal to 100% or greater than or equal to 70%
        if (_reserveRatioManagementLimit > DIVISIONER || _reserveRatioManagementLimit < MIN_RESERVE_RATIO) {
            hevm.expectRevert(ReservesRatio.InvalidMinimumReservesRatio.selector);
        }

        ReservesRatio.checkReserveRatioLimit(_reserveRatioManagementLimit);
    }
}
