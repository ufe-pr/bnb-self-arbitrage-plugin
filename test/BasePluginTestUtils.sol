// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "algebra-core/interfaces/plugin/IAlgebraPlugin.sol";
import "algebra-core/interfaces/IAlgebraPool.sol";
import "algebra-core/interfaces/callback/IAlgebraMintCallback.sol";
import "algebra-core/interfaces/callback/IAlgebraSwapCallback.sol";
import "algebra-core/interfaces/callback/IAlgebraFlashCallback.sol";
import "algebra-core/AlgebraFactory.sol";
import "algebra-core/AlgebraPoolDeployer.sol";
import "./mocks/MockFactory.sol";
import "./mocks/MockPool.sol";
import "./mocks/TestERC20.sol";
import "forge-std/Test.sol";
import "src/utils.sol";

abstract contract BasePluginTestUtils {
    function _getPool() internal view virtual returns (IAlgebraPool);

    function getKeyForPosition(address owner, int24 bottomTick, int24 topTick) internal pure returns (bytes32 key) {
        assembly {
            key := or(shl(24, or(shl(24, owner), and(bottomTick, 0xFFFFFF))), and(topTick, 0xFFFFFF))
        }
    }

    function _minTick() internal view returns (int24) {
        return getMinTick(_getPool().tickSpacing());
    }

    function _maxTick() internal view returns (int24) {
        return getMaxTick(_getPool().tickSpacing());
    }
}
