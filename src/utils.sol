// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

using Math for uint256;

function encodeSqrtPrice(uint256 reserve1, uint256 reserve0) pure returns (uint160) {
    return uint160((reserve1 * 10 ** 18 / reserve0).sqrt() * 2 ** 96 / 10 ** 9);
}

function getMinTick(int24 tickSpacing) pure returns (int24) {
    return int24(SignedSafeMath.div(-887272, tickSpacing) * tickSpacing);
}

function getMaxTick(int24 tickSpacing) pure returns (int24) {
    return int24(SignedSafeMath.div(887272, tickSpacing) * tickSpacing);
}
