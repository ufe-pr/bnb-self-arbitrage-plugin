// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "algebra-core/interfaces/plugin/IAlgebraPlugin.sol";
import "algebra-core/interfaces/IAlgebraPool.sol";
import "algebra-core/AlgebraFactory.sol";
import "algebra-core/AlgebraPoolDeployer.sol";
import "forge-std/Test.sol";
import "./mocks/TestERC20.sol";
import "./BasePluginTestUtils.sol";
import "./BasePluginTestCallbacks.sol";

abstract contract BasePluginTest is Test, BasePluginTestUtils, BasePluginTestCallbacks {
    IAlgebraFactory factory;
    IAlgebraPool pool;
    address plugin;
    // Users for use in tests
    address constant user1 = address(1);
    address constant user2 = address(2);
    address constant user3 = address(3);
    address constant user4 = address(4);
    address constant user5 = address(5);
    address constant user6 = address(6);
    TestERC20 token0;
    TestERC20 token1;
    bytes internal constant ZERO_BYTES = bytes("");

    function _getPool() internal view override returns (IAlgebraPool) {
        return pool;
    }

    function _setInitialUserBalanceAndAllowance(address user, uint256 amount) internal {
        token0.transfer(user, amount);
        token1.transfer(user, amount);
        vm.prank(user);
        token0.approve(plugin, type(uint256).max);
        vm.prank(user);
        token1.approve(plugin, type(uint256).max);
        vm.prank(user);
        token0.approve(address(this), type(uint256).max);
        vm.prank(user);
        token1.approve(address(this), type(uint256).max);
    }

    function initialize() internal {
        uint256 amount = 2 ** 128;
        TestERC20 _tokenA = new TestERC20(amount);
        TestERC20 _tokenB = new TestERC20(amount);

        // pools alphabetically sort tokens by address
        // so align `token0` with `pool.token0` for consistency
        if (address(_tokenA) < address(_tokenB)) {
            token0 = _tokenA;
            token1 = _tokenB;
        } else {
            token0 = _tokenB;
            token1 = _tokenA;
        }

        address deployerAddr = vm.computeCreateAddress(address(this), uint256(vm.getNonce(address(this))) + 1);
        factory = new AlgebraFactory(deployerAddr);
        new AlgebraPoolDeployer(address(factory));
        factory.createPool(address(token0), address(token1));
        address poolAddress = factory.poolByPair(address(token0), address(token1));
        pool = IAlgebraPool(poolAddress);
        plugin = getPlugin(IAlgebraPool(address(pool)));
        pool.setPlugin(plugin);
        // Initialize after setting plugin to use default plugin config for pool
        pool.initialize(encodeSqrtPrice(1, 1));

        _setInitialUserBalanceAndAllowance(user1, 100 ether);
        _setInitialUserBalanceAndAllowance(user2, 100 ether);
        _setInitialUserBalanceAndAllowance(user3, 100 ether);
        _setInitialUserBalanceAndAllowance(user4, 100 ether);
        _setInitialUserBalanceAndAllowance(user5, 100 ether);
        _setInitialUserBalanceAndAllowance(user6, 100 ether);
    }

    function getPlugin(IAlgebraPool) internal virtual returns (address);
}
