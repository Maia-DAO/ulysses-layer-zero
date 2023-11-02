// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";

import {ExcessivelySafeCall} from "lib/ExcessivelySafeCall.sol";

import {WETH9} from "./interfaces/IWETH9.sol";

import {ILayerZeroEndpoint} from "./interfaces/ILayerZeroEndpoint.sol";

import {AnycallFlags} from "./lib/AnycallFlags.sol";
import {IAnycallProxy} from "./interfaces/IAnycallProxy.sol";
import {IAnycallConfig} from "./interfaces/IAnycallConfig.sol";
import {IAnycallExecutor} from "./interfaces/IAnycallExecutor.sol";
import {ILayerZeroReceiver, IBranchBridgeAgent} from "./interfaces/IBranchBridgeAgent.sol";
import {IBranchRouter as IRouter} from "./interfaces/IBranchRouter.sol";
import {IBranchPort as IPort} from "./interfaces/IBranchPort.sol";

import {ERC20hTokenBranch as ERC20hToken} from "./token/ERC20hTokenBranch.sol";
import {BranchBridgeAgentExecutor, DeployBranchBridgeAgentExecutor} from "./BranchBridgeAgentExecutor.sol";
import {
    RootPath,
    GasParams,
    Deposit,
    DepositStatus,
    DepositInput,
    DepositMultipleInput,
    DepositParams,
    DepositMultipleParams,
    SettlementParams,
    SettlementMultipleParams
} from "./interfaces/IBranchBridgeAgent.sol";

/// @title Library for Branch Bridge Agent Deployment
library DeployBranchBridgeAgent {
    function deploy(
        WETH9 _wrappedNativeToken,
        uint16 _rootChainId,
        uint16 _localChainId,
        address _rootBridgeAgentAddress,
        address _lzEndpointAddress,
        address _localRouterAddress,
        address _localPortAddress
    ) external returns (BranchBridgeAgent) {
        return new BranchBridgeAgent(
            _wrappedNativeToken,
            _rootChainId,
            _localChainId,
            _rootBridgeAgentAddress,
            _lzEndpointAddress,
            _localRouterAddress,
            _localPortAddress
        );
    }
}

