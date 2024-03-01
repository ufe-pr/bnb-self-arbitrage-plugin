// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import {AlgebraPlugin, IAlgebraPlugin} from "./base/AlgebraPlugin.sol";
import {IAlgebraPool} from "algebra-core/interfaces/IAlgebraPool.sol";
import {IAlgebraFactory} from "algebra-core/interfaces/IAlgebraFactory.sol";
import "algebra-core/interfaces/callback/IAlgebraSwapCallback.sol";
import "algebra-core/interfaces/callback/IAlgebraFlashCallback.sol";
import "algebra-core/interfaces/IERC20Minimal.sol";
import {PoolInteraction} from "./libraries/PoolInteraction.sol";
import {PluginConfig, Plugins} from "./types/PluginConfig.sol";
import "./utils.sol";
import "forge-std/console.sol";

contract SelfArbitragePlugin is AlgebraPlugin, IAlgebraSwapCallback {
    error onlyPoolAllowed();
    error onlyAdministratorAllowed();
    error onlyWhitelistedAllowed();

    event Whitelisted(address indexed _address);
    event Unwhitelisted(address indexed _address);

    // TODO: Research ways to get route to provide best arbitrage
    // instead of fixing it to a single token
    address public externalToken;

    IAlgebraFactory public immutable factory;

    bytes32 public constant SELF_ARBITRAGE_ALGEBRA_ADMINISTRATOR = keccak256("WHITELIST_ALGEBRA_ADMINISTRATOR");
    uint160 private constant SQRT_P_1_1 = 79228162514264337593543950336;
    uint160 private constant SQRT_P_4_1 = 158456325028528675187087900672;
    uint160 private constant SQRT_P_1_4 = 39614081257132168796771975168;
    bytes private constant ZERO_BYTES = bytes("");

    PluginConfig private constant _defaultPluginConfig = PluginConfig.wrap(uint8(Plugins.AFTER_SWAP_FLAG));

    /// @notice the Algebra Integral pool
    IAlgebraPool public immutable pool;

    modifier onlyPool() {
        _checkOnlyPool();
        _;
    }

    modifier onlyAdministrator() {
        if (!factory.hasRoleOrOwner(SELF_ARBITRAGE_ALGEBRA_ADMINISTRATOR, msg.sender)) {
            revert onlyAdministratorAllowed();
        }
        _;
    }

    constructor(address _pool, address _externalToken) {
        pool = IAlgebraPool(_pool);
        factory = IAlgebraFactory(pool.factory());
        externalToken = _externalToken;
    }

    function defaultPluginConfig() external pure override returns (uint8 pluginConfig) {
        return _defaultPluginConfig.unwrap();
    }

    /// @inheritdoc IAlgebraPlugin
    function beforeInitialize(address, uint160) external onlyPool returns (bytes4) {
        PoolInteraction.changePluginConfigIfNeeded(pool, _defaultPluginConfig);
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    function _checkOnlyPool() internal view {
        if (msg.sender != address(pool)) revert onlyPoolAllowed();
    }

    function _swapAtoB(int256 amountRequired, uint160 limitSqrtPrice, address tokenA, address tokenB)
        internal
        returns (int256 amountADelta, int256 amountBDelta)
    {
        IAlgebraPool pairPool = IAlgebraPool(factory.poolByPair(tokenA, tokenB));
        (int256 amount0Delta, int256 amount1Delta) = pairPool.swapWithPaymentInAdvance(
            address(this), address(this), tokenA < tokenB, amountRequired, limitSqrtPrice, abi.encode(address(this))
        );

        if (tokenA < tokenB) {
            return (amount0Delta, amount1Delta);
        } else {
            return (amount1Delta, amount0Delta);
        }
    }

    function _arbitrageToken1() internal {
        address _token0 = pool.token0();
        address _token1 = pool.token1();
        // To save on SLOAD
        address _externalToken = externalToken;

        //Flash swap token1 for token0
        (int256 amountOfToken1UsedUp, int256 amount0Delta) =
            _swapAtoB(int256(IERC20Minimal(_token1).balanceOf(address(this))), encodeSqrtPrice(2, 1), _token1, _token0);

        //Swap token0 for externalToken
        (, int256 amount2Delta) = _swapAtoB(-amount0Delta, encodeSqrtPrice(1, 10), _token0, _externalToken);

        //Swap externalToken for token1 (pool1Id)
        (, int256 amountOfToken1Retrieved) = _swapAtoB(-amount2Delta, encodeSqrtPrice(1, 10), _externalToken, _token1);

        // TODO: figure out how to skip the arbitrage above if not profitable in advance
        require(-amountOfToken1Retrieved >= amountOfToken1UsedUp, "No profit");
    }

    function _arbitrageToken0() internal {
        address _token0 = pool.token0();
        address _token1 = pool.token1();
        // To save on SLOAD
        address _externalToken = externalToken;

        // swap token0 for token1
        (int256 amountOfToken0UsedUp, int256 amount1Delta) =
            _swapAtoB(int256(IERC20Minimal(_token1).balanceOf(address(this))), SQRT_P_1_1, _token0, _token1);

        //Swap token1 for externalToken
        (, int256 amount2Delta) = _swapAtoB(-amount1Delta, SQRT_P_4_1 + 1, _token1, _externalToken);

        //Swap externalToken for token0 (pool1Id)
        (, int256 amountOfToken0Retrieved) = _swapAtoB(-amount2Delta, encodeSqrtPrice(10, 1), _externalToken, _token0);

        // TODO: figure out how to skip the arbitrage above if not profitable in advance
        require(-amountOfToken0Retrieved >= amountOfToken0UsedUp, "No profit");
    }

    /// @inheritdoc IAlgebraPlugin
    function afterSwap(address sender, address, bool zeroToOne, int256, uint160, int256, int256, bytes calldata)
        external
        override
        returns (bytes4)
    {
        if (sender != address(this)) {
            if (zeroToOne) {
                _arbitrageToken1();
            } else {
                _arbitrageToken0();
            }
        }
        return IAlgebraPlugin.afterSwap.selector;
    }

    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        address sender = abi.decode(data, (address));

        if (amount0Delta > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
        }
    }
}
