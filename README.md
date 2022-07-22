# Getting Started

## Enviroment Requirements

- [node >= 16 or LTS](https://nodejs.org/en/download/)

- [forge >= 0.2.0](https://book.getfoundry.sh/getting-started/installation)

- [git >= 2.37.0](https://git-scm.com/download/)

- [VS Code](https://code.visualstudio.com/download) [recommended]

## Installing Dependencies

- Use Foundry:

```bash
forge install
```

- Use Hardhat:

```bash
pnpm install
```

## Running tests

- Foundry

```bash
forge test
```

- Hardhat

```bash
pnpm hardhat test 
# or 
pnpm test
```

- Use Hardhat's task framework

```bash
pnpm hardhat example
```

- Install libraries with Foundry which work with Hardhat.

```bash
forge install rari-capital/solmate
```

### Notes

Whenever you install new libraries using Foundry, make sure to update `remappings.txt` file by running `forge remappings > remappings.txt`.

### Warning

Windows enviroment users beware that redirecting powershell output to a file will default to UTF16 encoding where we expect `remappings.txt` to be UTF8 encoded.
