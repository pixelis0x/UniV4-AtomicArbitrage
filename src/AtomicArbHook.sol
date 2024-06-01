// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";

contract AtomicArbHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    uint128 public constant DEFAULT_FEE = 3000; // default fee is 0.3%
    uint128 public constant MIN_FEE = 100; // minimal fee is 0.01%

    address public atomicArbAddress;


    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function afterInitialize(PoolKey calldata key, bytes calldata) external override {
        atomicArbAddress = abi.decode(calldata, (address));
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

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 _currentFee = msg.sender == atomicArbAddress ? 0 : MIN_FEE;
        uint256 overrideFee = _currentFee | uint256(LPFeeLibrary.OVERRIDE_FEE_FLAG);

        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, uint24(_currentFee));
    }
}
