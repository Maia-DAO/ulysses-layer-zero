//SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import "../helpers/ImportHelper.sol";

import "../helpers/RootForkHelper.t.sol";

contract ERC20hTokenBranchFactoryTest is Test {
    using ERC20hTokenBranchFactoryHelper for ERC20hTokenBranchFactory;

    ERC20hTokenBranchFactory public factory;

    address internal localPortAddress = address(0xCAFE);
    BranchPort internal localPort = BranchPort(payable(localPortAddress));

    MockERC20 public mockNativeToken;
    ERC20hToken public nativeHToken;

    address internal coreBranchRouterAddress = address(this);
    CoreBranchRouter internal coreBranchRouter = CoreBranchRouter(coreBranchRouterAddress);

    /*//////////////////////////////////////////////////////////////
                               TEST SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Setups up the testing suite for call and payableCall
    function setUp() public {
        factory = factory._deploy(localPort, "Test", "TST");

        mockNativeToken = new MockERC20("Test Token", "TTK", 18);

        factory._init(address(mockNativeToken), coreBranchRouter);

        nativeHToken = factory.hTokens(0);
    }

    function invariant_metadata() public view {
        factory.check_deploy(localPort, "Test", "TST", address(0));
    }

    function test_constructor(BranchPort _port, string memory _name, string memory _symbol, address _owner)
        public
        returns (ERC20hTokenBranchFactory newFactory)
    {
        if (_owner == address(0)) _owner = address(1);
        if (address(_port) == address(0)) _port = BranchPort(payable(address(1)));

        vm.prank(_owner);
        newFactory = newFactory._deploy(_port, _name, _symbol, _owner);
    }

    function test_initialize_alreadyInitalized(address _caller) public {
        if (_caller == address(0)) _caller = address(1);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(_caller);
        factory.initialize(address(mockNativeToken), coreBranchRouterAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            TEST PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_unautharized(address _caller) public {
        test_initialize_unautharized(address(mockNativeToken), coreBranchRouterAddress, _caller);
    }

    function test_initialize_unautharized(address nativeToken, address router, address _caller) public {
        if (_caller == address(0) || _caller == address(this)) _caller = address(1);

        ERC20hTokenBranchFactory newFactory = test_constructor(localPort, "Test", "TST", _caller);

        vm.expectRevert(Ownable.Unauthorized.selector);
        newFactory.initialize(address(nativeToken), router);
    }

    function test_createToken_unautharized(address _caller) public {
        test_createToken_unautharized(
            mockNativeToken.name(), mockNativeToken.symbol(), mockNativeToken.decimals(), true, _caller
        );
    }

    function test_createToken_unautharized(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        bool _addPrefix,
        address _caller
    ) public {
        if (_caller == address(this)) _caller = address(1);

        vm.expectRevert(IERC20hTokenBranchFactory.UnrecognizedCoreRouter.selector);
        vm.prank(_caller);
        factory.createToken(_name, _symbol, _decimals);
    }

    /*//////////////////////////////////////////////////////////////
                           TEST GET HTOKENS
    //////////////////////////////////////////////////////////////*/

    function test_getHTokens() public {
        ERC20hToken[] memory hTokens = factory.getHTokens();

        assertEq(hTokens.length, 1);
        assertEq(address(hTokens[0]), address(factory.hTokens(0)));
        assertEq(address(hTokens[0]), address(nativeHToken));
    }

    /*//////////////////////////////////////////////////////////////
                           TEST CREATE TOKEN
    //////////////////////////////////////////////////////////////*/

    function test_createToken() public {
        test_createToken(mockNativeToken.name(), mockNativeToken.symbol(), mockNativeToken.decimals());
    }

    function test_createToken(string memory _name, string memory _symbol, uint8 _decimals) public {
        uint256 hTokensLength = factory.getHTokens().length;

        ERC20hToken newToken = factory.createToken(_name, _symbol, _decimals);

        assertEq(factory.getHTokens().length, hTokensLength + 1);
        assertEq(address(newToken), address(factory.hTokens(hTokensLength)));
        assertEq(newToken.owner(), localPortAddress);
        assertEq(newToken.decimals(), _decimals);

        assertEq(newToken.name(), _name);
        assertEq(newToken.symbol(), _symbol);
    }
}
