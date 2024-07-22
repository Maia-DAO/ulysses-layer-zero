// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {LibZip} from "solady/utils/LibZip.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {IVirtualAccount, Call, PayableCall} from "./interfaces/IVirtualAccount.sol";
import {IRootPort} from "./interfaces/IRootPort.sol";

import {AddressCodeSize} from "./lib/AddressCodeSize.sol";

/// @title VirtualAccount - Contract for managing a virtual user account on the Root Chain
contract VirtualAccount is IVirtualAccount, ERC1155Receiver {
    using SafeTransferLib for address;
    using AddressCodeSize for address;

    /// @inheritdoc IVirtualAccount
    address public immutable override userAddress;

    /// @inheritdoc IVirtualAccount
    address public immutable override localPortAddress;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for Virtual Account.
     * @param _userAddress Address of the user/owner.
     */
    constructor(address _userAddress) {
        localPortAddress = msg.sender;
        userAddress = _userAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    fallback() external payable {
        LibZip.cdFallback();
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVirtualAccount
    function withdrawNative(uint256 _amount) external override requiresApprovedCaller {
        msg.sender.safeTransferETH(_amount);
    }

    /// @inheritdoc IVirtualAccount
    function withdrawERC20(address _token, uint256 _amount) external override requiresApprovedCaller {
        _token.safeTransfer(msg.sender, _amount);
    }

    /// @inheritdoc IVirtualAccount
    function withdrawERC721(address _token, uint256 _tokenId) external override requiresApprovedCaller {
        ERC721(_token).transferFrom(address(this), msg.sender, _tokenId);
    }

    /// @inheritdoc IVirtualAccount
    function call(Call[] calldata calls) external override requiresApprovedCaller returns (bytes[] memory returnData) {
        uint256 length = calls.length;
        returnData = new bytes[](length);

        for (uint256 i = 0; i < length;) {
            bool success;
            Call calldata _call = calls[i];

            if (_call.target.isContract()) (success, returnData[i]) = _call.target.call(_call.callData);

            if (!success) revert CallFailed(returnData[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IVirtualAccount
    function payableCall(PayableCall[] calldata calls)
        public
        payable
        override
        requiresApprovedCaller
        returns (bytes[] memory returnData)
    {
        uint256 valAccumulator;
        uint256 length = calls.length;
        returnData = new bytes[](length);
        PayableCall calldata _call;
        for (uint256 i = 0; i < length;) {
            _call = calls[i];
            uint256 val = _call.value;
            // Humanity will be a Type V Kardashev Civilization before this overflows - andreas
            // ~ 10^25 Wei in existence << ~ 10^76 size uint fits in a uint256
            unchecked {
                valAccumulator += val;
            }

            bool success;

            if (_call.target.isContract()) (success, returnData[i]) = _call.target.call{value: val}(_call.callData);

            if (!success) revert CallFailed(returnData[i]);

            unchecked {
                ++i;
            }
        }

        // Finally, make sure the msg.value = SUM(call[0...i].value)
        if (msg.value != valAccumulator) revert EtherValueMismatch();
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL HOOKS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    /*///////////////////////////////////////////////////////////////
                                MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Modifier that verifies msg sender is the approved to use the virtual account. Either the owner or an approved router.
    modifier requiresApprovedCaller() {
        if (msg.sender != userAddress) {
            if (!IRootPort(localPortAddress).isRouterApproved(this, msg.sender)) {
                revert UnauthorizedCaller();
            }
        }
        _;
    }
}
