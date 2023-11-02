// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {WETH9} from "./interfaces/IWETH9.sol";

import {IERC20hTokenRootFactory as IFactory} from "./interfaces/IERC20hTokenRootFactory.sol";
import {IRootRouter} from "./interfaces/IRootRouter.sol";
import {IRootBridgeAgent as IBridgeAgent, GasParams} from "./interfaces/IRootBridgeAgent.sol";
import {IRootPort as IPort} from "./interfaces/IRootPort.sol";
import {IVirtualAccount, Call} from "./interfaces/IVirtualAccount.sol";

import {DepositParams, DepositMultipleParams} from "./interfaces/IRootBridgeAgent.sol";
import {ERC20hTokenRoot} from "./token/ERC20hTokenRoot.sol";

/**
 * @title  Core Root Router Contract
 * @author MaiaDAO
 * @notice Core Root Router implementation for Root Environment deployment.
 *         This contract is responsible for permissionlessly adding new
 *         tokens or Bridge Agents to the system as well as key governance
 *         enabled system functions (i.e. `toggleBranchBridgeAgentFactory`).
 * @dev    Func IDs for calling these functions through messaging layer:
 *
 *         CROSS-CHAIN MESSAGING FUNCIDs
 *         -----------------------------
 *         FUNC ID      | FUNC NAME
 *         -------------+---------------
 *         0x01         | addGlobalToken
 *         0x02         | addLocalToken
 *         0x03         | setLocalToken
 *         0x04         | syncBranchBridgeAgent
 *
 */
