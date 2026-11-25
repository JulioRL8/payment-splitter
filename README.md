# Payment Splitter

A two-party ETH splitter with immutable basis-point shares and independent withdrawals.

## How it works

1. Deploy with two distinct payees and the first payee's share in basis points.
2. Send ETH directly to the contract or call `deposit()`. Each deposit is credited immediately.
3. Each payee calls `withdraw(recipient)` to send its accrued credit to an address it chooses.

The first share rounds down per deposit. Any remaining wei goes to the second payee. ETH forced into the contract bypasses the deposit accounting.

## Build and test

Install [Foundry](https://getfoundry.sh/) and run these commands from this directory. Forge selects Solidity 0.8.36 from `foundry.toml`. The project has no third-party Solidity dependencies.

```bash
forge build
forge test -vv
forge coverage --exclude-tests
```

## Local deployment

Start a fresh `anvil` node in a separate terminal. Deploy with the first unlocked account on that local node.

```bash
export RPC_URL=http://127.0.0.1:8545
export ANVIL_ACCOUNT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
forge create src/PaymentSplitter.sol:PaymentSplitter --rpc-url "$RPC_URL" --from "$ANVIL_ACCOUNT" --unlocked --broadcast --constructor-args "$ANVIL_ACCOUNT" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 6000
```

## Local example

Set `CONTRACT` to the address printed by `forge create` and keep using the same terminal.

```bash
export ETH_RPC_URL="$RPC_URL"
CONTRACT=0x... # Replace with your deployed address.
cast send "$CONTRACT" 'deposit()' --value 1ether --from "$ANVIL_ACCOUNT" --unlocked
cast call "$CONTRACT" 'credit(address)(uint256)' "$ANVIL_ACCOUNT"
cast send "$CONTRACT" 'withdraw(address)' "$ANVIL_ACCOUNT" --from "$ANVIL_ACCOUNT" --unlocked
```

## Test cases

Foundry reports 8 passing tests and 100% coverage on contract lines, statements, branches and functions.

- Configuration validation, both deposit entry points and rounding.
- Independent payee credits, failed withdrawals and payout redirection.
- Fuzzed conservation across share ratios and ETH values.
