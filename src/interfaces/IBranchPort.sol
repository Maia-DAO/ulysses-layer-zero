// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title  Branch Port - Omnichain Token Management Contract
 * @author MaiaDAO
 * @notice Ulyses `Port` implementation for Branch Chain deployment. This contract is used to manage the deposit and
 *         withdrawal of underlying assets from the Branch Chain in response to Branch Bridge Agent requests.
 *         Manages Bridge Agents and their factories as well as the chain's strategies and their tokens.
 */
interface IBranchPort {
    /*///////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/
    /**
     * @notice Returns true if the address is a Bridge Agent.
     *   @param _bridgeAgent Bridge Agent address.
     *   @return bool .
     */
    function isBridgeAgent(address _bridgeAgent) external view returns (bool);

    /**
     * @notice Returns true if the address is a Strategy Token.
     *   @param _token token address.
     *   @return bool.
     */
    function isStrategyToken(address _token) external view returns (bool);

    /**
     * @notice Returns true if the address is a Port Strategy.
     *   @param _strategy strategy address.
     *   @param _token token address.
     *   @return bool.
     */
    function isPortStrategy(address _strategy, address _token) external view returns (bool);

    /**
     * @notice Returns true if the address is a Bridge Agent Factory.
     *   @param _bridgeAgentFactory Bridge Agent Factory address.
     *   @return bool.
     */
    function isBridgeAgentFactory(address _bridgeAgentFactory) external view returns (bool);

    /*///////////////////////////////////////////////////////////////
                          PORT STRATEGY MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows active Port Strategy addresses to withdraw assets.
     *  @param _token token address.
     *  @param _amount amount of tokens.
     */
    function manage(address _token, uint256 _amount) external;

    /**
     * @notice allow strategy address to repay borrowed reserves with reserves.
     *  @param _amount amount of tokens to repay.
     *  @param _token address of the token to repay.
     *  @dev must be called by the port strategy itself.
     */
    function replenishReserves(address _token, uint256 _amount) external;

    /**
     * @notice allow anyone to request repayment of a strategy's reserves if Port is under minimum reserves ratio.
     *  @param _strategy address of the strategy to repay.
     *  @param _token address of the token to repay.
     *  @dev can be called by anyone to ensure availability of service.
     */
    function replenishReserves(address _strategy, address _token) external;

    /*///////////////////////////////////////////////////////////////
                          hTOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to withdraw underlying / native token amount from Port to Branch Bridge Agent.
     *   @param _recipient address of the underlying token receiver.
     *   @param _underlyingAddress underlying token address.
     *   @param _amount amount of tokens.
     *   @dev must be called by the bridge agent itself. Matches the burning of global hTokens in root chain.
     */
    function withdraw(address _recipient, address _underlyingAddress, uint256 _amount) external;

    /**
     * @notice Function to mint hToken amount to Branch Bridge Agent.
     *   @param _recipient address of the hToken receiver.
     *   @param _localAddress hToken address.
     *   @param _amount amount of hTokens.
     *   @dev must be called by the bridge agent itself. Matches the storage of global hTokens in root port.
     */
    function bridgeIn(address _recipient, address _localAddress, uint256 _amount) external;

    /**
     * @notice Function to withdraw underlying / native tokens and mint local hTokens to Branch Bridge Agent.
     *   @param _recipient address of the token receiver.
     *   @param _localAddresses local hToken addresses.
     *   @param _underlyingAddresses underlying token addresses.
     *   @param _amounts total amount of tokens.
     *   @param _deposits amount of underlying tokens.
     */
    function bridgeInMultiple(
        address _recipient,
        address[] memory _localAddresses,
        address[] memory _underlyingAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) external;

    /**
     * @notice Function to deposit underlying / native tokens in Port and burn hTokens.
     *   @param _depositor address of the token depositor.
     *   @param _localAddress local hToken addresses.
     *   @param _underlyingAddress underlying token addresses.
     *   @param _amount total amount of tokens.
     *   @param _deposit amount of underlying tokens.
     */
    function bridgeOut(
        address _depositor,
        address _localAddress,
        address _underlyingAddress,
        uint256 _amount,
        uint256 _deposit
    ) external;

    /**
     * @notice Setter function to decrease local hToken supply.
     *   @param _depositor address of the token depositor.
     *   @param _localAddresses local hToken addresses.
     *   @param _underlyingAddresses underlying token addresses.
     *   @param _amounts total amount of tokens.
     *   @param _deposits amount of underlying tokens.
     */
    function bridgeOutMultiple(
        address _depositor,
        address[] memory _localAddresses,
        address[] memory _underlyingAddresses,
        uint256[] memory _amounts,
        uint256[] memory _deposits
    ) external;

    /*///////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new bridge agent address to the branch port.
     *   @param _bridgeAgent address of the bridge agent to add to the Port
     */
    function addBridgeAgent(address _bridgeAgent) external;

    /**
     * @notice Toggle a given bridge agent factory. If it's active, it will de-activate it and vice-versa.
     *   @param _bridgeAgentFactory address of the bridge agent factory to add to the Port
     */
    function toggleBridgeAgentFactory(address _bridgeAgentFactory) external;

