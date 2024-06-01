// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";

contract AtomicArbHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // Can be dynamically set in future. Min_fee can be even zero since most of the profits goes back to the pool
    uint24 public defaultFee;
    uint24 public arbFee;

    address public atomicArbRouterAddress;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    // function afterInitialize(address, PoolKey calldata, uint160, int24, bytes calldata)
    //     external
    //     virtual
    //     returns (bytes4)
    // {
    function afterInitialize(address, PoolKey calldata, uint160, int24, bytes calldata params)
        external
        override
        returns (bytes4)
    {
        (atomicArbRouterAddress, defaultFee, arbFee) = abi.decode(params, (address, uint24, uint24));

        return BaseHook.afterInitialize.selector;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Hook logic can be copied to other hooks conracts to be compatible wiht AtomicArbRouter
    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 _currentFee = msg.sender == atomicArbRouterAddress ? arbFee : defaultFee;
        uint256 overrideFee = _currentFee | uint256(LPFeeLibrary.OVERRIDE_FEE_FLAG);

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, uint24(overrideFee));
    }
}
