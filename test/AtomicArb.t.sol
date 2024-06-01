// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {AtomicArbHook} from "../src/AtomicArbHook.sol";
import {AtomicArbRouter} from "../src/AtomicArbRouter.sol";

contract AtomicArbTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    AtomicArbHook atomicArbHook;
    PoolId atomicArbPoolId;
    PoolKey atomicArbPoolKey;
    PoolId hooklessPoolId;
    PoolKey hooklessPoolKey;
    AtomicArbRouter atomicArbRouter;

    function setUp() public {
        // Creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();

        // deploy the atomic arb router
        atomicArbRouter = new AtomicArbRouter(IPoolManager(address(manager)));

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_INITIALIZE_FLAG);
        (address arbHookAddress, bytes32 salt) =
            HookMiner.find(address(this), flags, type(AtomicArbHook).creationCode, abi.encode(address(manager)));
        atomicArbHook = new AtomicArbHook{salt: salt}(IPoolManager(address(manager)));
        require(address(atomicArbHook) == arbHookAddress, "AtomicArbHook: hook address mismatch");

        // Create the pool
        bytes memory afterInitializeParams = abi.encode(address(atomicArbRouter), 3000, 500);
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(address(atomicArbHook)));
        atomicArbPoolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, afterInitializeParams);

        // Create hookless pool
        hooklessPoolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(address(0x0)));
        hooklessPoolId = hooklessPoolKey.toId();
        manager.initialize(hooklessPoolKey, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide liquidity to the Arb pool
        modifyLiquidityRouter.modifyLiquidity(key, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether, 0), ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether, 0),
            ZERO_BYTES
        );

        // Provide liquidity to the hookless pool
        modifyLiquidityRouter.modifyLiquidity(
            hooklessPoolKey, IPoolManager.ModifyLiquidityParams(-60, 60, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            hooklessPoolKey, IPoolManager.ModifyLiquidityParams(-120, 120, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            hooklessPoolKey,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10 ether, 0),
            ZERO_BYTES
        );
    }

    function testDefaultSwapImpliesSameResult() public {
        bool zeroForOne = true;

        // Swap in the hookless pool
        BalanceDelta delta0 = swap(hooklessPoolKey, zeroForOne, 1 ether, ZERO_BYTES);

        // Swap in the Arb pool
        BalanceDelta delta1 = swap(key, zeroForOne, 1 ether, ZERO_BYTES);

        assertEq(delta0.amount0(), delta1.amount0());
        assertEq(delta0.amount1(), delta1.amount1());
    }
}