contract CoreRootRouter is IRootRouter, Ownable {
    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    uint16 public immutable rootChainId;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable rootPortAddress;

    /// @notice Bridge Agent to maneg communcations and cross-chain assets.
    address payable public bridgeAgentAddress;

    address public bridgeAgentExecutorAddress;

    /// @notice Uni V3 Factory Address
    address public hTokenFactoryAddress;

    constructor(uint16 _rootChainId, address _wrappedNativeToken, address _rootPortAddress) {
        rootChainId = _rootChainId;
        wrappedNativeToken = WETH9(_wrappedNativeToken);
        rootPortAddress = _rootPortAddress;
        _initializeOwner(msg.sender);
    }

    function initialize(address _bridgeAgentAddress, address _hTokenFactory) external onlyOwner {
        bridgeAgentAddress = payable(_bridgeAgentAddress);
        bridgeAgentExecutorAddress = IBridgeAgent(_bridgeAgentAddress).bridgeAgentExecutorAddress();
        hTokenFactoryAddress = _hTokenFactory;
    }

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add a new Chain (Branch Bridge Agent and respective Router) to a Root Bridge Agent.
     * @param _branchBridgeAgentFactory Address of the branch Bridge Agent Factory.
     * @param _newBranchRouter Address of the new branch router.
     * @param _gasReceiver Address of the excess gas receiver.
     * @param _toChain Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function addBranchToBridgeAgent(
        address _rootBridgeAgent,
        address _branchBridgeAgentFactory,
        address _newBranchRouter,
        address _gasReceiver,
        uint16 _toChain,
        GasParams[2] calldata _gParams
    ) external payable {
        // Check if msg.sender is the Bridge Agent Manager
        if (msg.sender != IPort(rootPortAddress).getBridgeAgentManager(_rootBridgeAgent)) {
            revert UnauthorizedCallerNotManager();
        }

        //Check if valid chain
        if (!IPort(rootPortAddress).isChainId(_toChain)) revert InvalidChainId();

        //Check if chain already added to bridge agent
        if (IBridgeAgent(_rootBridgeAgent).getBranchBridgeAgent(_toChain) != address(0)) revert InvalidChainId();

        //Check if Branch Bridge Agent is allowed by Root Bridge Agent
        if (!IBridgeAgent(_rootBridgeAgent).isBranchBridgeAgentAllowed(_toChain)) revert UnauthorizedChainId();

        //Root Bridge Agent Factory Address
        address rootBridgeAgentFactory = IBridgeAgent(_rootBridgeAgent).factoryAddress();

        //Encode CallData
        bytes memory data = abi.encode(
            _newBranchRouter, _branchBridgeAgentFactory, _rootBridgeAgent, rootBridgeAgentFactory, _gParams[1]
        );

        //Pack funcId into data
        bytes memory packedData = abi.encodePacked(bytes1(0x02), data);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(_gasReceiver, _toChain, packedData, _gParams[0]);
    }

    /**
     * @dev Internal function sync a Root Bridge Agent with a newly created BRanch Bridge Agent.
     *   @param _newBranchBridgeAgent new branch bridge agent address
     *   @param _rootBridgeAgent new branch bridge agent address
     *   @param _fromChain branch chain id.
     *
     */
    function _syncBranchBridgeAgent(address _newBranchBridgeAgent, address _rootBridgeAgent, uint16 _fromChain)
        internal
    {
        IPort(rootPortAddress).syncBranchBridgeAgentWithRoot(_newBranchBridgeAgent, _rootBridgeAgent, _fromChain);
    }

    /*///////////////////////////////////////////////////////////////
                        TOKEN MANAGEMENT FUNCTIONS
    ////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to add a global token to a specific chain. Must be called from a branch.
     *   @param _gasReceiver Address of the excess gas receiver.
     *   @param _globalAddress global token to be added.
     *   @param _toChain chain to which the Global Token will be added.
     *   @param _gParams Gas parameters for remote execution.
     *
     */
    function _addGlobalToken(address _gasReceiver, address _globalAddress, uint16 _toChain, GasParams memory _gParams)
        internal
    {
        if (_toChain == rootChainId) revert InvalidChainId();

        if (!IPort(rootPortAddress).isGlobalAddress(_globalAddress)) {
            revert UnrecognizedGlobalToken();
        }

        //Verify that it does not exist
        if (IPort(rootPortAddress).isGlobalToken(_globalAddress, _toChain)) {
            revert TokenAlreadyAdded();
        }

        //Encode CallData
        bytes memory data = abi.encode(
            _globalAddress,
            ERC20(_globalAddress).name(),
            ERC20(_globalAddress).symbol(),
            ERC20(_globalAddress).decimals(),
            _gParams
        );

        //Pack funcId into data
        bytes memory packedData = abi.encodePacked(bytes1(0x01), data);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(_gasReceiver, _toChain, packedData, _gParams);
    }

    /**
     * @notice Function to add a new local to the global environment. Called from branch chain.
     *   @param _underlyingAddress the token's underlying/native chain address.
     *   @param _localAddress the token's address.
     *   @param _name the token's name.
     *   @param _symbol the token's symbol.
     *   @param _decimals the token's decimals.
     *   @param _fromChain the token's origin chain Id.
     *
     */
    function _addLocalToken(
        address _underlyingAddress,
        address _localAddress,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint16 _fromChain
    ) internal {
        // Verify if underlying address is already known by branch or root chain
        if (
            IPort(rootPortAddress).isGlobalAddress(_underlyingAddress)
                || IPort(rootPortAddress).isLocalToken(_underlyingAddress, _fromChain)
                || IPort(rootPortAddress).isUnderlyingToken(_underlyingAddress, _fromChain)
        ) revert TokenAlreadyAdded();

        //Create new global token
        address newToken = address(IFactory(hTokenFactoryAddress).createToken(_name, _symbol, _decimals));

        //Update Registry
        IPort(rootPortAddress).setAddresses(
            newToken, (_fromChain == rootChainId) ? newToken : _localAddress, _underlyingAddress, _fromChain
        );
    }

    /**
     * @notice Internal function to set the local token on a specific chain for a global token.
     *   @param _globalAddress global token to be updated.
     *   @param _localAddress local token to be added.
     *   @param _toChain local token's chain.
     *
     */
    function _setLocalToken(address _globalAddress, address _localAddress, uint16 _toChain) internal {
        // Verify if token already added
        if (IPort(rootPortAddress).isLocalToken(_localAddress, _toChain)) revert TokenAlreadyAdded();

        // Set global token's new branch chain address
        IPort(rootPortAddress).setLocalAddress(_globalAddress, _localAddress, _toChain);
    }

    /*///////////////////////////////////////////////////////////////
                    GOVERNANCE / ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or Remove a Branch Bridge Agent Factory.
     * @param _rootBridgeAgentFactory Address of the root Bridge Agent Factory.
     * @param _branchBridgeAgentFactory Address of the branch Bridge Agent Factory.
     * @param _gasReceiver Receiver of any leftover execution gas upon reaching destination network.
     * @param _toChain Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function toggleBranchBridgeAgentFactory(
        address _rootBridgeAgentFactory,
        address _branchBridgeAgentFactory,
        address _gasReceiver,
        uint16 _toChain,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        if (!IPort(rootPortAddress).isBridgeAgentFactory(_rootBridgeAgentFactory)) {
            revert UnrecognizedBridgeAgentFactory();
        }

        //Encode CallData
        bytes memory data = abi.encode(_branchBridgeAgentFactory);

        //Pack funcId into data
        bytes memory packedData = abi.encodePacked(bytes1(0x03), data);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(_gasReceiver, _toChain, packedData, _gParams);
    }

    /**
     * @notice Remove a Branch Bridge Agent.
     * @param _branchBridgeAgent Address of the Branch Bridge Agent to be updated.
     * @param _gasReceiver Receiver of any leftover execution gas upon reaching destination network.
     * @param _toChain Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function removeBranchBridgeAgent(
        address _branchBridgeAgent,
        address _gasReceiver,
        uint16 _toChain,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        //Encode CallData
        bytes memory data = abi.encode(_branchBridgeAgent);

        //Pack funcId into data
        bytes memory packedData = abi.encodePacked(bytes1(0x04), data);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(_gasReceiver, _toChain, packedData, _gParams);
    }

    /**
     * @notice Add or Remove a Strategy Token.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _minimumReservesRatio Minimum Branch Port reserves ratio for the underlying token.
     * @param _gasReceiver Receiver of any leftover execution gas upon reaching destination network.
     * @param _toChain Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function manageStrategyToken(
        address _underlyingToken,
        uint256 _minimumReservesRatio,
        address _gasReceiver,
        uint16 _toChain,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        //Encode CallData
        bytes memory data = abi.encode(_underlyingToken, _minimumReservesRatio);

        //Pack funcId into data
        bytes memory packedData = abi.encodePacked(bytes1(0x05), data);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(_gasReceiver, _toChain, packedData, _gParams);
    }

    /**
     * @notice Add, Remove or update a Port Strategy.
     * @param _portStrategy Address of the Port Strategy to be added for use in Branch strategies.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _dailyManagementLimit Daily management limit of the given token for the Port Strategy.
     * @param _isUpdateDailyLimit Boolean to safely indicate if the Port Strategy is being updated and not deactivated.
     * @param _gasReceiver Receiver of any leftover execution gas upon reaching destination network.
     * @param _toChain Chain Id of the branch chain where the new Bridge Agent will be deployed.
     * @param _gParams Gas parameters for remote execution.
     */
    function managePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        bool _isUpdateDailyLimit,
        address _gasReceiver,
        uint16 _toChain,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        //Encode CallData
        bytes memory data = abi.encode(_portStrategy, _underlyingToken, _dailyManagementLimit, _isUpdateDailyLimit);

        //Pack funcId into data
        bytes memory packedData = abi.encodePacked(bytes1(0x06), data);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(_gasReceiver, _toChain, packedData, _gParams);
    }

    /*///////////////////////////////////////////////////////////////
                        ANYCALL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootRouter
    function executeResponse(bytes1 _funcId, bytes calldata _encodedData, uint16 _fromChainId)
        external
        payable
        override
        requiresExecutor
    {
        ///  FUNC ID: 2 (_addLocalToken)
        if (_funcId == 0x02) {
            (address underlyingAddress, address localAddress, string memory name, string memory symbol, uint8 decimals)
            = abi.decode(_encodedData, (address, address, string, string, uint8));

            _addLocalToken(underlyingAddress, localAddress, name, symbol, decimals, _fromChainId);

            /// FUNC ID: 3 (_setLocalToken)
        } else if (_funcId == 0x03) {
            (address globalAddress, address localAddress) = abi.decode(_encodedData, (address, address));

            _setLocalToken(globalAddress, localAddress, _fromChainId);

            /// FUNC ID: 4 (_syncBranchBridgeAgent)
        } else if (_funcId == 0x04) {
            (address newBranchBridgeAgent, address rootBridgeAgent) = abi.decode(_encodedData, (address, address));

            _syncBranchBridgeAgent(newBranchBridgeAgent, rootBridgeAgent, _fromChainId);

            /// Unrecognized Function Selector
        } else {
            revert UnrecognizedFunctionId();
        }
    }

    /// @inheritdoc IRootRouter
    function execute(bytes1 _funcId, bytes calldata _encodedData, uint16) external payable override requiresExecutor {
        /// FUNC ID: 1 (_addGlobalToken)
        if (_funcId == 0x01) {
            (address gasReceiver, address globalAddress, uint16 toChain, GasParams memory gasParams) =
                abi.decode(_encodedData, (address, address, uint16, GasParams));

            _addGlobalToken(gasReceiver, globalAddress, toChain, gasParams);

            /// Unrecognized Function Selector
        } else {
            revert UnrecognizedFunctionId();
        }
    }

    /// @inheritdoc IRootRouter
    function executeDepositSingle(bytes1, bytes memory, DepositParams memory, uint16)
        external
        payable
        override
        requiresExecutor
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeDepositMultiple(bytes1, bytes calldata, DepositMultipleParams memory, uint16)
        external
        payable
        requiresExecutor
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeSigned(bytes1, bytes memory, address, uint16) external payable override requiresExecutor {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeSignedDepositSingle(bytes1, bytes memory, DepositParams memory, address, uint16)
        external
        payable
        override
        requiresExecutor
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeSignedDepositMultiple(bytes1, bytes memory, DepositMultipleParams memory, address, uint16)
        external
        payable
        requiresExecutor
    {
        revert();
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    uint256 internal _unlocked = 1;

    /// @notice Modifier for a simple re-entrancy check.
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /// @notice Modifier verifies the caller is the Bridge Agent Executor.
    modifier requiresExecutor() {
        _requiresExecutor();
        _;
    }

    /// @notice Internal function verifies the caller is the Bridge Agent Executor. Reuse to reduce contract bytesize
    function _requiresExecutor() internal view {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedBridgeAgentExecutor();
    }

    /*///////////////////////////////////////////////////////////////
                                ERROR
    ///////////////////////////////////////////////////////////////*/

    error InvalidChainId();

    error UnauthorizedChainId();

    error UnauthorizedCallerNotManager();

    error TokenAlreadyAdded();

    error UnrecognizedGlobalToken();

    error UnrecognizedBridgeAgentFactory();
}