    /**
     * @notice Toggle a given strategy token. If it's active, it will de-activate it and vice-versa.
     * @param _token address of the token to add to the Strategy Tokens
     * @param _minimumReservesRatio minimum reserves ratio for the token
     * @dev Must be between 7000 and 10000 (70% and 100%). Can be any value if the token is being de-activated.
     */
    function toggleStrategyToken(address _token, uint256 _minimumReservesRatio) external;

    /**
     * @notice Update an active strategy token's minimum reserves ratio. If it is not active, it will revert.
     * @param _token address of the token to add to the Strategy Tokens
     * @param _minimumReservesRatio minimum reserves ratio for the token
     * @dev Must be between 7000 and 10000 (70% and 100%). Can be any value if the token is being de-activated.
     */
    function updateStrategyToken(address _token, uint256 _minimumReservesRatio) external;

    /**
     * @notice Add or Remove a Port Strategy.
     * @param _portStrategy Address of the Port Strategy to be added for use in Branch strategies.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _dailyManagementLimit Daily management limit of the given token for the Port Strategy.
     * @param _reserveRatioManagementLimit Total reserves management limit of the given token for the Port Strategy.
     * @dev Must be between 7000 and 10000 (70% and 100%). Can be any value if the token is being de-activated.
     */
    function togglePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit
    ) external;

    /**
     * @notice Updates a Port Strategy.
     * @param _portStrategy Address of the Port Strategy to be added for use in Branch strategies.
     * @param _underlyingToken Address of the underlying token to be added for use in Branch strategies.
     * @param _dailyManagementLimit Daily management limit of the given token for the Port Strategy.
     * @param _reserveRatioManagementLimit Total reserves management limit of the given token for the Port Strategy.
     * @dev Must be between 7000 and 10000 (70% and 100%). Can be any value if the token is being de-activated.
     */
    function updatePortStrategy(
        address _portStrategy,
        address _underlyingToken,
        uint256 _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit
    ) external;

    /**
     * @notice Sets the core branch router and bridge agent for the branch port.
     *   @param _coreBranchRouter address of the new core branch router
     *   @param _coreBranchBridgeAgent address of the new core branch bridge agent
     */
    function setCoreBranchRouter(address _coreBranchRouter, address _coreBranchBridgeAgent) external;

    /**
     * @notice Allows governance to claim any native tokens accumulated from failed transactions.
     *  @param _recipient address to transfer ETH to.
     */
    function sweep(address _recipient) external;

    /*///////////////////////////////////////////////////////////////
                            EVENTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when a Port Strategy manages more reserves increasing its debt for a given token.
    event DebtCreated(address indexed _strategy, address indexed _token, uint256 _amount);
    /// @notice Event emitted when a Port Strategy replenishes reserves decreasing its debt for a given token.
    event DebtRepaid(address indexed _strategy, address indexed _token, uint256 _amount);

    /// @notice Event emitted when Strategy Token has its details updated.
    event StrategyTokenUpdated(address indexed _token, uint256 indexed _minimumReservesRatio);

    /// @notice Event emitted when a Port Strategy has its details updated.
    event PortStrategyUpdated(
        address indexed _portStrategy,
        address indexed _token,
        uint256 indexed _dailyManagementLimit,
        uint256 _reserveRatioManagementLimit
    );

    /// @notice Event emitted when a Branch Bridge Agent Factory is toggled on or off.
    event BridgeAgentFactoryToggled(address indexed _bridgeAgentFactory);

    /// @notice Event emitted when a Bridge Agent is toggled on or off.
    event BridgeAgentToggled(address indexed _bridgeAgent);

    /// @notice Event emitted when a Core Branch Router and Bridge Agent are set.
    event CoreBranchSet(address indexed _coreBranchRouter, address indexed _coreBranchBridgeAgent);

    /*///////////////////////////////////////////////////////////////
                            ERRORS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Error emitted when Bridge Agent is already added.
    error AlreadyAddedBridgeAgent();

    /// @notice Error emitted when Port Strategy request would exceed the Branch Port's minimum reserves.
    error InsufficientReserves();
    /// @notice Error emitted when not enough debt.
    error InsufficientDebt();

    /// @notice Error emitted when Port Strategy request would exceed it's reserve ratio management limit.
    error ExceedsReserveRatioManagementLimit();

    /// @notice Error emitted when amount requested is zero.
    error InvalidAmount();
    /// @notice Error emitted when minimum reserves ratio is set too low.
    error InvalidMinimumReservesRatio();
    /// @notice Error emitted when token deposit arrays have different lengths.
    error InvalidInputArrays();
    /// @notice Error emitted when an invalid underlying token address is provided.
    error InvalidUnderlyingAddress();

    /// @notice Error emitted when caller is not the Core Branch Router.
    error UnrecognizedCore();
    /// @notice Error emitted when caller is not an active Branch Bridge Agent.
    error UnrecognizedBridgeAgent();
    /// @notice Error emitted when caller is not an active Branch Bridge Agent Factory.
    error UnrecognizedBridgeAgentFactory();
    /// @notice Error emitted when caller is not an active Port Strategy.
    error UnrecognizedPortStrategy();
    /// @notice Error emitted when caller is not an active Strategy Token.
    error UnrecognizedStrategyToken();
}
