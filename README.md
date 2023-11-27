# Maia DAO - Ulysses audit details

### Ulysses

**[Ulysses](https://v2-docs.maiadao.io/protocols/Ulysses/introduction)** scope for this audit focuses on Ulysses Omnichain our Liquidity and Execution Platform built on top of Layer Zero.

This can be divided in two main features:

1. **[Virtualized liquidity](https://v2-docs.maiadao.io/protocols/Ulysses/overview/omnichain/virtual-liquidity)** is achieved by connecting [Ports](https://v2-docs.maiadao.io/protocols/Ulysses/overview/omnichain/ports) within a Pool and Spoke architecture, comprising both the Root Chain and multiple Branch Chains. These contracts are responsible for managing token balances and address mappings across environments. In addition, means that an asset deposited from a specific chain, is recognized as a different asset from the "same" asset but from a different chain (ex: arb ETH is different from mainnet ETH).

2. **Arbitrary Cross-Chain Execution** is facilitated by an expandable set of routers such as the Multicall Root Router that can be permissionlessly deployed through the Bridge Agent Factories. For more insight on Bridge Agents, please refer to our documentation [here](https://v2-docs.maiadao.io/protocols/Ulysses/overview/omnichain/bridge-agents). Our [Virtual Account](https://v2-docs.maiadao.io/protocols/Ulysses/overview/omnichain/virtual-accounts) contract simplifies remote asset management and interaction within the Root chain.

## Links

##### **Previous audits:**

Previous Audits by Zellic and Code4rena can be found in the [audits](https://github.com/code-423n4/2023-05-maia/tree/main/audits) folder.
There are three audits, two of them featuring Ulysses:

- [Zellic Audit](https://github.com/code-423n4/2023-05-maia/tree/main/audits/Ulysses%20Protocol%20May%202023%20-%20Zellic%20Audit%20Report.pdf)
- [Code 4rena Contest](https://code4rena.com/reports/2023-05-maia)
- [Code 4rena Contest](https://code4rena.com/reports/2023-09-maia)

##### **Other links:**

- **[Documentation](https://v2-docs.maiadao.io/)**
- **[Website](https://maiadao.io/)**
- **[Twitter](https://twitter.com/MaiaDAOEco)**
- **[Discord](https://discord.gg/maiadao)**

# Additional Context

### Describe any novel or unique curve logic or mathematical models implemented in the contracts
Branch / Root Bridge Agent and Bridge Agent Executor packed payload decoding and encoding.

### Please list specific ERC20 that your protocol is anticipated to interact with. Could be "any" (literally anything, fee on transfer tokens, ERC777 tokens and so forth) or a list of tokens you envision using on launch.
Arbitrum's deployment of UniswapV3 and Balancer.

### Please list specific ERC721 that your protocol is anticipated to interact with.
Virtual Account should be able to keep and use UniswapV3 NFT's.

### Which blockchains will this code be deployed to, and are considered in scope for this audit?
Root contracts are to be deployed on Arbitrum and Branch contracts in several L1 and L2 networks such as Ethereum mainnet, Polygon, Base and Optimism

### Please list all trusted roles (e.g. operators, slashers, pausers, etc.), the privileges they hold, and any conditions under which privilege escalation is expected/allowable:
Only our governance has access to key admin state changing functions present in the `RootPort` and `CoreRootRouter` and the Root Bridge Agent deployer (referred to in the codebase as manager) is responsible for allowing new branch chains to connect to their Root Bridge Agent in order to prevent griefing.

### In the event of a DOS, could you outline a minimum duration after which you would consider a finding to be valid? This question is asked in the context of most systems' capacity to handle DoS attacks gracefully for a certain period.
Unless there is the need to upgrade and migrate any component of Ulysses via governance ( e.g. Bridge Agents or Core Routers) downtime should be negligible to ensure assets are available at any time to their different users.

### Is any part of your implementation intended to conform to any EIP's? If yes, please list the contracts in this format:
  - `ERC20hTokenBranch`: Should comply with `ERC20/EIP20`
  - `ERC20hTokenRoot`: Should comply with `ERC20/EIP20`

## Attack ideas (Where to look for bugs)

- Double spending of deposit and settlement nonces / assets (Bridge Agents and Bridge Agent Executors).
- Griefing of user deposits and settlements (Bridge Agents).
- Bricking of Bridge Agent and subsequent Omnichain dApps that rely on it.
- Circumventing Bridge Agent's encoding rules to manipulate remote chain state.

## Main invariants

- The total balance of any given Virtualized Liquidity Token should never be greater than the amount of Underlying Tokens deposited in the asset's origin chain Branch Port.
- A Deposit / Settlement can never be redeemable and retryable at the same time.

# Tests

**Here is an example of a full script to run the first time you build the contracts in both Windows and Linux:**

- Remove `.example` from the provided `.env` file and edit the uncommented `RPC` and `RPC_API_KEY` values to your preferences. These values will be used by our fork testing suite.

```bash
forge install
forge build
forge test --gas-report
forge snapshot --diff
```

Default gas price is 10,000, but you can change it by adding `--gas-price <gas price>` to the command or by setting the `gas_price` property in the [foundry.toml](https://github.com/code-423n4/2023-09-maia/tree/main/foundry.toml) file.

### Install and First Build

Install libraries using forge and compile contracts.

```bash
forge install
forge build
```

## Layer Zero Fork Testing Environment

### Requirements
only uses native foundry tools (VM.fork)

### Set-up
- open the file '.env.sample' and populate the API_KEY and RPC_URL of the chains ARBITRUM, AVAX and FTM (FTM public RPC should be used). Add any other chain you want. Afterwards remove '.sample' from the file name.
- If you're creating a new test file extend 'LzForkTest' contract
- override the internal function 'setUpLzChains()' to start forks for the chains useful for your testing purposes you'll need to indicate the network chainId, name and the chain's Layer Zero 'Endpoint.sol' address.
- In the test's 'setUp() make sure to invoke the 'setUpLzChains()' function

### Using LzForkTest inside your tests
Whenever you need to change chain during there are 6 functions at your disposal:
- switchLzChain and switchChain: changes the current VM chain, updates any pending packet for the destination chain and executes them. Receives either the layer zero chain Id (e.g. 100 or 110) or the network chainId (e.g. 1 or 42161)
- switchLzChainWithoutExecutePackets and switchChainWithoutExecutePackets: changes the current VM chain, updates any pending packet for the destination chain and without executing them. Receives either the layer zero chain Id (e.g. 100 or 110) or the network chainId (e.g. 1 or 42161)
- switchLzChainWithoutExecutePacketsOrUpdate and switchChainWithoutExecutePacketsOrUpdate: changes the current VM chain, without updating any pending packets for the destination chain and without executing them. Receives either the layer zero chain Id (e.g. 100 or 110) or the network chainId (e.g. 1 or 42161)

## Slither

If you encounter any issues, please update slither to [0.9.3](https://github.com/crytic/slither/releases/tag/0.9.3), the latest version at the moment.

To run [slither](https://github.com/crytic/slither) from root, please specify the src directory.

```bash
slither "./src/*"
```

We have a [slither config](https://github.com/code-423n4/2023-09-maia/tree/main/slither.config.json) file that turns on optimization and adds forge remappings.

The output is provided in [./slither.txt](https://github.com/code-423n4/2023-09-maia/tree/main/slither.txt)
