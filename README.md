# Algebra Self Arbitrage Plugin

While arbitraging opportunities are an important factor in keeping AMM pools relatively stable and reducing impermanent loss for Liquidity providers, they open up these pools to be exploited by bad MEV actors, frequently sandwiching user trades and resulting in worse trading experience for traders as they don't get the best price for their trades. There are several ways to mitigate this MEV and this paper focuses on one of them: Self Arbitrage.
Previously, this was a feature that was very complex to implement and would most likely require creating a new AMM protocol or a new Blockchain altogether. But with the introduction of plugins, a new plethora of possibilities open up.

This plugin seeks to explore this possibility and provides an experimental implementation. It should not be used on mainnet until it has gone through various testing and auditing phases.

Sources of inspiration for this plugin are:
https://github.com/cryptoalgebra/integral-team-plugins
https://github.com/emmaguo13/backrunning-hook

## Usage

### Deploy the plugin

The plguin constructor accepts 2 arguments.

1. `pool`: This is the address of the pool for which the plugin is deployed.
2. `externalToken`: This is the address of the 3rd token that will be used to complete the triangle for the triangular arbitrage that the plugin executes. For example, if we have a pool of `USDC` against `BNB`, the external token could be `DAI`.

### Configuring the pool

Call `setPlugin` on the `pool` in the plugin's constructor with the plugin's address as an argument.
Then sit back and monitor plugin activity.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
