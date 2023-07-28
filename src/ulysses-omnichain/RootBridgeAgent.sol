// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

import {Ownable} from "solady/auth/Ownable.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ExcessivelySafeCall} from "lib/ExcessivelySafeCall.sol";

import {WETH9} from "./interfaces/IWETH9.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

import {ILayerZeroEndpoint} from "./interfaces/ILayerZeroEndpoint.sol";

import {AnycallFlags} from "./lib/AnycallFlags.sol";

import {IAnycallProxy} from "./interfaces/IAnycallProxy.sol";
import {IAnycallConfig} from "./interfaces/IAnycallConfig.sol";
import {IAnycallExecutor} from "./interfaces/IAnycallExecutor.sol";

import {ILayerZeroReceiver, IRootBridgeAgent} from "./interfaces/IRootBridgeAgent.sol";
import {IBranchBridgeAgent} from "./interfaces/IBranchBridgeAgent.sol";
import {IERC20hTokenRoot} from "./interfaces/IERC20hTokenRoot.sol";
import {IRootPort as IPort} from "./interfaces/IRootPort.sol";
import {IRootRouter as IRouter} from "./interfaces/IRootRouter.sol";

import {VirtualAccount} from "./VirtualAccount.sol";
import {
    IRootBridgeAgent,
    GasParams,
    DepositParams,
    DepositMultipleParams,
    Settlement,
    SettlementInput,
    SettlementMultipleInput,
    SettlementStatus,
    SettlementParams,
    SettlementMultipleParams
} from "./interfaces/IRootBridgeAgent.sol";

import {DeployRootBridgeAgentExecutor, RootBridgeAgentExecutor} from "./RootBridgeAgentExecutor.sol";

/// @title Library for Cross Chain Deposit Parameters Validation.
library CheckParamsLib {
    /**
     * @notice Function to check cross-chain deposit parameters and verify deposits made on branch chain are valid.
     * @param _localPortAddress Address of local Port.
     * @param _dParams Cross Chain swap parameters.
     * @param _fromChain Chain ID of the chain where the deposit was made.
     * @dev Local hToken must be recognized and address must match underlying if exists otherwise only local hToken is checked.
     *
     */
    function checkParams(address _localPortAddress, DepositParams memory _dParams, uint16 _fromChain)
        internal
        view
        returns (bool)
    {
        if (
            (_dParams.amount < _dParams.deposit) //Deposit can't be greater than amount.
                || (_dParams.amount > 0 && !IPort(_localPortAddress).isLocalToken(_dParams.hToken, _fromChain)) //Check local exists.
                || (_dParams.deposit > 0 && !IPort(_localPortAddress).isUnderlyingToken(_dParams.token, _fromChain)) //Check underlying exists.
        ) {
            return false;
        }
        return true;
    }
}

/// @title Library for Root Bridge Agent Deployment.
library DeployRootBridgeAgent {
    function deploy(
        WETH9 _wrappedNativeToken,
        uint16 _localChainId,
        address _daoAddress,
        address _lzEndpointAddress,
        address _localPortAddress,
        address _localRouterAddress
    ) external returns (RootBridgeAgent) {
        return new RootBridgeAgent(
            _wrappedNativeToken,
            _localChainId,
            _daoAddress,
            _lzEndpointAddress,
            _localPortAddress,
            _localRouterAddress
        );
    }
}

