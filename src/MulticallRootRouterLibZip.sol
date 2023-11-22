// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibZip} from "solady/utils/LibZip.sol";

import {MulticallRootRouter} from "./MulticallRootRouter.sol";

/**
 * @title  Multicall Root Router LibZip Contract
 * @author MaiaDAO
 * @notice Root Router implementation for interfacing with third-party dApps present in the Root Omnichain Environment.
 * @dev    Func IDs for calling these  functions through the messaging layer:
 *
 *         CROSS-CHAIN MESSAGING FUNCIDs
 *         -----------------------------
 *         FUNC ID      | FUNC NAME
 *         -------------+---------------
 *         0x01         | multicallNoOutput
 *         0x02         | multicallSingleOutput
 *         0x03         | multicallMultipleOutput
 */
contract MulticallRootRouterLibZip is MulticallRootRouter {
    using LibZip for bytes;

    /**
     * @notice Constructor for Multicall Root Router.
     * @param _localChainId The local chain id.
     * @param _localPortAddress The local port address.
     * @param _multicallAddress The address of the Multicall contract.
     */
    constructor(uint256 _localChainId, address _localPortAddress, address _multicallAddress)
        MulticallRootRouter(_localChainId, _localPortAddress, _multicallAddress)
    {}

    /*///////////////////////////////////////////////////////////////
                            DECODING FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     *  @notice Function hook to decode bytes data.
     *  @param data to be decoded.
     *  @return decoded data.
     */
    function _decode(bytes calldata data) internal pure override returns (bytes memory) {
        return data.cdDecompress();
    }
}
