// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {PoolModifyPositionTest} from "@uniswap/v4-core/contracts/test/PoolModifyPositionTest.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol"; //add this to the snippets (REMOVE WHEN ADDED)



contract CreateLiquidityExampleInputs{
    using CurrencyLibrary for Currency;

    // set the router address
    IPoolManager manager = IPoolManager(0x0DCd1Bf9A1b36cE34237eEaFef220932846BCD82); //add pool manager

    function run() external {
        address token0 = address(0x4ed7c70F96B99c776995fB64377f0d4aB3B0e1C1);//mUSDC deployed locally
        address token1 = address(0x59b670e9fA9D0A427751Af201D676719a970857b);//mUNI deployed locally

        // Using a hooked pool
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(token0), //update to wrap
            currency1: Currency.wrap(token1), //update to wrap
            fee: 4000,
            tickSpacing: 60,
            hooks: IHooks(address(0x3cC6198C897c87353Cb89bCCBd9b5283A0042a14))
        });

        //will need to add approvals for both tokens but b/c mock tokens don't have them it's okay
        //code here

        // approve tokens to the LP Router
        IERC20(token0).approve(address(manager), type(uint256).max);
        IERC20(token1).approve(address(manager), type(uint256).max);

        //modify the position and add liquidity
        manager.modifyPosition(pool, IPoolManager.ModifyPositionParams(-600, 600, 1 ether), abi.encode(msg.sender));

    }
}
