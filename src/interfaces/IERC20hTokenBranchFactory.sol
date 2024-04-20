// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20hToken} from "../token/ERC20hToken.sol";

/**
 * @title  ERC20hTokenBranchFactory Contract
 * @author MaiaDAO
 * @notice Factory contract allowing for permissionless deployment of new Branch hTokens in Branch
 *  	   Chains of Ulysses Omnichain Liquidity Protocol.
 * @dev    This contract is called by the chain's Core Branch Router.
 */
interface IERC20hTokenBranchFactory {
    /*///////////////////////////////////////////////////////////////
                            hTOKEN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to create a new Branch hToken.
     * @param _name Name of the Token.
     * @param _symbol Symbol of the Token.
     * @param _decimals Decimals of the Token.
     */
    function createToken(string memory _name, string memory _symbol, uint8 _decimals)
        external
        returns (ERC20hToken newToken);

    /*///////////////////////////////////////////////////////////////
                                ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when caller is not the Core Branch Router.
    error UnrecognizedCoreRouter();

    /// @notice Error emitted when the Port Address is the zero address.
    error UnrecognizedPort();
}
