// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "algebra-core/interfaces/callback/IAlgebraMintCallback.sol";
import "algebra-core/interfaces/callback/IAlgebraSwapCallback.sol";
import "algebra-core/interfaces/callback/IAlgebraFlashCallback.sol";
import "./mocks/MockFactory.sol";
import "./mocks/MockPool.sol";
import "./mocks/TestERC20.sol";
import "algebra-core/interfaces/IAlgebraPool.sol";

abstract contract BasePluginTestCallbacks is IAlgebraSwapCallback, IAlgebraMintCallback, IAlgebraFlashCallback {
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
        address sender = abi.decode(data, (address));

        if (amount0Delta > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token0()).transferFrom(sender, msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token1()).transferFrom(sender, msg.sender, uint256(amount1Delta));
        }
    }

    function algebraMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        address sender = abi.decode(data, (address));

        if (amount0Owed > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token0()).transferFrom(sender, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token1()).transferFrom(sender, msg.sender, amount1Owed);
        }
    }

    function algebraFlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external override {
        (address sender, uint256 amount0, uint256 amount1) = abi.decode(data, (address, uint256, uint256));

        if (amount0 > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token0()).transferFrom(sender, msg.sender, amount0 + fee0);
        }
        if (amount1 > 0) {
            IERC20Minimal(IAlgebraPool(msg.sender).token1()).transferFrom(sender, msg.sender, amount1 + fee1);
        }
    }
}
