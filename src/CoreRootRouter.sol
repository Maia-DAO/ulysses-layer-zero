// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/auth/Ownable.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {IERC20hTokenRootFactory as IFactory} from "./interfaces/IERC20hTokenRootFactory.sol";
import {ICoreRootRouter, IRootRouter} from "./interfaces/ICoreRootRouter.sol";
import {
    DepositParams,
    DepositMultipleParams,
    GasParams,
    IRootBridgeAgent as IBridgeAgent
} from "./interfaces/IRootBridgeAgent.sol";
import {IRootPort as IPort} from "./interfaces/IRootPort.sol";

import {ReservesRatio} from "./lib/ReservesRatio.sol";

/// @title  Core Root Router Contract
/// @author Maia DAO
contract CoreRootRouter is ICoreRootRouter, Ownable {
    /*///////////////////////////////////////////////////////////////
                    CORE ROOT ROUTER STATE
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICoreRootRouter
    uint256 public immutable override rootChainId;

    /// @inheritdoc ICoreRootRouter
    address public immutable override rootPortAddress;

    /// @inheritdoc ICoreRootRouter
    address payable public override bridgeAgentAddress;

    /// @inheritdoc ICoreRootRouter
    address public override bridgeAgentExecutorAddress;

    /// @inheritdoc ICoreRootRouter
    address public override hTokenFactoryAddress;

    /// @notice Boolean to indicate if the contract is in set up mode.
    bool internal _setup;

    /*///////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for Core Root Router.
     * @param _rootChainId layer zero root chain id.
     * @param _rootPortAddress address of the Root Port.
     */
    constructor(uint256 _rootChainId, address _rootPortAddress) {
        rootChainId = _rootChainId;
        rootPortAddress = _rootPortAddress;

        _initializeOwner(msg.sender);
        _setup = true;
    }

    /*///////////////////////////////////////////////////////////////
                    INITIALIZATION FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    function initialize(address _bridgeAgentAddress, address _hTokenFactory) external onlyOwner {
        require(_setup, "Contract is already initialized");
        _setup = false;
        bridgeAgentAddress = payable(_bridgeAgentAddress);
        bridgeAgentExecutorAddress = IBridgeAgent(_bridgeAgentAddress).bridgeAgentExecutorAddress();
        hTokenFactoryAddress = _hTokenFactory;
    }

    /*///////////////////////////////////////////////////////////////
                    BRIDGE AGENT MANAGEMENT FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICoreRootRouter
    function addBranchToBridgeAgent(
        address _rootBridgeAgent,
        address _branchBridgeAgentFactory,
        address _newBranchRouter,
        address _refundee,
        uint16 _dstChainId,
        GasParams[2] calldata _gParams
    ) external payable {
        // Check if msg.sender is the Bridge Agent Manager
        if (msg.sender != IPort(rootPortAddress).getBridgeAgentManager(_rootBridgeAgent)) {
            revert UnauthorizedCallerNotManager();
        }

        // Check if valid chain
        if (!IPort(rootPortAddress).isChainId(_dstChainId)) revert InvalidChainId();

        // Check if chain already added to bridge agent
        if (IBridgeAgent(_rootBridgeAgent).getBranchBridgeAgent(_dstChainId) != address(0)) revert InvalidChainId();

        // Check if Branch Bridge Agent is allowed by Root Bridge Agent
        if (!IBridgeAgent(_rootBridgeAgent).isBranchBridgeAgentAllowed(_dstChainId)) revert UnauthorizedChainId();

        // Encode CallData
        bytes memory params = abi.encode(
            _newBranchRouter,
            _branchBridgeAgentFactory,
            _rootBridgeAgent,
            IBridgeAgent(_rootBridgeAgent).factoryAddress(),
            _refundee,
            _gParams[1]
        );

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x02), params);

        // Add new branch to bridge agent
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams[0]
        );
    }

    /*///////////////////////////////////////////////////////////////
                GOVERNANCE / ADMIN EXTERNAL FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICoreRootRouter
    function toggleBranchBridgeAgentFactory(
        address _rootBridgeAgentFactory,
        address _branchBridgeAgentFactory,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        if (!IPort(rootPortAddress).isBridgeAgentFactory(_rootBridgeAgentFactory)) {
            revert UnrecognizedBridgeAgentFactory();
        }

        // Encode CallData
        bytes memory params = abi.encode(_branchBridgeAgentFactory);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x03), params);

        // Update branch bridge agent factory
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc ICoreRootRouter
    function toggleStrategyToken(
        address _underlyingToken,
        uint256 _minimumReservesRatio,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        ReservesRatio.checkReserveRatioLimit(_minimumReservesRatio);

        // Encode CallData
        bytes memory params = abi.encode(_underlyingToken, _minimumReservesRatio);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x04), params);

        // Update strategy token
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc ICoreRootRouter
    function updateStrategyToken(
        address _underlyingToken,
        uint256 _minimumReservesRatio,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        ReservesRatio.checkReserveRatioLimit(_minimumReservesRatio);

        // Encode CallData
        bytes memory params = abi.encode(_underlyingToken, _minimumReservesRatio);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x05), params);

        // Update strategy token
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc ICoreRootRouter
    function togglePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        ReservesRatio.checkReserveRatioLimit(_reserveRatioManagementLimit);

        // Encode CallData
        bytes memory params =
            abi.encode(_portStrategy, _underlyingToken, _dailyManagementLimit, _reserveRatioManagementLimit);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x06), params);

        // Update port strategy
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc ICoreRootRouter
    function updatePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit,
        address _refundee,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable onlyOwner {
        ReservesRatio.checkReserveRatioLimit(_reserveRatioManagementLimit);

        // Encode CallData
        bytes memory params =
            abi.encode(_portStrategy, _underlyingToken, _dailyManagementLimit, _reserveRatioManagementLimit);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x07), params);

        // Update port strategy
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc ICoreRootRouter
    function setCoreBranch(
        address _refundee,
        address _coreBranchRouter,
        address _coreBranchBridgeAgent,
        uint16 _dstChainId,
        GasParams calldata _gParams
    ) external payable {
        // Check caller is root port
        require(msg.sender == rootPortAddress, "Only root port can call");

        // Encode CallData
        bytes memory params = abi.encode(_coreBranchRouter, _coreBranchBridgeAgent);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x08), params);

        // Set Core Branch Router and Bridge Agent
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc ICoreRootRouter
    function sweep(address _refundee, address _recipient, uint16 _dstChainId, GasParams calldata _gParams)
        external
        payable
        onlyOwner
    {
        // Encode CallData
        bytes memory params = abi.encode(_recipient);

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x09), params);

        // Sweep native tokens from branch port
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _recipient, _dstChainId, payload, _gParams
        );
    }

    /// @inheritdoc IRootRouter
    function retrySettlement(uint32, address, bytes calldata, GasParams calldata, bool) external payable override {
        revert();
    }

    /*///////////////////////////////////////////////////////////////
                        LAYERZERO FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootRouter
    function executeRetrySettlement(address, uint32, address, bytes calldata, GasParams calldata, bool, uint16)
        public
        payable
        override
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function execute(bytes calldata _encodedData, uint16 _srcChainId) external payable override requiresExecutor {
        // Parse funcId
        bytes1 funcId = _encodedData[0];

        /// FUNC ID: 1 (_addGlobalToken)
        if (funcId == 0x01) {
            (address refundee, address globalAddress, uint16 dstChainId, GasParams[2] memory gasParams) =
                abi.decode(_encodedData[1:], (address, address, uint16, GasParams[2]));

            _addGlobalToken(refundee, globalAddress, dstChainId, gasParams);

            ///  FUNC ID: 2 (_addLocalToken)
        } else if (funcId == 0x02) {
            (address underlyingAddress, address localAddress, string memory name, string memory symbol, uint8 decimals)
            = abi.decode(_encodedData[1:], (address, address, string, string, uint8));

            _addLocalToken(underlyingAddress, localAddress, name, symbol, decimals, _srcChainId);

            /// FUNC ID: 3 (_setLocalToken)
        } else if (funcId == 0x03) {
            (address globalAddress, address localAddress) = abi.decode(_encodedData[1:], (address, address));

            _setLocalToken(globalAddress, localAddress, _srcChainId);

            /// FUNC ID: 4 (_syncBranchBridgeAgent)
        } else if (funcId == 0x04) {
            (address newBranchBridgeAgent, address rootBridgeAgent) = abi.decode(_encodedData[1:], (address, address));

            _syncBranchBridgeAgent(newBranchBridgeAgent, rootBridgeAgent, _srcChainId);

            /// Unrecognized Function Selector
        } else {
            revert UnrecognizedFunctionId();
        }
    }

    /// @inheritdoc IRootRouter
    function executeDepositSingle(bytes memory, DepositParams memory, uint16) external payable override {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeDepositMultiple(bytes calldata, DepositMultipleParams memory, uint16) external payable override {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeSigned(bytes memory, address, uint16) external payable override {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeSignedDepositSingle(bytes memory, DepositParams memory, address, uint16)
        external
        payable
        override
    {
        revert();
    }

    /// @inheritdoc IRootRouter
    function executeSignedDepositMultiple(bytes memory, DepositMultipleParams memory, address, uint16)
        external
        payable
        override
    {
        revert();
    }

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to add a new local to the global environment. Called from branch chain.
     *   @param _underlyingAddress the token's underlying/native chain address.
     *   @param _localAddress the token's address.
     *   @param _name the token's name.
     *   @param _symbol the token's symbol.
     *   @param _decimals the token's decimals.
     *   @param _srcChainId the token's origin chain Id.
     *
     */
    function _addLocalToken(
        address _underlyingAddress,
        address _localAddress,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint16 _srcChainId
    ) internal {
        // Verify if the underlying address is already known by the branch or root chain
        if (IPort(rootPortAddress).isGlobalAddress(_underlyingAddress)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isLocalToken(_underlyingAddress, _srcChainId)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isUnderlyingToken(_underlyingAddress, _srcChainId)) revert TokenAlreadyAdded();

        // Verify if the local address is already known by the branch or root chain
        if (IPort(rootPortAddress).isGlobalAddress(_localAddress)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isLocalToken(_localAddress, _srcChainId)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isUnderlyingToken(_localAddress, _srcChainId)) revert TokenAlreadyAdded();

        //Create a new global token
        address newToken = address(IFactory(hTokenFactoryAddress).createToken(_name, _symbol, _decimals));

        // Update Registry
        IPort(rootPortAddress).setAddresses(
            newToken, (_srcChainId == rootChainId) ? newToken : _localAddress, _underlyingAddress, _srcChainId
        );
    }

    /**
     * @notice Internal function to add a global token to a specific chain. Must be called from a branch.
     *   @param _refundee Address of the excess gas receiver.
     *   @param _globalAddress global token to be added.
     *   @param _dstChainId chain to which the Global Token will be added.
     *   @param _gParams Gas parameters for remote execution.
     *
     */
    function _addGlobalToken(
        address _refundee,
        address _globalAddress,
        uint16 _dstChainId,
        GasParams[2] memory _gParams
    ) internal {
        if (_dstChainId == rootChainId) revert InvalidChainId();

        if (!IPort(rootPortAddress).isGlobalAddress(_globalAddress)) {
            revert UnrecognizedGlobalToken();
        }

        // Verify that it does not exist
        if (IPort(rootPortAddress).isGlobalToken(_globalAddress, _dstChainId)) {
            revert TokenAlreadyAdded();
        }

        // Encode CallData
        bytes memory params = abi.encode(
            _globalAddress,
            ERC20(_globalAddress).name(),
            ERC20(_globalAddress).symbol(),
            ERC20(_globalAddress).decimals(),
            _refundee,
            _gParams[1]
        );

        // Pack funcId into data
        bytes memory payload = abi.encodePacked(bytes1(0x01), params);

        //Add new global token to branch chain
        IBridgeAgent(bridgeAgentAddress).callOut{value: msg.value}(
            payable(_refundee), _refundee, _dstChainId, payload, _gParams[0]
        );
    }

    /**
     * @notice Internal function to set the local token on a specific chain for a global token.
     *   @param _globalAddress global token to be updated.
     *   @param _localAddress local token to be added.
     *   @param _dstChainId local token's chain.
     */
    function _setLocalToken(address _globalAddress, address _localAddress, uint16 _dstChainId) internal {
        // Verify if this is a global token
        if (!IPort(rootPortAddress).isGlobalAddress(_globalAddress)) revert UnrecognizedGlobalToken();

        // Verify if the global address is already known by the branch or root chain
        if (IPort(rootPortAddress).isGlobalToken(_globalAddress, _dstChainId)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isLocalToken(_globalAddress, _dstChainId)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isUnderlyingToken(_globalAddress, _dstChainId)) revert TokenAlreadyAdded();

        // Verify if the local address is already known by the branch or root chain
        if (IPort(rootPortAddress).isGlobalAddress(_localAddress)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isLocalToken(_localAddress, _dstChainId)) revert TokenAlreadyAdded();
        if (IPort(rootPortAddress).isUnderlyingToken(_localAddress, _dstChainId)) revert TokenAlreadyAdded();

        // Set the global token's new branch chain address
        IPort(rootPortAddress).setLocalAddress(_globalAddress, _localAddress, _dstChainId);
    }

    /*///////////////////////////////////////////////////////////////
                BRIDGE AGENT MANAGEMENT INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function sync a Root Bridge Agent with a newly created BRanch Bridge Agent.
     *   @param _newBranchBridgeAgent new branch bridge agent address
     *   @param _rootBridgeAgent new branch bridge agent address
     *   @param _srcChainId branch chain id.
     */
    function _syncBranchBridgeAgent(address _newBranchBridgeAgent, address _rootBridgeAgent, uint256 _srcChainId)
        internal
    {
        IPort(rootPortAddress).syncBranchBridgeAgentWithRoot(_newBranchBridgeAgent, _rootBridgeAgent, _srcChainId);
    }

    /*///////////////////////////////////////////////////////////////
                             MODIFIERS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Modifier verifies the caller is the Bridge Agent Executor.
    modifier requiresExecutor() {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedBridgeAgentExecutor();
        _;
    }
}
