
<div align="center">

   <h1>TheEqualizer</h1>


   <h2>Atomic arbitrage router and hook for Uniswap v4 🦄</h2>


</div>

Once **Uniswap V4** is released, it will host a multitute of *pools* for the same *tokens* but with different *hooks*. This will lead to bunch of *pools* experiencing price deviations, allowing for swaps between them with low transaction costs due to flash accounting (all *pools' tokens* stored in a *single contract*). 

However, the majority of these pools might not attract sufficient attention from **solvers/arbitragers** due to a lack of liquidity and fees not allowing to perform profitable trade. At the same time, having trades is crucial for these pools as they might use hooks for *TWAP,  rebalancing,* and other purposes. 

The proposed solution suggests discounting fee rates and distibuting only small share of arbitrage profit to arbitrager. It consists of two components:
- **Discounted Fee Hook**:  This allows setting discounted fee for *Arbitrager* who is using *Arbitrage Router* (aka **TheEqualizer**) to perform trades much sooner than any *MEV actor*. The fee can be reduced by 10x or even set to 0, enabling *Arbitrage Router* to **fron-trun toxic arbitrage** before it becomes possible for later
- **Arbitrage Router**: Takes 4 essential arguments:  **amount**, **tradeDirection**,  **pool0** and **pool1** (one with actual and outdated prices). It performs trades and estimates the **profit**. In case of positive outcome, **minor 10%** share  (can be lowered) goes as a bounty to the **initiator**, while the **major 90%** goes back to **LPs** utilizing *.donate()* function available in **UniV4**

Most of the slippage still benefits *Liquidity Providers*. So **Pool Managers** win from updated prices and triggered hooks, **Liquidity Providers** receive more fees **capturing LVR**, and **arbitragers** are able to execute arbitrage more frequently

---

## Set up

*requires [foundry](https://book.getfoundry.sh)*

```
forge install
forge test
```
---

Additional resources:

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

[v4-by-example](https://v4-by-example.org)

