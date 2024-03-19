<!-- 1. pegged $1
   1. chainlink pricefeed.
   2. func to exchange eth&btc -> $$
2. stability (minting) : Algo (Decentralized)
   1. can only be minted with enough colateral
3. colateral: Crypto (Exogenous)
   1. wEth
   2. wBtc

engin: 0xaA8Db0C102a77408dC3f1f980A33bFF904cF2c0c : https://sepolia.etherscan.io/address/0xaA8Db0C102a77408dC3f1f980A33bFF904cF2c0c#code

dcs: 0x03dE20bB2369752cCA82dA142B27c51F6313b57D : https://sepolia.etherscan.io/address/0x03dE20bB2369752cCA82dA142B27c51F6313b57D#code

forge verify-contract 0xaA8Db0C102a77408dC3f1f980A33bFF904cF2c0c DSCEngine --watch --etherscan-api-key $ETHERSCAN_API_KEY --chain-id 11155111 --constructor-args $(cast abi-encode "constructor(address[],address[],address)" "[0xdd13E55209Fd76AfE204dBda4007C227904f0a81, 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063]" "[0x694AA1769357215DE4FAC081bf1f309aDC325306, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43]" 0x03dE20bB2369752cCA82dA142B27c51F6313b57D )

forge verify-contract 0x03dE20bB2369752cCA82dA142B27c51F6313b57D DecentralizedStableCoin --watch --etherscan-api-key $ETHERSCAN_API_KEY --chain-id 11155111 -->

# Stablecoin

The `stablecoin` project is a Solidity-based stablecoin framework developed using Foundry, designed to maintain a stable value pegged to $1 USD. This project utilizes Chainlink price feeds for accurate and decentralized price information, allowing for the exchange of ETH and BTC into stablecoin currency. The stablecoin emphasizes stability through an algorithmic minting process that requires sufficient collateral, supporting wETH and wBTC as collateral types.

## Features

1. `$1` **Peg**: Utilizes Chainlink price feeds to maintain a stable value pegged to $1 USD.

   - Chainlink price feed integration.
   - Functions to exchange ETH and BTC into stablecoin.

2. **Stability (Minting)**: Implements an algorithmic, decentralized approach to minting that requires sufficient collateral.

   - Minting is controlled and requires adequate collateral to ensure stability.

3. **Collateral**: Supports wETH and wBTC as exogenous collateral types.
   - Users can provide wETH or wBTC as collateral to mint stablecoins.

### Built With

This project was built using the following technologies:

- [Solidity](https://soliditylang.org/)
- [Foundry](https://getfoundry.sh/)
- [Chainlink](https://chain.link/)

### Prerequisites

Ensure you have the latest version of Foundry installed. For instructions on installing Foundry, visit [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation.html).

## Usage

For developers interested in integrating or building upon the `stablecoin` project, refer to the `/contracts` and `/scripts` directories for Solidity contracts and deployment scripts.

## Deployment on Sepolia

```shell
forge script script/DeployDSC.s.sol:DeployDSC --rpc-url $SEPOLIA_RPC_URL  --private-key $SEPOLIA_PRIVATE_KEY --broadcast --verify -vvv
```

for some reason the verification is not working directly
use the following command to verify the contract on etherscan

```shell
forge verify-contract 0xaA8Db0C102a77408dC3f1f980A33bFF904cF2c0c DSCEngine --watch --etherscan-api-key $ETHERSCAN_API_KEY --chain-id 11155111 --constructor-args $(cast abi-encode "constructor(address[],address[],address)" "[0xdd13E55209Fd76AfE204dBda4007C227904f0a81, 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063]" "[0x694AA1769357215DE4FAC081bf1f309aDC325306, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43]" DSC_Contract_address )

forge verify-contract 0x03dE20bB2369752cCA82dA142B27c51F6313b57D DecentralizedStableCoin --watch --etherscan-api-key $ETHERSCAN_API_KEY --chain-id 11155111
```

the project is deployed on Sepolia testnet

**DSCEngine**: [0xaA8Db0C102a77408dC3f1f980A33bFF904cF2c0c](https://sepolia.etherscan.io/address/0xaA8Db0C102a77408dC3f1f980A33bFF904cF2c0c#code)

**DecentralizedStableCoin**: [0x03dE20bB2369752cCA82dA142B27c51F6313b57D](https://sepolia.etherscan.io/address/0x03dE20bB2369752cCA82dA142B27c51F6313b57D#code)

## Roadmap

- [ ] write more Tests
- [ ] Add more collateral types beyond wETH and wBTC.
- [ ] Implement governance mechanisms for protocol adjustments.
- [ ] Explore and integrate additional DeFi protocols for broader utility.

## Contact

Your Name - [@ManaanAnsari](https://twitter.com/ManaanAnsari)

Project Link: [https://github.com/ManaanAnsari/stablecoin](https://github.com/ManaanAnsari/stablecoin)
