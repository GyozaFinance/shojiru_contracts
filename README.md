# Shojiru.finance contracts!

This is the repo for Shojiru.finance's contracts.

## How to deploy?
Deploy main contracts and add a zappy-tlos vault:

```bash
npx hardhat run scripts/deploy-contracts.js --network telos_mainnet
````
Add more vaults (check the code to specify which one):

````bash
npx hardhat run scripts/deploy-new-vault.js --network telos_mainnet
````

There are different ways to manage your private key : if you save it in the environment as the `WALLET` variable, Hardhat will pick it up.

*Developping complex protocols on Telos is still hacky at the moment, and not all tools designed to work with GETH function with Telos. For instance, we started with eth-brownie, but we had to switch to hardhat after Jesse pushed a fix (thanks Jesse!) that allowed us to test our deploy-scripts with a fork of the chain. 

Since there are still some bugs that may break the scripts (adding liquidity seems problematic for some reason). Move with caution when modifying the scripts, and expect to do some stuff "by hand" (like adding liquidity) if needed.

## Architecture

Contracts inherit from Pacoca\'s architecture. Since one diagram is clearer than a long text, you can see the organisation here:

![architecture](https://i.ibb.co/ThWTkPZ/shojiru-Contracts.png)

