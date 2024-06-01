// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/src/types/BalanceDelta.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolTestBase} from "v4-core/src/test/PoolTestBase.sol";
import {CurrencySettleTake} from "v4-core/src/libraries/CurrencySettleTake.sol";

bytes constant ZERO_BYTES = new bytes(0);

contract AtomicArbRouter is PoolTestBase {
    using CurrencyLibrary for Currency;
    using CurrencySettleTake for Currency;
    using Hooks for IHooks;

    constructor(IPoolManager _manager) PoolTestBase(_manager) {}

    error NoSwapOccurred();

    struct CallbackData {
        address sender;
        TestSettings testSettings;
        PoolKey key0;
        PoolKey key1;
        bytes hookData0;
        bytes hookData1;
        bool zeroForOne;
        int256 amountSpecified;
    }

    struct TestSettings {
        bool takeClaims;
        bool settleUsingBurn;
    }

    // function swap(
    //     PoolKey memory key,
    //     IPoolManager.SwapParams memory params,
    //     TestSettings memory testSettings,
    //     bytes memory hookData
    // ) external payable returns (BalanceDelta delta) {
    //     delta = abi.decode(
    //         manager.unlock(abi.encode(CallbackData(msg.sender, testSettings, key, params, hookData))), (BalanceDelta)
    //     );

    //     uint256 ethBalance = address(this).balance;
    //     if (ethBalance > 0) CurrencyLibrary.NATIVE.transfer(msg.sender, ethBalance);
    // }

    // function performing arbitrage between two pools
    // donates 90% of the profit to the second pool
    function arbSwap(
        PoolKey memory key0,
        PoolKey memory key1,
        bool zeroForone,
        int256 amountSpecified,
        bytes memory hookData0,
        bytes memory hookData1
    ) external payable returns (uint256 profit) {
        // perform 1st swap
        abi.decode(
            manager.unlock(
                abi.encode(
                    CallbackData(
                        msg.sender,
                        TestSettings(false, false),
                        key0,
                        key1,
                        hookData0,
                        hookData1,
                        zeroForone,
                        amountSpecified
                    )
                )
            ),
            (BalanceDelta)
        );
    }

    // @dev unlockCallback is called by the pool manager after calling unlock() to execute the hook logic
    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        require(msg.sender == address(manager));

        CallbackData memory data = abi.decode(rawData, (CallbackData));

        (,, int256 deltaBefore0) = _fetchBalances(data.key0.currency0, data.sender, address(this));
        (,, int256 deltaBefore1) = _fetchBalances(data.key0.currency1, data.sender, address(this));

        require(deltaBefore0 == 0, "deltaBefore0 is not equal to 0");
        require(deltaBefore1 == 0, "deltaBefore1 is not equal to 0");

        // perform 1st swap and use it result delta to perform 2nd swap
        BalanceDelta delta0 =
            manager.swap(data.key0, IPoolManager.SwapParams(data.zeroForOne, data.amountSpecified, 0), data.hookData0);

        if (delta0.amount0() == 0 && delta0.amount1() == 0) revert NoSwapOccurred();

        int128 amountUnspecified = data.zeroForOne ? delta0.amount1() : delta0.amount0();
        // perform 2nd swap with output of 1st swap
        manager.swap(data.key1, IPoolManager.SwapParams(!data.zeroForOne, amountUnspecified, 0), data.hookData1);

        (,, int256 deltaAfter0) = _fetchBalances(data.key0.currency0, data.sender, address(this));
        (,, int256 deltaAfter1) = _fetchBalances(data.key0.currency1, data.sender, address(this));

        if (data.zeroForOne) {
            require(data.amountSpecified < 0, "amountSpecified should be negative");
            require(deltaAfter0 > 0, "noProfit");
            require(deltaAfter1 == 0, "intermediate arbitrage asset should not be left");
        } else {
            require(data.amountSpecified < 0, "amountSpecified should be negative");
            require(deltaAfter0 > 0, "noProfit");
            require(deltaAfter1 == 0, "intermediate arbitrage asset should not be left");
        }

        // estimate swap profit
        uint256 profit = data.zeroForOne ? uint256(-deltaAfter0) : uint256(-deltaAfter1);
        uint256 poolDonateAmount = profit * 9 / 10;
        uint256 arbitragerProfit = profit - poolDonateAmount;

        Currency donateCurrency = data.zeroForOne ? data.key1.currency0 : data.key1.currency1;

        // donate 90% of the profit to the second pool
        if (data.zeroForOne) {
            manager.donate(data.key1, 0, poolDonateAmount, ZERO_BYTES);
        } else {
            manager.donate(data.key1, poolDonateAmount, 0, ZERO_BYTES);
        }

        donateCurrency.settle(manager, data.sender, arbitragerProfit, data.testSettings.settleUsingBurn);

        // if (deltaAfter0 > 0) {
        //     data.key.currency0.take(manager, data.sender, uint256(deltaAfter0), data.testSettings.takeClaims);
        // }
        // if (deltaAfter1 > 0) {
        //     data.key.currency1.take(manager, data.sender, uint256(deltaAfter1), data.testSettings.takeClaims);
        // }

        return abi.encode((profit));
    }
}
