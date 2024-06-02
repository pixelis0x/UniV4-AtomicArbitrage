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
import {Pool} from "v4-core/src/libraries/Pool.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {AtomicArbHook} from "../src/AtomicArbHook.sol";
import {AtomicArbRouter} from "../src/AtomicArbRouter.sol";

contract AtomicArbTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    AtomicArbHook atomicArbHook;
    PoolId atomicArbPoolId;
    PoolKey atomicArbPoolKey;
    PoolId hooklessPoolId;
    PoolKey hooklessPoolKey;
    AtomicArbRouter atomicArbRouter;

    // devaites price roughly for 1.3%
    function manipulatePriceOfHooklessPool() private {
        // hookless price before
        (uint160 sqrtPriceX96,,,) = manager.getSlot0(hooklessPoolId);
        // manipulate the price of the hookless pool to move it for 0.5%
        swap(hooklessPoolKey, true, 2 ether, ZERO_BYTES);

        // hookless price after
        (uint160 sqrtPriceX96After,,,) = manager.getSlot0(hooklessPoolId);
        // relative price change in percentage
        uint256 priceChange = getPriceFromX96(sqrtPriceX96) * 1000 / getPriceFromX96(sqrtPriceX96After);
        console.log("price change: %d", priceChange);
    }

    function getPriceFromX96(uint160 sqrtPriceX96) public pure returns (uint256) {
        return uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / 2 ** 96;
    }

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
        bytes memory afterInitializeParams = abi.encode(address(atomicArbRouter), 10000, 500);
        atomicArbPoolKey = PoolKey(currency0, currency1, 10000, 100, IHooks(address(atomicArbHook)));
        atomicArbPoolId = atomicArbPoolKey.toId();
        manager.initialize(atomicArbPoolKey, SQRT_PRICE_1_1, afterInitializeParams);

        // Create hookless pool
        hooklessPoolKey = PoolKey(currency0, currency1, 10000, 100, IHooks(address(0x0)));
        hooklessPoolId = hooklessPoolKey.toId();
        manager.initialize(hooklessPoolKey, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide liquidity to the Arb pool
        modifyLiquidityRouter.modifyLiquidity(
            atomicArbPoolKey, IPoolManager.ModifyLiquidityParams(-600, 600, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            atomicArbPoolKey, IPoolManager.ModifyLiquidityParams(-1200, 1200, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            atomicArbPoolKey,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(100), TickMath.maxUsableTick(100), 10 ether, 0),
            ZERO_BYTES
        );

        // Provide liquidity to the hookless pool
        modifyLiquidityRouter.modifyLiquidity(
            hooklessPoolKey, IPoolManager.ModifyLiquidityParams(-600, 600, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            hooklessPoolKey, IPoolManager.ModifyLiquidityParams(-1200, 1200, 10 ether, 0), ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            hooklessPoolKey,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(100), TickMath.maxUsableTick(100), 10 ether, 0),
            ZERO_BYTES
        );
    }

    function testDefaultSwapImpliesSameResult() public {
        bool zeroForOne = true;

        // Swap in the hookless pool
        BalanceDelta delta0 = swap(hooklessPoolKey, zeroForOne, -1 ether, ZERO_BYTES);

        // Swap in the Arb pool
        BalanceDelta delta1 = swap(atomicArbPoolKey, zeroForOne, -1 ether, ZERO_BYTES);

        assertEq(delta0.amount0(), delta1.amount0());
        assertEq(delta0.amount1(), delta1.amount1());
    }

    function testArbSwapTakesLessFee() public {
        bool zeroForOne = true;

        // manipulate the price of the hookless pool to move it for 0.5%
        manipulatePriceOfHooklessPool();

        // ERC20 balance before swap
        uint256 balance0Before = currency0.balanceOf(address(this));
        uint256 balance1Before = currency1.balanceOf(address(this));

        atomicArbRouter.arbSwap(atomicArbPoolKey, hooklessPoolKey, zeroForOne, -1 ether, ZERO_BYTES, ZERO_BYTES);

        // ERC20 balance after swap
        uint256 balance0After = currency0.balanceOf(address(this));
        uint256 balance1After = currency1.balanceOf(address(this));

        // profits are made
        assertGt(balance0After, balance0Before);
        // sending token is not sent since arbitrage is executed with flash accounting
        assertEq(balance1Before, balance1After);
    }

    function testArbSwapHasNoProfitWithNormalRouter() public {
        bool zeroForOne = true;

        // manipulate the price of the hookless pool to move it for 0.8%
        manipulatePriceOfHooklessPool();

        // try to perform profitable aritrage with 1 eth and ususal router
        uint256 balance0Before = currency0.balanceOf(address(this));
        uint256 balance1Before = currency1.balanceOf(address(this));

        BalanceDelta delta0 = swap(hooklessPoolKey, zeroForOne, -1 ether, ZERO_BYTES);

        // swap output value with defered priced pool
        int256 amountUnspecified = -delta0.amount1();
        BalanceDelta delta1 = swap(atomicArbPoolKey, !zeroForOne, amountUnspecified, ZERO_BYTES);

        // check amount out is lower than amount in
        assertLt(delta1.amount0(), -delta0.amount0());
        uint256 balance0After = currency0.balanceOf(address(this));
        uint256 balance1After = currency1.balanceOf(address(this));

        console.log("balance0Before: %d, balance0After: %d", balance0Before, balance0After);
        // no profit is made
        assertLt(balance0After, balance0Before);
        assertEq(balance1Before, balance1After);
    }
}