/// @title  Root Bridge Agent Contract
contract RootBridgeAgent is IRootBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using ExcessivelySafeCall for address;

    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// AnyExec Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_ADDRESS_SIZE = 20;

    /// BridgeIn Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    /*///////////////////////////////////////////////////////////////
                        ROOT BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Local Chain Id
    uint16 public immutable localChainId;

    /// @notice Local Wrapped Native Token
    WETH9 public immutable wrappedNativeToken;

    /// @notice Bridge Agent Factory Address.
    address public immutable factoryAddress;

    /// @notice Address of DAO.
    address public immutable daoAddress;

    /// @notice Local Core Root Router Address
    address public immutable localRouterAddress;

    /// @notice Local Port Address where funds deposited from this chain are stored.
    address public immutable localPortAddress;

    /// @notice Local Layer Zero Endpoint Address for cross-chain communication.
    address public immutable lzEndpointAddress;

    /// @notice Address of Root Bridge Agent Executor.
    address public immutable bridgeAgentExecutorAddress;

    /*///////////////////////////////////////////////////////////////
                    BRANCH BRIDGE AGENTS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain -> Branch Bridge Agent Address. For N chains, each Root Bridge Agent Address has M =< N Branch Bridge Agent Address.
    mapping(uint256 => address) public getBranchBridgeAgent;

    /// @notice Message Path for each connected Branch Bridge Agent as bytes for Layzer Zero interaction = localAddress + destinationAddress abi.encodePacked()
    mapping(uint256 => bytes) public getBranchBridgeAgentPath;

    /// @notice If true, bridge agent manager has allowed for a new given branch bridge agent to be synced/added.
    mapping(uint256 => bool) public isBranchBridgeAgentAllowed;

    /*///////////////////////////////////////////////////////////////
                        SETTLEMENTS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit nonce used for identifying transaction.
    uint32 public settlementNonce;

    /// @notice Mapping from Settlement nonce to Deposit Struct.
    mapping(uint32 => Settlement) public getSettlement;

    /*///////////////////////////////////////////////////////////////
                            EXECUTOR STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice If true, bridge agent has already served a request with this nonce from  a given chain. Chain -> Nonce -> Bool
    mapping(uint256 => mapping(uint32 => bool)) public executionHistory;

    /*///////////////////////////////////////////////////////////////
                        GAS MANAGEMENT CONST
    //////////////////////////////////////////////////////////////*/

    uint24 public constant MIN_EXECUTION_GAS = 200_000;

    /*///////////////////////////////////////////////////////////////
                        DAO STATE
    //////////////////////////////////////////////////////////////*/

    uint256 public accumulatedFees;

    /**
     * @notice Constructor for Bridge Agent.
     *     @param _wrappedNativeToken Local Wrapped Native Token.
     *     @param _daoAddress Address of DAO.
     *     @param _localChainId Local Chain Id.
     *     @param _lzEndpointAddress Local Anycall Address.
     *     @param _localPortAddress Local Port Address.
     *     @param _localRouterAddress Local Port Address.
     */
    constructor(
        WETH9 _wrappedNativeToken,
        uint16 _localChainId,
        address _daoAddress,
        address _lzEndpointAddress,
        address _localPortAddress,
        address _localRouterAddress
    ) {
        require(address(_wrappedNativeToken) != address(0), "Wrapped native token cannot be zero address");
        require(_daoAddress != address(0), "DAO cannot be zero address");
        require(_lzEndpointAddress != address(0), "Anycall Address cannot be zero address");
        require(_lzEndpointAddress != address(0), "Anycall Executor Address cannot be zero address");
        require(_localPortAddress != address(0), "Port Address cannot be zero address");
        require(_localRouterAddress != address(0), "Router Address cannot be zero address");

        wrappedNativeToken = _wrappedNativeToken;
        factoryAddress = msg.sender;
        daoAddress = _daoAddress;
        localChainId = _localChainId;
        lzEndpointAddress = _lzEndpointAddress;
        localPortAddress = _localPortAddress;
        localRouterAddress = _localRouterAddress;
        bridgeAgentExecutorAddress = DeployRootBridgeAgentExecutor.deploy(address(this));
        settlementNonce = 1;
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function getSettlementEntry(uint32 _settlementNonce) external view returns (Settlement memory) {
        return getSettlement[_settlementNonce];
    }

    function getFeeEstimate(
        uint16 _toChain,
        bytes calldata _payload,
        uint256 _gasLimit,
        uint256 _remoteBranchExecutionGas
    ) external view returns (uint256 _fee) {
        (_fee,) = ILayerZeroEndpoint(lzEndpointAddress).estimateFees(
            _toChain, address(this), _payload, false, _getAdapterParams(_gasLimit, _remoteBranchExecutionGas, _toChain)
        );
    }

    /*///////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function retrySettlement(uint32 _settlementNonce, GasParams calldata _gParams) external payable lock {
        //Clear Settlement with updated gas.
        _retrySettlement(_settlementNonce, _gParams);
    }

    /// @inheritdoc IRootBridgeAgent
    function redeemSettlement(uint32 _depositNonce) external lock {
        //Get deposit owner.
        address depositOwner = getSettlement[_depositNonce].owner;

        //Update Deposit
        if (getSettlement[_depositNonce].status != SettlementStatus.Failed || depositOwner == address(0)) {
            revert SettlementRedeemUnavailable();
        } else if (
            msg.sender != depositOwner && msg.sender != address(IPort(localPortAddress).getUserAccount(depositOwner))
        ) {
            revert NotSettlementOwner();
        }
        _redeemSettlement(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                    ROOT ROUTER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function callOut(address _recipient, uint16 _toChain, bytes memory _params, GasParams calldata _gParams)
        external
        payable
        lock
        requiresRouter
    {
        //Encode Data for call.
        bytes memory packedData = abi.encodePacked(bytes1(0x00), _recipient, settlementNonce++, _params);

        //Perform Call to clear hToken balance on destination branch chain.
        _performCall(packedData, _toChain, _gParams);
    }

    /// @inheritdoc IRootBridgeAgent
    function callOutAndBridge(
        address _owner,
        address _recipient,
        uint16 _toChain,
        bytes calldata _params,
        SettlementInput calldata _sParams,
        GasParams calldata _gParams
    ) external payable lock requiresRouter {
        //Get destination Local Address from Global Address.
        address localAddress = IPort(localPortAddress).getLocalTokenFromGlobal(_sParams.globalAddress, _toChain);

        //Get destination Underlying Address from Local Address.
        address underlyingAddress = IPort(localPortAddress).getUnderlyingTokenFromLocal(localAddress, _toChain);

        //Check if valid assets
        if (localAddress == address(0) || (underlyingAddress == address(0) && _sParams.deposit > 0)) {
            revert InvalidInputParams();
        }

        //Prepare data for call
        bytes memory packedData = abi.encodePacked(
            bytes1(0x01),
            _recipient,
            settlementNonce,
            localAddress,
            underlyingAddress,
            _sParams.amount,
            _sParams.deposit,
            _params
        );

        //Update State to reflect bridgeOut
        _updateStateOnBridgeOut(
            msg.sender,
            _sParams.globalAddress,
            localAddress,
            underlyingAddress,
            _sParams.amount,
            _sParams.deposit,
            _toChain
        );

        //Create Settlement
        _createSettlement(
            _owner, _recipient, localAddress, underlyingAddress, _sParams.amount, _sParams.deposit, packedData, _toChain
        );

        //Perform Call to clear hToken balance on destination branch chain and perform call.
        _performCall(packedData, _toChain, _gParams);
    }

    /// @inheritdoc IRootBridgeAgent
    function callOutAndBridgeMultiple(
        address _owner,
        address _recipient,
        uint16 _toChain,
        bytes calldata _params,
        SettlementMultipleInput calldata _sParams,
        GasParams calldata _gParams
    ) external payable lock requiresRouter {
        address[] memory hTokens = new address[](_sParams.globalAddresses.length);
        address[] memory tokens = new address[](_sParams.globalAddresses.length);
        for (uint256 i = 0; i < _sParams.globalAddresses.length;) {
            //Populate Addresses for Settlement
            hTokens[i] = IPort(localPortAddress).getLocalTokenFromGlobal(_sParams.globalAddresses[i], _toChain);
            tokens[i] = IPort(localPortAddress).getUnderlyingTokenFromLocal(hTokens[i], _toChain);

            if (hTokens[i] == address(0) || (tokens[i] == address(0) && _sParams.deposits[i] > 0)) {
                revert InvalidInputParams();
            }

            _updateStateOnBridgeOut(
                msg.sender,
                _sParams.globalAddresses[i],
                hTokens[i],
                tokens[i],
                _sParams.amounts[i],
                _sParams.deposits[i],
                _toChain
            );

            unchecked {
                ++i;
            }
        }

        //Bring 'up' to avoid stack too deep
        (bytes memory params, uint16 toChain) = (_params, _toChain);

        //Prepare data for call with settlement of multiple assets
        bytes memory packedData = abi.encodePacked(
            bytes1(0x02),
            _recipient,
            uint8(hTokens.length),
            settlementNonce,
            hTokens,
            tokens,
            _sParams.amounts,
            _sParams.deposits,
            params
        );

        //Create Settlement Balance
        _createMultipleSettlement(
            _owner, _recipient, hTokens, tokens, _sParams.amounts, _sParams.deposits, packedData, toChain
        );

        //Perform Call to destination Branch Chain.
        _performCall(packedData, toChain, _gParams);
    }

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function bridgeIn(address _recipient, DepositParams memory _dParams, uint16 _fromChain)
        public
        requiresAgentExecutor
    {
        //Check Deposit info from Cross Chain Parameters.
        if (!CheckParamsLib.checkParams(localPortAddress, _dParams, _fromChain)) {
            revert InvalidInputParams();
        }

        //Get global address
        address globalAddress = IPort(localPortAddress).getGlobalTokenFromLocal(_dParams.hToken, _fromChain);

        //Check if valid asset
        if (globalAddress == address(0)) revert InvalidInputParams();

        //Move hTokens from Branch to Root + Mint Sufficient hTokens to match new port deposit
        IPort(localPortAddress).bridgeToRoot(_recipient, globalAddress, _dParams.amount, _dParams.deposit, _fromChain);
    }

    /// @inheritdoc IRootBridgeAgent
    function bridgeInMultiple(address _recipient, DepositMultipleParams calldata _dParams, uint16 _fromChain)
        external
        requiresAgentExecutor
    {
        for (uint256 i = 0; i < _dParams.hTokens.length;) {
            bridgeIn(
                _recipient,
                DepositParams({
                    hToken: _dParams.hTokens[i],
                    token: _dParams.tokens[i],
                    amount: _dParams.amounts[i],
                    deposit: _dParams.deposits[i],
                    depositNonce: 0
                }),
                _fromChain
            );

            unchecked {
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                    TOKEN MANAGEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the token balance state by moving assets from root omnichain environment to branch chain, when a user wants to bridge out tokens from the root bridge agent chain.
     *     @param _depositor address of the token depositor.
     *     @param _globalAddress address of the global token.
     *     @param _localAddress address of the local token.
     *     @param _underlyingAddress address of the underlying token.
     *     @param _amount amount of hTokens to be bridged out.
     *     @param _deposit amount of underlying tokens to be bridged out.
     *     @param _toChain chain to bridge to.
     */
    function _updateStateOnBridgeOut(
        address _depositor,
        address _globalAddress,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit,
        uint16 _toChain
    ) internal {
        if (_amount - _deposit > 0) {
            //Move output hTokens from Root to Branch
            if (_localAddress == address(0)) revert UnrecognizedLocalAddress();
            _globalAddress.safeTransferFrom(_depositor, localPortAddress, _amount - _deposit);
        }

        if (_deposit > 0) {
            //Verify there is enough balance to clear native tokens if needed
            if (_underlyingAddress == address(0)) revert UnrecognizedUnderlyingAddress();
            if (IERC20hTokenRoot(_globalAddress).getTokenBalance(_toChain) < _deposit) {
                revert InsufficientBalanceForSettlement();
            }
            IPort(localPortAddress).burn(_depositor, _globalAddress, _deposit, _toChain);
        }
    }

    /*///////////////////////////////////////////////////////////////
                SETTLEMENT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to store a Settlement instance. Settlement should be reopened if fallback occurs.
     *    @param _owner settlement owner address.
     *    @param _recipient destination chain reciever address.
     *    @param _hToken deposited global token address.
     *    @param _token deposited global token address.
     *    @param _amount amounts of total hTokens + Tokens output.
     *    @param _deposit amount of underlying / native token to output.
     *    @param _callData calldata to execute on destination Router.
     *    @param _toChain Destination chain identificator.
     *
     */
    function _createSettlement(
        address _owner,
        address _recipient,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _callData,
        uint16 _toChain
    ) internal {
        //Cast to Dynamic
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        //Call createSettlement
        _createMultipleSettlement(_owner, _recipient, hTokens, tokens, amounts, deposits, _callData, _toChain);
    }

    /**
     * @notice Function to create a settlemment. Settlement should be reopened if fallback occurs.
     *    @param _owner settlement owner address.
     *    @param _recipient destination chain reciever address.
     *    @param _hTokens deposited global token addresses.
     *    @param _tokens deposited global token addresses.
     *    @param _amounts amounts of total hTokens + Tokens output.
     *    @param _deposits amount of underlying / native tokens to output.
     *    @param _callData calldata to execute on destination Router.
     *    @param _toChain Destination chain identificator.
     *
     *
     */
    function _createMultipleSettlement(
        address _owner,
        address _recipient,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _callData,
        uint16 _toChain
    ) internal {
        // Update State
        getSettlement[settlementNonce++] = Settlement({
            toChain: _toChain,
            owner: _owner,
            recipient: _recipient,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            status: SettlementStatus.Success,
            callData: _callData
        });
    }

    /**
     * @notice Function to retry a user's Settlement balance with a new amount of gas to bridge out of Root Bridge Agent's Omnichain Environment.
     *    @param _settlementNonce Identifier for token settlement.
     *    @param _gParams Gas parameters for the retry call.
     *
     */
    function _retrySettlement(uint32 _settlementNonce, GasParams calldata _gParams) internal {
        // Load into memory
        Settlement memory settlement = getSettlement[_settlementNonce];

        //Check if Settlement hasn't been redeemed.
        if (settlement.owner == address(0)) return;

        // Get storage reference
        Settlement storage _settlement = getSettlement[_settlementNonce];

        //Update Settlement Staus
        _settlement.status = SettlementStatus.Success;

        //Retry call with additional gas
        _performCall(settlement.callData, settlement.toChain, _gParams);
    }

    /**
     * @notice Function to retry a user's Settlement balance.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _redeemSettlement(uint32 _settlementNonce) internal {
        // Get storage reference
        Settlement storage settlement = getSettlement[_settlementNonce];

        //Clear Global hTokens To Recipient on Root Chain cancelling Settlement to Branch
        for (uint256 i = 0; i < settlement.hTokens.length;) {
            //Check if asset
            if (settlement.hTokens[i] != address(0)) {
                //Move hTokens from Branch to Root + Mint Sufficient hTokens to match new port deposit
                IPort(localPortAddress).bridgeToRoot(
                    msg.sender,
                    IPort(localPortAddress).getGlobalTokenFromLocal(settlement.hTokens[i], settlement.toChain),
                    settlement.amounts[i],
                    settlement.deposits[i],
                    settlement.toChain
                );
            }

            unchecked {
                ++i;
            }
        }

        // Delete Settlement
        delete getSettlement[_settlementNonce];
    }

    /**
     * @notice Function to reopen a user's Settlement balance as pending and thus retryable by users. Called upon anyFallback of triggered by Branch Bridge Agent.
     *     @param _settlementNonce Identifier for token settlement.
     *
     */
    function _reopenSettlemment(uint32 _settlementNonce) internal {
        //Update Deposit
        getSettlement[_settlementNonce].status = SettlementStatus.Failed;
    }

    /*///////////////////////////////////////////////////////////////
                    LAYER ZERO EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILayerZeroReceiver
    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64, bytes calldata _payload) public {
        address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(this.lzReceiveNonBlocking.selector, msg.sender, _srcChainId, _srcAddress, _payload)
        );
    }

    function lzReceiveNonBlocking(
        address _endpoint,
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        bytes calldata _payload
    ) public requiresEndpoint(_endpoint, _srcChainId, _srcAddress) {
        //Save Action Flag
        bytes1 flag = _payload[0];

        //DEPOSIT FLAG: 0 (System request / response)
        if (flag == 0x00) {
            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSystemRequest{value: address(this).balance}(
                localRouterAddress, _payload, _srcChainId
            ) {} catch (bytes memory) {
                _performFallbackCall(_payload, _srcChainId);
            }

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]))] = true;

            //DEPOSIT FLAG: 1 (Call without Deposit)
        } else if (flag == 0x01) {
            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeNoDeposit{value: address(this).balance}(
                localRouterAddress, _payload, _srcChainId
            ) {} catch (bytes memory) {
                _performFallbackCall(_payload, _srcChainId);
            }

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]))] = true;

            //DEPOSIT FLAG: 2 (Call with Deposit)
        } else if (flag == 0x02) {
            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithDeposit{value: address(this).balance}(
                localRouterAddress, _payload, _srcChainId
            ) {} catch (bytes memory) {
                _performFallbackCall(_payload, _srcChainId);
            }

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]))] = true;

            //DEPOSIT FLAG: 3 (Call with multiple asset Deposit)
        } else if (flag == 0x03) {
            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[2:6]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithDepositMultiple{
                value: address(this).balance
            }(localRouterAddress, _payload, _srcChainId) {} catch (bytes memory) {
                _performFallbackCall(_payload, _srcChainId);
            }

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[2:6]))] = true;

            //DEPOSIT FLAG: 4 (Call without Deposit + msg.sender)
        } else if (flag == 0x04) {
            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START_SIGNED:25]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Get User Virtual Account
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(_payload[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Bringing back to avoid stack too deep
            uint16 srcChainId = _srcChainId;

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSignedNoDeposit{value: address(this).balance}(
                address(userAccount), localRouterAddress, _payload, srcChainId
            ) {} catch (bytes memory) {
                _performFallbackCall(_payload, srcChainId);
            }

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START_SIGNED:25]))] = true;

            //DEPOSIT FLAG: 5 (Call with Deposit + msg.sender)
        } else if (flag == 0x05) {
            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START_SIGNED:25]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Get User Virtual Account
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(_payload[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Bringing back to avoid stack too deep
            uint16 srcChainId = _srcChainId;

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSignedWithDeposit{
                value: address(this).balance
            }(address(userAccount), localRouterAddress, _payload, srcChainId) {} catch (bytes memory) {
                _performFallbackCall(_payload, srcChainId);
            }

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START_SIGNED:25]))] = true;

            //DEPOSIT FLAG: 6 (Call with multiple asset Deposit + msg.sender)
        } else if (flag == 0x06) {
            //Bringing back to avoid stack too deep
            uint16 srcChainId = _srcChainId;

            //Check if tx has already been executed
            if (executionHistory[srcChainId][uint32(bytes4(_payload[PARAMS_START_SIGNED:25]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Get User Virtual Account
            VirtualAccount userAccount = IPort(localPortAddress).fetchVirtualAccount(
                address(uint160(bytes20(_payload[PARAMS_START:PARAMS_START_SIGNED])))
            );

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeSignedWithDepositMultiple{
                value: address(this).balance
            }(address(userAccount), localRouterAddress, _payload, srcChainId) {} catch (bytes memory) {
                _performFallbackCall(_payload, srcChainId);
            }

            //Toggle Router Virtual Account use for tx execution
            IPort(localPortAddress).toggleVirtualAccountApproved(userAccount, localRouterAddress);

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[PARAMS_START_SIGNED:25]))] = true;

            /// DEPOSIT FLAG: 7 (retrySettlement)
        } else if (flag == 0x07) {
            //Get nonce
            uint32 nonce = uint32(bytes4(_payload[1:5]));

            //Get gas params
            GasParams memory gasParams = abi.decode(_payload[5:], (GasParams));

            //Check if tx has already been executed
            if (executionHistory[_srcChainId][uint32(bytes4(_payload[1:5]))]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try RootBridgeAgentExecutor(bridgeAgentExecutorAddress).executeRetrySettlement{value: address(this).balance}(
                nonce, gasParams
            ) {} catch (bytes memory) {
                _performFallbackCall(_payload, _srcChainId);
            }

            //Update tx state as executed
            executionHistory[_srcChainId][uint32(bytes4(_payload[1:5]))] = true;

            /// DEPOSIT FLAG: 8 (retrieveDeposit)
        } else if (flag == 0x08) {
            //Get nonce
            uint32 nonce = uint32(bytes4(_payload[1:5]));

            //Check if tx has already been executed
            if (!executionHistory[_srcChainId][uint32(bytes4(_payload[1:5]))]) {
                //Toggle Nonce as executed
                executionHistory[_srcChainId][nonce] = true;

                //Retry failed fallback
                _performFallbackCall(_payload, _srcChainId);
            } else {
                revert AlreadyExecutedTransaction();
            }

            //DEPOSIT FLAG: 9 (Fallback)
        } else if (flag == 0x09) {
            //Reopen Settlement
            _fallback(_srcChainId, _payload[1:]);

            //Unrecognized Function Selector
        } else {
            revert UnknownFlag();
        }

        emit LogCallin(flag, _payload, _srcChainId);
    }

    /*///////////////////////////////////////////////////////////////
                    LAYER ZERO INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdapterParams(uint256 _gasLimit, uint256 _remoteBranchExecutionGas, uint16 _toChain)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(2), _gasLimit, _remoteBranchExecutionGas, getBranchBridgeAgent[_toChain]);
    }

    /**
     * @notice Internal function performs call to Layer Zero Endpoint Contract for cross-chain messaging.
     * @param _payload Payload of message to be sent to Layer Zero Endpoint Contract.
     * @param _toChain Chain ID of destination chain.
     * @param _gParams Gas parameters for cross-chain message execution.
     */

    function _performCall(bytes memory _payload, uint16 _toChain, GasParams calldata _gParams) internal {
        console2.log("performing call");
        //Get destination Branch Bridge Agent
        address callee = getBranchBridgeAgent[_toChain];

        if (callee == address(0)) revert UnrecognizedBridgeAgent();

        if (_toChain != localChainId) {
        console2.log("not local chain destination");
            //Sends message to AnycallProxy
            ILayerZeroEndpoint(lzEndpointAddress).send{value: msg.value}(
                _toChain,
                getBranchBridgeAgentPath[_toChain],
                _payload,
                payable(localPortAddress),
                address(0),
                abi.encodePacked(uint16(2), _gParams.gasLimit, _gParams.remoteBranchExecutionGas, callee)
            );
        } else {
            //Send Gas to Local Branch Bridge Agent
            callee.call{value: msg.value}("");
            //Execute locally
            IBranchBridgeAgent(callee).lzReceive(0, "", 0, _payload);
        }
    }

    /**
     * @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param _calldata params for root bridge agent execution.
     *   @param _toChain Chain ID of destination chain.
     */
    function _performFallbackCall(bytes calldata _calldata, uint16 _toChain) internal {
        //Sends message to LayerZero messaging layer
        ILayerZeroEndpoint(lzEndpointAddress).send{value: address(this).balance}(
            _toChain,
            getBranchBridgeAgentPath[_toChain],
            abi.encodePacked(bytes1(0x03), _calldata),
            payable(localPortAddress),
            address(0),
            ""
        );
    }

    /**
     * @notice Internal function called from Destination Chain Bridge Agent Contract through Layer Zero cross-chain messaging to revert Settlememt state upon branch execution failure.
     *   @param _srcChainId Chain ID of origin chain.
     *   @param _payload Payload of failed transaction.
     */
    function _fallback(uint16 _srcChainId, bytes calldata _payload) internal {
        //Save Flag
        bytes1 flag = _payload[0];

        //Deposit nonce
        uint32 _settlementNonce;

        /// SETTLEMENT FLAG: 0 (no asset settlement)
        if (flag == 0x00) {
            _settlementNonce = uint32(bytes4(_payload[PARAMS_START_SIGNED:25]));
            _reopenSettlemment(_settlementNonce);

            /// SETTLEMENT FLAG: 1 (single asset settlement)
        } else if (flag == 0x01) {
            _settlementNonce = uint32(bytes4(_payload[PARAMS_START_SIGNED:25]));
            _reopenSettlemment(_settlementNonce);

            /// SETTLEMENT FLAG: 2 (multiple asset settlement)
        } else if (flag == 0x02) {
            _settlementNonce = uint32(bytes4(_payload[22:26]));
            _reopenSettlemment(_settlementNonce);
        }
        emit LogCalloutFail(flag, _payload, _srcChainId);
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRootBridgeAgent
    function approveBranchBridgeAgent(uint256 _branchChainId) external requiresManager {
        if (getBranchBridgeAgent[_branchChainId] != address(0)) revert AlreadyAddedBridgeAgent();
        isBranchBridgeAgentAllowed[_branchChainId] = true;
    }

    /// @inheritdoc IRootBridgeAgent
    function syncBranchBridgeAgent(address _newBranchBridgeAgent, uint16 _branchChainId) external requiresPort {
        getBranchBridgeAgent[_branchChainId] = _newBranchBridgeAgent;
        getBranchBridgeAgentPath[_branchChainId] = abi.encodePacked(_newBranchBridgeAgent, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    uint256 internal _unlocked = 1;

    /// @notice Modifier for a simple re-entrancy check.
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /// @notice Modifier that verifies msg sender is the Bridge Agent's Router
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    /// @notice Internal function to verify msg sender is Bridge Agent's Router. Reuse to reduce contract bytesize.
    function _requiresRouter() internal view {
        if (msg.sender != localRouterAddress) revert UnrecognizedRouter();
    }

    /// @notice Modifier verifies the caller is the Anycall Executor or Local Branch Bridge Agent.
    modifier requiresEndpoint(address _endpoint, uint16 _srcChain, bytes calldata _srcAddress) {
        if (msg.sender != address(this)) revert LayerZeroUnauthorizedEndpoint();

        if (_endpoint == getBranchBridgeAgent[localChainId]) {} else {
            if (_endpoint != lzEndpointAddress) revert LayerZeroUnauthorizedEndpoint();

            if (keccak256(getBranchBridgeAgentPath[_srcChain]) != keccak256(_srcAddress)) {
                revert LayerZeroUnauthorizedCaller();
            }
        }
        _;
    }

    /// @notice Modifier that verifies msg sender is Bridge Agent Executor.
    modifier requiresAgentExecutor() {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedExecutor();
        _;
    }

    /// @notice Modifier that verifies msg sender is the Local Port.
    modifier requiresPort() {
        if (msg.sender != localPortAddress) revert UnrecognizedPort();
        _;
    }

    /// @notice Modifier that verifies msg sender is the Bridge Agent's Manager.
    modifier requiresManager() {
        if (msg.sender != IPort(localPortAddress).getBridgeAgentManager(address(this))) {
            revert UnrecognizedBridgeAgentManager();
        }
        _;
    }

    fallback() external payable {}
}