/// @title Branch Bridge Agent Contract
contract BranchBridgeAgent is IBranchBridgeAgent {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using ExcessivelySafeCall for address;

    /*///////////////////////////////////////////////////////////////
                            ENCODING CONSTS
    //////////////////////////////////////////////////////////////*/

    /// AnyExec Decode Consts

    uint8 internal constant PARAMS_START = 1;

    uint8 internal constant PARAMS_START_SIGNED = 21;

    uint8 internal constant PARAMS_ENTRY_SIZE = 32;

    /// ClearTokens Decode Consts

    uint8 internal constant PARAMS_TKN_START = 5;

    uint8 internal constant PARAMS_AMT_OFFSET = 64;

    uint8 internal constant PARAMS_DEPOSIT_OFFSET = 96;

    /*///////////////////////////////////////////////////////////////
                         BRIDGE AGENT STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain Id for Root Chain where liqudity is virtualized(e.g. 4).
    uint16 public immutable rootChainId;

    /// @notice Chain Id for Local Chain.
    uint16 public immutable localChainId;

    /// @notice Address for Local Wrapped Native Token.
    WETH9 public immutable wrappedNativeToken;

    /// @notice Address for Bridge Agent who processes requests submitted for the Root Router Address where cross-chain requests are executed in the Root Chain.
    address public immutable rootBridgeAgentAddress;

    RootPath private rootBridgeAgentPath;

    /// @notice Address for Local AnycallV7 Proxy Address where cross-chain requests are sent to the Root Chain Router.
    address public immutable lzEndpointAddress;

    /// @notice Address for Local Router used for custom actions for different hApps.
    address public immutable localRouterAddress;

    /// @notice Address for Local Port Address where funds deposited from this chain are kept, managed and supplied to different Port Strategies.
    address public immutable localPortAddress;

    address public bridgeAgentExecutorAddress;

    /*///////////////////////////////////////////////////////////////
                            DEPOSITS STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit nonce used for identifying transaction.
    uint32 public depositNonce;

    /// @notice Mapping from Pending deposits hash to Deposit Struct.
    mapping(uint32 => Deposit) public getDeposit;

    /*///////////////////////////////////////////////////////////////
                            EXECUTOR STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice If true, bridge agent has already served a request with this nonce from  a given chain. Chain -> Nonce -> Bool
    mapping(uint32 => bool) public executionHistory;

    /*///////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        WETH9 _wrappedNativeToken,
        uint16 _rootChainId,
        uint16 _localChainId,
        address _rootBridgeAgentAddress,
        address _lzEndpointAddress,
        address _localRouterAddress,
        address _localPortAddress
    ) {
        require(_rootBridgeAgentAddress != address(0), "Root Bridge Agent Address cannot be the zero address.");
        require(_lzEndpointAddress != address(0), "AnyCall Address cannot be the zero address.");
        require(_localRouterAddress != address(0), "Local Router Address cannot be the zero address.");
        require(_localPortAddress != address(0), "Local Port Address cannot be the zero address.");

        wrappedNativeToken = _wrappedNativeToken;
        localChainId = _localChainId;
        rootChainId = _rootChainId;
        rootBridgeAgentAddress = _rootBridgeAgentAddress;
        lzEndpointAddress = _lzEndpointAddress;
        localRouterAddress = _localRouterAddress;
        localPortAddress = _localPortAddress;
        bridgeAgentExecutorAddress = DeployBranchBridgeAgentExecutor.deploy();
        depositNonce = 1;

        rootBridgeAgentPath = RootPath({rootPathAsBytes: abi.encodePacked(_rootBridgeAgentAddress, address(this))});
    }

    /*///////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function getDepositEntry(uint32 _depositNonce) external view returns (Deposit memory) {
        return getDeposit[_depositNonce];
    }

    function getFeeEstimate(bytes calldata _payload, uint256 _gasLimit, uint256 _remoteBranchExecutionGas)
        external
        view
        returns (uint256 _fee)
    {
        (_fee,) = ILayerZeroEndpoint(lzEndpointAddress).estimateFees(
            rootChainId, address(this), _payload, false, _getAdapterParams(_gasLimit, _remoteBranchExecutionGas)
        );
    }

    /*///////////////////////////////////////////////////////////////
                        USER EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function callOutSystem(address payable _refundee, bytes calldata _params, GasParams calldata _gParams)
        external
        payable
        lock
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x00), depositNonce++, _params);

        //Perform Call
        _performCall(_refundee, packedData, _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas));
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOut(address payable _refundee, bytes calldata _params, GasParams calldata _gParams)
        external
        payable
        lock
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x01), depositNonce++, _params);

        //Perform Call
        _performCall(_refundee, packedData, _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas));
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutAndBridge(
        address payable _refundee,
        bytes calldata _params,
        DepositInput memory _dParams,
        GasParams calldata _gParams
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x02), depositNonce, _dParams.hToken, _dParams.token, _dParams.amount, _dParams.deposit, _params
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            _refundee,
            packedData,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas)
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutAndBridgeMultiple(
        address payable _refundee,
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        GasParams calldata _gParams
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x03),
            uint8(_dParams.hTokens.length),
            depositNonce,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _params
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            _refundee,
            packedData,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas)
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSigned(address payable _refundee, bytes calldata _params, GasParams calldata _gParams)
        external
        payable
        lock
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x04), msg.sender, depositNonce, _params);

        //Perform Signed Call without deposit
        _performCall(_refundee, packedData, _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas));
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSignedAndBridge(
        address payable _refundee,
        bytes calldata _params,
        DepositInput memory _dParams,
        GasParams calldata _gParams
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x05),
            msg.sender,
            depositNonce,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            _params
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCall(
            _refundee,
            packedData,
            _dParams.hToken,
            _dParams.token,
            _dParams.amount,
            _dParams.deposit,
            _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas)
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function callOutSignedAndBridgeMultiple(
        address payable _refundee,
        bytes calldata _params,
        DepositMultipleInput memory _dParams,
        GasParams calldata _gParams
    ) external payable lock {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(
            bytes1(0x06),
            msg.sender,
            uint8(_dParams.hTokens.length),
            depositNonce,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _params
        );

        //Create Deposit and Send Cross-Chain request
        _depositAndCallMultiple(
            _refundee,
            packedData,
            _dParams.hTokens,
            _dParams.tokens,
            _dParams.amounts,
            _dParams.deposits,
            _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas)
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function retryDeposit(
        bool _isSigned,
        uint32 _depositNonce,
        address payable _refundee,
        bytes calldata _params,
        GasParams calldata _gParams
    ) external payable lock {
        //Check if deposit belongs to message sender
        if (getDeposit[_depositNonce].owner != msg.sender) revert NotDepositOwner();

        //Encode Data for cross-chain call.
        bytes memory packedData;

        if (uint8(getDeposit[_depositNonce].hTokens.length) == 1) {
            if (_isSigned) {
                packedData = abi.encodePacked(
                    bytes1(0x05),
                    msg.sender,
                    _depositNonce,
                    getDeposit[_depositNonce].hTokens[0],
                    getDeposit[_depositNonce].tokens[0],
                    getDeposit[_depositNonce].amounts[0],
                    getDeposit[_depositNonce].deposits[0],
                    _params
                );
            } else {
                packedData = abi.encodePacked(
                    bytes1(0x02),
                    _depositNonce,
                    getDeposit[_depositNonce].hTokens[0],
                    getDeposit[_depositNonce].tokens[0],
                    getDeposit[_depositNonce].amounts[0],
                    getDeposit[_depositNonce].deposits[0],
                    _params
                );
            }
        } else if (uint8(getDeposit[_depositNonce].hTokens.length) > 1) {
            //Nonce
            uint32 nonce = _depositNonce;

            if (_isSigned) {
                packedData = abi.encodePacked(
                    bytes1(0x06),
                    msg.sender,
                    uint8(getDeposit[_depositNonce].hTokens.length),
                    nonce,
                    getDeposit[nonce].hTokens,
                    getDeposit[nonce].tokens,
                    getDeposit[nonce].amounts,
                    getDeposit[nonce].deposits,
                    _params
                );
            } else {
                packedData = abi.encodePacked(
                    bytes1(0x03),
                    uint8(getDeposit[nonce].hTokens.length),
                    _depositNonce,
                    getDeposit[nonce].hTokens,
                    getDeposit[nonce].tokens,
                    getDeposit[nonce].amounts,
                    getDeposit[nonce].deposits,
                    _params
                );
            }
        }

        //Ensure success Status
        getDeposit[_depositNonce].status = DepositStatus.Success;

        //Perform Call
        _performCall(_refundee, packedData, _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas));
    }

    /// @inheritdoc IBranchBridgeAgent
    function retrySettlement(uint32 _settlementNonce, address payable _refundee, GasParams calldata _gParams)
        external
        payable
        lock
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x07), depositNonce++, _settlementNonce);
        //Update State and Perform Call
        _sendRetrieveOrRetry(
            _refundee, packedData, _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas)
        );
    }

    /// @inheritdoc IBranchBridgeAgent
    function retrieveDeposit(uint32 _depositNonce, address payable _refundee, GasParams calldata _gParams)
        external
        payable
        lock
    {
        //Encode Data for cross-chain call.
        bytes memory packedData = abi.encodePacked(bytes1(0x08), _depositNonce);

        //Update State and Perform Call
        _sendRetrieveOrRetry(
            _refundee, packedData, _getAdapterParams(_gParams.gasLimit, _gParams.remoteBranchExecutionGas)
        );
    }

    /**
     * @notice Internal function to send a cross-chain call through LayerZero Messaging Layer retrieving or retrying a deposit.
     *  @param _refundee Address to refund gas to.
     *  @param _data Encoded data to be sent to the root router.
     *  @param _lzAdapterParams LayerZero gas information. (_gasLimit + _remoteBranchExecutionGas)
     */
    function _sendRetrieveOrRetry(address payable _refundee, bytes memory _data, bytes memory _lzAdapterParams)
        internal
    {
        //Perform Call
        _performCall(_refundee, _data, _lzAdapterParams);
    }

    /// @inheritdoc IBranchBridgeAgent
    function redeemDeposit(uint32 _depositNonce) external lock {
        //Get storage reference
        Deposit storage deposit = getDeposit[_depositNonce];

        //Check Deposit
        if (deposit.status != DepositStatus.Failed || deposit.owner == address(0)) {
            revert DepositRedeemUnavailable();
        }
        _redeemDeposit(_depositNonce);
    }

    /*///////////////////////////////////////////////////////////////
                TOKEN MANAGEMENT EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBranchBridgeAgent
    function clearToken(address _recipient, address _hToken, address _token, uint256 _amount, uint256 _deposit)
        external
        requiresAgentExecutor
    {
        _clearToken(_recipient, _hToken, _token, _amount, _deposit);
    }

    /// @inheritdoc IBranchBridgeAgent
    function clearTokens(bytes calldata _sParams, address _recipient)
        external
        requiresAgentExecutor
        returns (SettlementMultipleParams memory)
    {
        //Parse Params
        uint8 numOfAssets = uint8(bytes1(_sParams[0]));
        uint32 nonce = uint32(bytes4(_sParams[PARAMS_START:PARAMS_TKN_START]));

        address[] memory _hTokens = new address[](numOfAssets);
        address[] memory _tokens = new address[](numOfAssets);
        uint256[] memory _amounts = new uint256[](numOfAssets);
        uint256[] memory _deposits = new uint256[](numOfAssets);

        //Transfer token to recipient
        for (uint256 i = 0; i < numOfAssets;) {
            //Parse Params
            _hTokens[i] = address(
                uint160(
                    bytes20(
                        bytes32(
                            _sParams[
                                PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * i) + 12:
                                    PARAMS_TKN_START + (PARAMS_ENTRY_SIZE * (PARAMS_START + i))
                            ]
                        )
                    )
                )
            );
            _tokens[i] = address(
                uint160(
                    bytes20(
                        _sParams[
                            PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(i + numOfAssets) + 12:
                                PARAMS_TKN_START + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i + numOfAssets)
                        ]
                    )
                )
            );
            _amounts[i] = uint256(
                bytes32(
                    _sParams[
                        PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_AMT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );
            _deposits[i] = uint256(
                bytes32(
                    _sParams[
                        PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets) + (PARAMS_ENTRY_SIZE * uint16(i)):
                            PARAMS_TKN_START + PARAMS_DEPOSIT_OFFSET * uint16(numOfAssets)
                                + PARAMS_ENTRY_SIZE * uint16(PARAMS_START + i)
                    ]
                )
            );
            //Clear Tokens to destination
            if (_amounts[i] - _deposits[i] > 0) {
                IPort(localPortAddress).bridgeIn(_recipient, _hTokens[i], _amounts[i] - _deposits[i]);
            }

            if (_deposits[i] > 0) {
                IPort(localPortAddress).withdraw(_recipient, _tokens[i], _deposits[i]);
            }

            unchecked {
                ++i;
            }
        }

        return SettlementMultipleParams(numOfAssets, _recipient, nonce, _hTokens, _tokens, _amounts, _deposits);
    }

    /*///////////////////////////////////////////////////////////////
                LOCAL USER DEPOSIT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _refundee address to return excess gas deposited in `msg.value` to.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _hToken Local Input hToken Address.
     *   @param _token Native / Underlying Token Address.
     *   @param _amount Amount of Local hTokens deposited for trade.
     *   @param _deposit Amount of native tokens deposited for trade.
     *   @param _lzAdapterParams LayerZero gas information. (_gasLimit + _remoteBranchExecutionGas)
     *
     */
    function _depositAndCall(
        address payable _refundee,
        bytes memory _data,
        address _hToken,
        address _token,
        uint256 _amount,
        uint256 _deposit,
        bytes memory _lzAdapterParams
    ) internal {
        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOut(msg.sender, _hToken, _token, _amount, _deposit);

        // Cast to dynamic memory array
        address[] memory hTokens = new address[](1);
        hTokens[0] = _hToken;
        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;
        uint256[] memory deposits = new uint256[](1);
        deposits[0] = _deposit;

        // Update State
        getDeposit[depositNonce++] = Deposit({
            owner: _refundee,
            hTokens: hTokens,
            tokens: tokens,
            amounts: amounts,
            deposits: deposits,
            status: DepositStatus.Success
        });

        //Perform Call
        _performCall(_refundee, _data, _lzAdapterParams);
    }

    /**
     * @dev Internal function to move assets from branch chain to root omnichain environment. Naive assets are deposited and hTokens are bridgedOut.
     *   @param _refundee address to return excess gas deposited in `msg.value` to.
     *   @param _data data to be sent to cross-chain messaging layer.
     *   @param _hTokens Local Input hToken Address.
     *   @param _tokens Native / Underlying Token Address.
     *   @param _amounts Amount of Local hTokens deposited for trade.
     *   @param _deposits  Amount of native tokens deposited for trade.
     *   @param _lzAdapterParams LayerZero gas information. (_gasLimit + _remoteBranchExecutionGas)
     *
     */
    function _depositAndCallMultiple(
        address payable _refundee,
        bytes memory _data,
        address[] memory _hTokens,
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256[] memory _deposits,
        bytes memory _lzAdapterParams
    ) internal {
        //Validate Input
        if (
            _hTokens.length != _tokens.length || _tokens.length != _amounts.length
                || _amounts.length != _deposits.length
        ) revert InvalidInput();

        //Deposit / Lock Tokens into Port
        IPort(localPortAddress).bridgeOutMultiple(msg.sender, _hTokens, _tokens, _amounts, _deposits);

        // Update State
        getDeposit[depositNonce++] = Deposit({
            owner: _refundee,
            hTokens: _hTokens,
            tokens: _tokens,
            amounts: _amounts,
            deposits: _deposits,
            status: DepositStatus.Success
        });

        //Perform Call
        _performCall(_refundee, _data, _lzAdapterParams);
    }

    /**
     * @dev External function to clear / refund a user's failed deposit.
     *    @param _depositNonce Identifier for user deposit.
     *
     */
    function _redeemDeposit(uint32 _depositNonce) internal {
        //Get Deposit
        Deposit storage deposit = getDeposit[_depositNonce];

        //Save Deposit Tokens Length
        uint256 depositTokensLength = deposit.tokens.length;

        //Transfer token to depositor / user
        for (uint256 i = 0; i < depositTokensLength;) {
            _clearToken(deposit.owner, deposit.hTokens[i], deposit.tokens[i], deposit.amounts[i], deposit.deposits[i]);

            unchecked {
                ++i;
            }
        }

        //Delete Failed Deposit Token Info
        delete getDeposit[_depositNonce];
    }

    /*///////////////////////////////////////////////////////////////
                REMOTE USER DEPOSIT INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to request balance clearance from a Port to a given user.
     *     @param _recipient token receiver.
     *     @param _hToken  local hToken addresse to clear balance for.
     *     @param _token  native / underlying token addresse to clear balance for.
     *     @param _amount amounts of hToken to clear balance for.
     *     @param _deposit amount of native / underlying tokens to clear balance for.
     *
     */
    function _clearToken(address _recipient, address _hToken, address _token, uint256 _amount, uint256 _deposit)
        internal
    {
        if (_amount - _deposit > 0) {
            IPort(localPortAddress).bridgeIn(_recipient, _hToken, _amount - _deposit);
        }

        if (_deposit > 0) {
            IPort(localPortAddress).withdraw(_recipient, _token, _deposit);
        }
    }

    /**
     * @notice Function to clear / refund a user's failed deposit. Called upon fallback in cross-chain messaging.
     *    @param _depositNonce Identifier for user deposit.
     *
     */
    function _clearDeposit(uint32 _depositNonce) internal {
        //Update and return Deposit
        getDeposit[_depositNonce].status = DepositStatus.Failed;
    }

    /*///////////////////////////////////////////////////////////////
                    LAYER ZERO EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ILayerZeroReceiver
    function lzReceive(uint16, bytes calldata _srcAddress, uint64, bytes calldata _payload) public {
        address(this).excessivelySafeCall(
            gasleft(),
            150,
            abi.encodeWithSelector(this.lzReceiveNonBlocking.selector, msg.sender, _srcAddress, _payload)
        );
    }

    function lzReceiveNonBlocking(address _endpoint, bytes calldata _srcAddress, bytes calldata _payload)
        public
        requiresEndpoint(_endpoint, _srcAddress)
    {
        //Save Recipient
        address payable recipient = payable(address(uint160(bytes20(_payload[PARAMS_START:PARAMS_START_SIGNED]))));

        //Save Action Flag
        bytes1 flag = _payload[0];

        //DEPOSIT FLAG: 0 (No settlement)
        if (flag == 0x00) {
            //Get Settlement Nonce
            uint32 nonce = uint32(bytes4(_payload[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[nonce]) {
                revert AlreadyExecutedTransaction();
            }

            try BranchBridgeAgentExecutor(bridgeAgentExecutorAddress).executeNoSettlement{value: address(this).balance}(
                localRouterAddress, _payload
            ) {} catch (bytes memory) {
                _performFallbackCall(recipient, _payload);
            }

            //Update tx state as executed
            executionHistory[nonce] = true;

            //DEPOSIT FLAG: 1 (Single Asset Settlement)
        } else if (flag == 0x01) {
            //Get Settlement Nonce
            uint32 nonce = uint32(bytes4(_payload[PARAMS_START_SIGNED:25]));

            //Check if tx has already been executed
            if (executionHistory[nonce]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try BranchBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithSettlement{
                value: address(this).balance
            }(recipient, localRouterAddress, _payload) {} catch (bytes memory) {
                _performFallbackCall(recipient, _payload);
            }

            //Update tx state as executed
            executionHistory[nonce] = true;

            //DEPOSIT FLAG: 2 (Multiple Settlement)
        } else if (flag == 0x02) {
            //Get deposit nonce
            uint32 nonce = uint32(bytes4(_payload[22:26]));

            //Check if tx has already been executed
            if (executionHistory[nonce]) {
                revert AlreadyExecutedTransaction();
            }

            //Try to execute remote request
            try BranchBridgeAgentExecutor(bridgeAgentExecutorAddress).executeWithSettlementMultiple{
                value: address(this).balance
            }(recipient, localRouterAddress, _payload) {} catch (bytes memory) {
                _performFallbackCall(recipient, _payload);
            }

            //Update tx state as executed
            executionHistory[nonce] = true;

            //DEPOSIT FLAG: 3 (Fallback)
        } else if (flag == 0x03) {
            //Reopen Deposit
            _fallback(_payload);

            //Unrecognized Function Selector
        } else {
            revert UnknownFlag();
        }

        emit LogCallin(flag, _payload, rootChainId);
    }

    /*///////////////////////////////////////////////////////////////
                    LAYER ZERO INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAdapterParams(uint256 _gasLimit, uint256 _remoteBranchExecutionGas)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(uint16(2), _gasLimit, _remoteBranchExecutionGas, rootBridgeAgentAddress);
    }

    /**
     * @notice Internal function performs call to LayerZero messaging layer Endpoint for cross-chain messaging.
     *   @param _refundee address to refund gas to.
     *   @param _calldata params for root bridge agent execution.
     *   @param _lzAdapterParams LayerZero gas information. (_gasLimit + _remoteBranchExecutionGas)
     */
    function _performCall(address payable _refundee, bytes memory _calldata, bytes memory _lzAdapterParams)
        internal
        virtual
    {
        //Sends message to LayerZero messaging layer
        ILayerZeroEndpoint(lzEndpointAddress).send{value: msg.value}(
            rootChainId, rootBridgeAgentPath.rootPathAsBytes, _calldata, _refundee, address(0), _lzAdapterParams
        );
    }

    /**
     * @notice Internal function performs call to AnycallProxy Contract for cross-chain messaging.
     *   @param _refundee address to refund gas to.
     *   @param _calldata params for root bridge agent execution.
     */
    function _performFallbackCall(address payable _refundee, bytes calldata _calldata) internal {
        //Sends message to LayerZero messaging layer
        ILayerZeroEndpoint(lzEndpointAddress).send{value: address(this).balance}(
            rootChainId,
            rootBridgeAgentPath.rootPathAsBytes,
            abi.encodePacked(bytes1(0x09), _calldata),
            _refundee,
            address(0),
            ""
        );
    }

    function _fallback(bytes calldata _payload) internal {
        //Save Flag
        bytes1 flag = _payload[0];

        //Save memory for Deposit Nonce
        uint32 _depositNonce;

        /// DEPOSIT FLAG: 0, 1, 2, 8
        if ((flag == 0x00) || (flag == 0x01) || (flag == 0x02) || (flag == 0x08)) {
            //Check nonce calldata slice.
            _depositNonce = uint32(bytes4(_payload[PARAMS_START:PARAMS_TKN_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, _payload, rootChainId);

            /// DEPOSIT FLAG: 3
        } else if (flag == 0x03) {
            _depositNonce = uint32(bytes4(_payload[PARAMS_START + PARAMS_START:PARAMS_TKN_START + PARAMS_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, _payload, rootChainId);

            /// DEPOSIT FLAG: 4, 5
        } else if ((flag == 0x04) || (flag == 0x05)) {
            //Save nonce
            _depositNonce = uint32(bytes4(_payload[PARAMS_START_SIGNED:PARAMS_START_SIGNED + PARAMS_TKN_START]));

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, _payload, rootChainId);

            /// DEPOSIT FLAG: 6
        } else if (flag == 0x06) {
            //Save nonce
            _depositNonce = uint32(
                bytes4(
                    _payload[PARAMS_START_SIGNED + PARAMS_START:PARAMS_START_SIGNED + PARAMS_TKN_START + PARAMS_START]
                )
            );

            //Make tokens available to depositor.
            _clearDeposit(_depositNonce);

            emit LogCalloutFail(flag, _payload, rootChainId);

            //Unrecognized Function Selector
        } else {
            revert UnknownFlag();
        }
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

    /// @notice Modifier verifies the caller is the Anycall Executor or Local Branch Bridge Agent.
    modifier requiresEndpoint(address _endpoint, bytes calldata _srcAddress) {
        _requiresEndpoint(_endpoint, _srcAddress);
        _;
    }

    /// @notice Verifies the caller is the Anycall Executor. Internal function used in modifier to reduce contract bytesize.
    function _requiresEndpoint(address _endpoint, bytes calldata _srcAddress) internal view virtual {
        //Verify Endpoint
        if (msg.sender != address(this) || _endpoint != lzEndpointAddress) revert LayerZeroUnauthorizedEndpoint();
        //Verify Remote Caller
        if (rootBridgeAgentAddress != address(uint160(bytes20(_srcAddress[20:])))) revert LayerZeroUnauthorizedCaller();
    }

    /// @notice Modifier that verifies caller is Branch Bridge Agent's Router.
    modifier requiresRouter() {
        _requiresRouter();
        _;
    }

    /// @notice Internal function that verifies caller is Branch Bridge Agent's Router. Reuse to reduce contract bytesize.
    function _requiresRouter() internal view {
        if (msg.sender != localRouterAddress) revert UnrecognizedRouter();
    }

    /// @notice Modifier that verifies caller is the Bridge Agent Executor.
    modifier requiresAgentExecutor() {
        if (msg.sender != bridgeAgentExecutorAddress) revert UnrecognizedBridgeAgentExecutor();
        _;
    }

    fallback() external payable {}
}
