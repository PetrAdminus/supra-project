# Supra Move MCP Server
A Model Context Protocol (MCP) server that provides production-ready Supra Move code templates for blockchain development.

This MCP server gives Claude access to 9-tested Supra Move templates to Generate correct, production-ready smart contracts for DeFi, NFTs, and more.

## Prerequisites

- Python 3.8+
- Claude Desktop app

## Setup

**One-Click Install**

```bash
curl -fsSL https://raw.githubusercontent.com/JatinSupra/supra-move-mcp/refs/heads/main/setup.sh | bash
```

### If above one doesn't work, Configure Claude Desktop:

Add to your Claude Desktop config file:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`

**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "supra": {
      "command": "python",
      "args": ["/path/to/supra_mcp.py"]
    }
  }
}
```

## Examples

### Example 1: Deploy a Custom Coin

1. Get the coin template
2. Replace `my_address` with your address
3. Update coin name, symbol, and decimals
4. Deploy with: `supra move tool publish --package-dir .`

### Example 2: Create NFT Collection

1. Get the `nft_with_signature` template
2. Set up ed25519 keypair: `supra key generate --key-type ed25519`
3. Update the public key in `init_module`
4. Deploy under resource account
5. Sign mint requests from your backend

### Example 3: Build a DEX

1. Get the `amm_swap` template
2. Define your custom token
3. Set fee rate (default: 30 basis points = 0.3%)
4. Initialize pool with liquidity
5. Enable swapping