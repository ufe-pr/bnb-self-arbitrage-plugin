// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "algebra-core/libraries/TickMath.sol";
import "src/SelfArbitragePlugin.sol";
import "src/utils.sol";
import "./BasePluginTest.sol";

contract SelfArbitragePluginTest is BasePluginTest {
    SelfArbitragePlugin sap;
    TestERC20 eToken;
    IAlgebraPool poolEto0;
    IAlgebraPool poolEto1;

    function getPlugin(IAlgebraPool) internal override returns (address) {
        TestERC20 externalToken = new TestERC20(2 ** 128);
        eToken = externalToken;
        sap = new SelfArbitragePlugin(address(pool), address(eToken));
        return address(sap);
    }

    function setUp() public {
        eToken = new TestERC20(2 ** 128);

        initialize();
        pool.setFee(0);

        address user = user1;
        int24 minTick = _minTick();
        int24 maxTick = _maxTick();

        eToken.transfer(user, 100 ether);
        vm.prank(user);
        eToken.approve(plugin, type(uint256).max);
        vm.prank(user);
        eToken.approve(address(this), type(uint256).max);

        address a = factory.createPool(address(token0), address(eToken));
        address b = factory.createPool(address(token1), address(eToken));
        poolEto0 = IAlgebraPool(a);
        poolEto1 = IAlgebraPool(b);
        uint160 four1 = encodeSqrtPrice(4, 1);
        uint160 one4 = encodeSqrtPrice(1, 4);
        poolEto0.initialize(address(token0) < address(eToken) ? four1 : one4);
        poolEto1.initialize(address(token1) < address(eToken) ? four1 : one4);

        pool.mint(address(this), user, minTick, maxTick, 10 ** 10, abi.encode(address(this)));
        poolEto0.mint(address(this), user, minTick, maxTick, 10 ** 18, abi.encode(address(this)));
        poolEto1.mint(address(this), user, minTick, maxTick, 10 ** 18, abi.encode(address(this)));

        // Supply tokens to use for arbitrage to plugin
        token0.transfer(address(sap), 1000);
        token1.transfer(address(sap), 1000);
    }

    modifier _makesProfit() {
        uint256 initialBalance0 = token0.balanceOf(plugin);
        uint256 initialBalance1 = token1.balanceOf(plugin);
        uint256 initialBalanceE = eToken.balanceOf(plugin);

        _;
        uint256 finalBalance0 = token0.balanceOf(plugin);
        uint256 finalBalance1 = token1.balanceOf(plugin);
        uint256 finalBalanceE = eToken.balanceOf(plugin);
        console.log("Initial balances: ", initialBalance0, initialBalance1, initialBalanceE);
        console.log("Final balances:   ", finalBalance0, finalBalance1, finalBalanceE);
        assertGe(finalBalance0, initialBalance0, "Token0 balance should be greater or equal");
        assertGe(finalBalance1, initialBalance1, "Token1 balance should be greater or equal");
        assertGe(finalBalanceE, initialBalanceE, "External token balance should be greater or equal");
    }

    function test_setup() external _makesProfit {
        console.log("Setup works");
    }

    function test_SimpleArbTrade() public _makesProfit {
        vm.skip(true);
        pool.swapWithPaymentInAdvance(
            address(this), user1, false, 10 ** 9, TickMath.MAX_SQRT_RATIO - 1, abi.encode(user1)
        );
    }

    function test_SimpleArbTrade2() public _makesProfit {
        vm.skip(true);
        poolEto0.swapWithPaymentInAdvance(
            address(this), user1, false, 10 ** 10, TickMath.MAX_SQRT_RATIO - 1, abi.encode(user1)
        );
        pool.swapWithPaymentInAdvance(
            address(this), user1, false, 10 ** 9, TickMath.MAX_SQRT_RATIO - 1, abi.encode(user1)
        );
    }

    function random(uint256 n) private view returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(block.timestamp, n))) % 255);
    }

    function testFuzz_SwapsShouldMakeProfit(uint16 n) public _makesProfit {
        for (uint i = 1; i < n; i++) {
            if (random(i) % i == 0) {
                bool zto1 = random(i ** 2) % i == 0;
                poolEto0.swapWithPaymentInAdvance(
                    address(this),
                    user1,
                    zto1,
                    int256(10 ** (random(i ** 3) % 10)),
                    !zto1 ? TickMath.MAX_SQRT_RATIO - 1 : TickMath.MIN_SQRT_RATIO + 1,
                    abi.encode(user1)
                );
            } else {
                bool zto1 = random(i ** 4) % i == 0;
                poolEto1.swapWithPaymentInAdvance(
                    address(this),
                    user1,
                    zto1,
                    10 ** 9,
                    !zto1 ? TickMath.MAX_SQRT_RATIO - 1 : TickMath.MIN_SQRT_RATIO + 1,
                    abi.encode(user1)
                );
            }
        }
        pool.swapWithPaymentInAdvance(
            address(this), user1, false, 10 ** 9, TickMath.MAX_SQRT_RATIO - 1, abi.encode(user1)
        );
    }
}
