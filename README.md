# Getting Started

[Check out the UML](https://www.plantuml.com/plantuml/uml/jPJFJjj04CRFzLEuog5j46g5Mcv5H4vI8O5QfG4E25c3TqYsx9zeTfmGA8_GM-zznJv2rmiccnXBI6rzydxphUtvVPxTTmp4fLR9IvwYnbG3kUHLkhsT5WgSG-TlaoG9YpJxUd8AIY6djqdgh-2JPeea6Ko1bVV5BLmu9YZuxi18bg3a3LmeZ0kPDOpNV3oR40ZSh7vUc4gAgydgTNCW5zwpTNOs66Kxxquiepi_J-UMfPcCxHMQoAwHfrOyxEXsyxomnh-dBDXIddUxhzzuNTOVYc4fKE446CUsMdPocCt8pl70N5R6ofFSnKnEe5JSlzyahVclS8xy9sXGNyXUBuTUiBHiemD24BeApIA4Tg1d2ZKQ3byPBAKqlFDXrrlOCgY77b24elPzUwBfmtC-xgtYznj4xMs1tSdp9fgy0XYWjbRpqXHJa0R5lMyzZEsy8FIhqF-zWP19uXnNp-avX-oUZcc8wFvvG2q1D00EoTwWwKjNsD84YfThoj2Ix-ZMLGaLTt4ylImR7VSEyr5lF6Ynz0V3tl7XE1yE1XlPVhFIZAN63La3bxxrvORi2b2uyGCLRdxaCscFEiPRXzpGc_5k_VxryyUCS2vnuIsFqWIvGUQngE7QUslbaX1lS2LqAairichfnPN27a3zj9Kw8rd4SlEFUUPPvu-YzxixkorJ6sDewl4CD7-blplC0h4mtFLKH0TSLXAXuKo1r9jnd4gU2e95Z7rDMqIBUEC81Q8EAjMt7ck3tzkqT7uwV6nLFpK9Vt_MwGDTVR9Ae1bPSVvzButvFTCQ8MrAJ--iZxTa7uqejVe3)


![Architecture](https://user-images.githubusercontent.com/1284031/182102399-d8e78527-61ee-462d-8bd3-b65613145977.png)

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

- Install libraries with Foundry which work with Hardhat. This project prefers forge/gitsubmodule installs for external contracts rather than node dependencies.

```bash
forge install rari-capital/solmate
```

### Notes

Whenever you install new libraries, make sure to update `remappings.txt` file by running `forge remappings > remappings.txt`.

### Warning

Windows enviroment users beware that redirecting powershell output to a file will default to UTF16 encoding where we expect `remappings.txt` to be UTF8 encoded.
