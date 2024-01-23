// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {IArbitrumBranchPort} from "./interfaces/IArbitrumBranchPort.sol";
import {IRootPort} from "./interfaces/IRootPort.sol";

import {AddressCodeSize} from "./lib/AddressCodeSize.sol";

import {BranchPort} from "./BranchPort.sol";

/// @title Arbitrum Branch Port Contract
/// @author MaiaDAO
contract ArbitrumBranchPort is BranchPort, IArbitrumBranchPort {
    using SafeTransferLib for address;
    using AddressCodeSize for address;

    /*///////////////////////////////////////////////////////////////
                    ARBITRUM BRANCH PORT STATE
    ///////////////////////////////////////////////////////////////*/

    /// @notice Local Network Identifier.
    uint16 public immutable override rootChainId;

    /// @notice Address for Root Port Address
    address public immutable override rootPortAddress;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for Arbitrum Branch Port.
     * @param _rootChainId arbitrum layer zero chain id.
     * @param _rootPortAddress address of the Root Port.
     * @param _owner owner of the contract.
     */
    constructor(uint16 _rootChainId, address _rootPortAddress, address _owner) BranchPort(_owner) {
        require(_rootPortAddress != address(0), "Root Port Address cannot be 0");

        rootChainId = _rootChainId;
        rootPortAddress = _rootPortAddress;
    }

    /*///////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    ///@inheritdoc IArbitrumBranchPort
    function depositToPort(address _depositor, address _recipient, address _underlyingAddress, uint256 _deposit)
        external
        override
        nonReentrant
        requiresBridgeAgent
    {
        // Save root port address to memory
        address _rootPortAddress = rootPortAddress;

        // Get global token address from root port
        address _globalToken = IRootPort(_rootPortAddress).getLocalTokenFromUnderlying(_underlyingAddress, rootChainId);

        // Check if the global token exists
        if (_globalToken == address(0)) revert UnknownGlobalToken();

        // Check if underlying address is a contract
        if (_underlyingAddress.isEOA()) revert InvalidUnderlyingAddress();
        // Deposit Assets to Port
        _underlyingAddress.safeTransferFrom(_depositor, address(this), _deposit);

        // Request Minting of Global Token
        IRootPort(_rootPortAddress).mintToLocalBranch(_recipient, _globalToken, _deposit);
    }

    ///@inheritdoc IArbitrumBranchPort
    function withdrawFromPort(address _depositor, address _recipient, address _globalAddress, uint256 _amount)
        external
        override
        nonReentrant
        requiresBridgeAgent
    {
        // Save root port address to memory
        address _rootPortAddress = rootPortAddress;

        // Check if the global token exists
        if (!IRootPort(_rootPortAddress).isGlobalToken(_globalAddress, rootChainId)) revert UnknownGlobalToken();

        // Get the underlying token address from the root port
        address _underlyingAddress =
            IRootPort(_rootPortAddress).getUnderlyingTokenFromLocal(_globalAddress, rootChainId);

        // Check if the underlying token exists
        if (_underlyingAddress == address(0)) revert UnknownUnderlyingToken();

        // Burn deposited hTokens
        IRootPort(_rootPortAddress).burnFromLocalBranch(_depositor, _globalAddress, _amount);

        // Transfer underlying tokens to recipient
        _underlyingAddress.safeTransfer(_recipient, _amount);
    }

    /*///////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to bridge in assets from the Root Chain.
     * @param _recipient recipient of the bridged assets.
     * @param _localAddress address of the local token.
     * @param _amount amount of the bridged assets.
     */
    function _bridgeIn(address _recipient, address _localAddress, uint256 _amount) internal override {
        IRootPort(rootPortAddress).bridgeToLocalBranchFromRoot(_recipient, _localAddress, _amount);
    }

    /**
     * @notice Internal function to bridge out assets to the Root Chain.
     * @param _depositor depositor of the bridged assets.
     * @param _localAddress address of the local token.
     * @param _underlyingAddress address of the underlying token.
     * @param _amount amount of the bridged assets.
     * @param _deposit amount of the underlying assets to be deposited.
     */
    function _bridgeOut(
        address _depositor,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit
    ) internal override {
        // Burn hTokens if any are being used
        if (_amount - _deposit > 0) {
            unchecked {
                IRootPort(rootPortAddress).bridgeToRootFromLocalBranch(_depositor, _localAddress, _amount - _deposit);
            }
        }

        // Store Underlying Tokens
        if (_deposit > 0) {
            // Check if underlying address is a contract
            if (_underlyingAddress.isEOA()) revert InvalidUnderlyingAddress();

            _underlyingAddress.safeTransferFrom(_depositor, address(this), _deposit);
        }
    }
}
