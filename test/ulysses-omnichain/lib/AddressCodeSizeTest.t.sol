//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "../helpers/ImportHelper.sol";

contract AddressCodeSizeTest is Test {
    using AddressCodeSize for address;

    function test_isEOA() public {
        test_fuzz_isEOA(address(0xCAFE));
    }

    function test_isEOA_not() public {
        test_fuzz_isEOA_not(address(this));
    }

    function test_fuzz_isEOA(address addr) public {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(addr)
        }

        assertEq(size == 0, addr.isEOA());
    }

    function test_fuzz_isEOA_not(address addr) public {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(addr)
        }

        assertEq(size > 0, !addr.isEOA());
    }

    function test_isContract() public {
        test_fuzz_isContract(address(this));
    }

    function test_isContract_not() public {
        test_fuzz_isContract_not(address(0xCAFE));
    }

    function test_fuzz_isContract(address addr) public {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(addr)
        }

        assertEq(size > 0, addr.isContract());
    }

    function test_fuzz_isContract_not(address addr) public {
        uint256 size;
        assembly ("memory-safe") {
            size := extcodesize(addr)
        }

        assertEq(size == 0, !addr.isContract());
    }
}
