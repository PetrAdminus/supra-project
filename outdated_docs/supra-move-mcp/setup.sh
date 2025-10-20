#!/bin/bash
set -e
echo "╔═══════════════════════════════════════╗"
echo "║   Supra Move MCP Installer v1.0       ║"
echo "╔═══════════════════════════════════════╗"
echo ""

OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*|MINGW*|MSYS*) MACHINE=Windows;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "[1/6] Detected OS: $MACHINE"
if [ "$MACHINE" = "Mac" ]; then
    CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [ "$MACHINE" = "Linux" ]; then
    CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
elif [ "$MACHINE" = "Windows" ]; then
    CLAUDE_CONFIG_DIR="$APPDATA/Claude"
else
    echo "❌ Unsupported operating system: $MACHINE"
    exit 1
fi
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
INSTALL_DIR="$HOME/.supra-mcp"
echo "[2/6] Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
echo "[3/6] Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8+ first."
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo "   ✓ Python $PYTHON_VERSION found"
echo "[4/6] Installing MCP Python package..."
pip3 install mcp --quiet || {
    echo "❌ Failed to install MCP package. Try: pip3 install mcp"
    exit 1
}
echo "   ✓ MCP package installed"
echo "[5/6] Creating Supra MCP server..."
cat > "$INSTALL_DIR/supra_mcp.py" << 'EOPYTHON'
#!/usr/bin/env python3
"""
Production Supra MCP Server - Built from Real Framework Examples
"""
import asyncio
import json
import sys
from typing import Any, Dict, List
from mcp.server import Server, NotificationOptions
from mcp.server.models import InitializationOptions
import mcp.server.stdio
import mcp.types as types
CODE_TEMPLATES = {
    "hello_world": """module my_address::hello_world {
    use std::string::{Self, String};
    use supra_framework::event;
    
    struct HelloEvent has drop, store {
        message: String,
    }
    
    public entry fun say_hello() {
        event::emit(HelloEvent {
            message: string::utf8(b"Hello from Supra!")
        });
    }
}""",
    
    "counter": """module my_address::counter {
    use std::signer;
    
    struct Counter has key {
        value: u64
    }
    
    public entry fun initialize(account: &signer) {
        move_to(account, Counter { value: 0 });
    }
    
    public entry fun increment(account: &signer) acquires Counter {
        let counter = borrow_global_mut<Counter>(signer::address_of(account));
        counter.value = counter.value + 1;
    }
    
    #[view]
    public fun get_count(addr: address): u64 acquires Counter {
        borrow_global<Counter>(addr).value
    }
}""",

    "coin": """module my_address::my_coin {
    use supra_framework::coin;
    use std::signer;
    use std::string;
    
    struct MyCoin {}
    
    fun init_module(sender: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<MyCoin>(
            sender,
            string::utf8(b"My Coin"),
            string::utf8(b"MYC"),
            8,
            false,
        );
        
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_freeze_cap(freeze_cap);
        
        coin::register<MyCoin>(sender);
        
        let coins = coin::mint(10000000000, &mint_cap);
        coin::deposit(signer::address_of(sender), coins);
        
        coin::destroy_mint_cap(mint_cap);
    }
}""",

    "nft_with_signature": """module my_address::nft_minting {
    use std::error;
    use std::signer;
    use std::string::{Self, String};
    use supra_framework::account;
    use supra_framework::event;
    use supra_framework::timestamp;
    use aptos_std::ed25519;
    use aptos_token::token::{Self, TokenDataId};
    use supra_framework::resource_account;

    #[event]
    struct TokenMinting has drop, store {
        token_receiver_address: address,
        token_data_id: TokenDataId,
    }

    struct ModuleData has key {
        public_key: ed25519::ValidatedPublicKey,
        signer_cap: account::SignerCapability,
        token_data_id: TokenDataId,
        expiration_timestamp: u64,
        minting_enabled: bool,
    }

    struct MintProofChallenge has drop {
        receiver_account_sequence_number: u64,
        receiver_account_address: address,
        token_data_id: TokenDataId,
    }

    const ECOLLECTION_EXPIRED: u64 = 2;
    const EMINTING_DISABLED: u64 = 3;
    const EINVALID_PROOF_OF_KNOWLEDGE: u64 = 6;

    fun init_module(resource_signer: &signer) {
        let collection_name = string::utf8(b"My NFT Collection");
        let token_name = string::utf8(b"My NFT");
        
        token::create_collection(
            resource_signer,
            collection_name,
            string::utf8(b"Collection Description"),
            string::utf8(b"https://example.com/collection"),
            0,
            vector<bool>[false, false, false]
        );

        let token_data_id = token::create_tokendata(
            resource_signer,
            collection_name,
            token_name,
            string::utf8(b""),
            0,
            string::utf8(b"https://example.com/token"),
            signer::address_of(resource_signer),
            1,
            0,
            token::create_token_mutability_config(&vector<bool>[false, false, false, false, true]),
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[b""],
            vector<String>[string::utf8(b"address")],
        );

        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @source_addr);
        let pk_bytes = x"f66bf0ce5ceb582b93d6780820c2025b9967aedaa259bdbb9f3d0297eced0e18";
        let public_key = std::option::extract(&mut ed25519::new_validated_public_key_from_bytes(pk_bytes));
        
        move_to(resource_signer, ModuleData {
            public_key,
            signer_cap: resource_signer_cap,
            token_data_id,
            expiration_timestamp: 10000000000,
            minting_enabled: true,
        });
    }

    public entry fun mint_nft(receiver: &signer, mint_proof_signature: vector<u8>) acquires ModuleData {
        let receiver_addr = signer::address_of(receiver);
        let module_data = borrow_global_mut<ModuleData>(@my_address);
        
        assert!(timestamp::now_seconds() < module_data.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
        assert!(module_data.minting_enabled, error::permission_denied(EMINTING_DISABLED));

        verify_signature(receiver_addr, mint_proof_signature, module_data.token_data_id, module_data.public_key);

        let resource_signer = account::create_signer_with_capability(&module_data.signer_cap);
        let token_id = token::mint_token(&resource_signer, module_data.token_data_id, 1);
        token::direct_transfer(&resource_signer, receiver, token_id, 1);

        event::emit(TokenMinting {
            token_receiver_address: receiver_addr,
            token_data_id: module_data.token_data_id,
        });
    }

    fun verify_signature(
        receiver_addr: address,
        mint_proof_signature: vector<u8>,
        token_data_id: TokenDataId,
        public_key: ed25519::ValidatedPublicKey
    ) {
        let proof_challenge = MintProofChallenge {
            receiver_account_sequence_number: account::get_sequence_number(receiver_addr),
            receiver_account_address: receiver_addr,
            token_data_id,
        };

        let signature = ed25519::new_signature_from_bytes(mint_proof_signature);
        let unvalidated_public_key = ed25519::public_key_to_unvalidated(&public_key);
        assert!(
            ed25519::signature_verify_strict_t(&signature, &unvalidated_public_key, proof_challenge),
            error::invalid_argument(EINVALID_PROOF_OF_KNOWLEDGE)
        );
    }
}""",

    "locked_coins": """module my_address::locked_coins {
    use supra_framework::coin::{Self, Coin};
    use supra_framework::event;
    use supra_framework::timestamp;
    use aptos_std::table::{Self, Table};
    use std::error;
    use std::signer;

    struct Lock<phantom CoinType> has store {
        coins: Coin<CoinType>,
        unlock_time_secs: u64,
    }

    struct Locks<phantom CoinType> has key {
        locks: Table<address, Lock<CoinType>>,
        withdrawal_address: address,
        total_locks: u64,
    }

    #[event]
    struct Claim has drop, store {
        sponsor: address,
        recipient: address,
        amount: u64,
        claimed_time_secs: u64,
    }

    const ELOCK_NOT_FOUND: u64 = 1;
    const ELOCKUP_HAS_NOT_EXPIRED: u64 = 2;
    const ELOCK_ALREADY_EXISTS: u64 = 3;

    public entry fun initialize_sponsor<CoinType>(sponsor: &signer, withdrawal_address: address) {
        move_to(sponsor, Locks {
            locks: table::new<address, Lock<CoinType>>(),
            withdrawal_address,
            total_locks: 0,
        })
    }

    public entry fun add_locked_coins<CoinType>(
        sponsor: &signer, 
        recipient: address, 
        amount: u64, 
        unlock_time_secs: u64
    ) acquires Locks {
        let locks = borrow_global_mut<Locks<CoinType>>(signer::address_of(sponsor));
        let coins = coin::withdraw<CoinType>(sponsor, amount);
        assert!(!table::contains(&locks.locks, recipient), error::already_exists(ELOCK_ALREADY_EXISTS));
        table::add(&mut locks.locks, recipient, Lock<CoinType> { coins, unlock_time_secs });
        locks.total_locks = locks.total_locks + 1;
    }

    public entry fun claim<CoinType>(recipient: &signer, sponsor: address) acquires Locks {
        let locks = borrow_global_mut<Locks<CoinType>>(sponsor);
        let recipient_address = signer::address_of(recipient);
        assert!(table::contains(&locks.locks, recipient_address), error::not_found(ELOCK_NOT_FOUND));

        let Lock { coins, unlock_time_secs } = table::remove(&mut locks.locks, recipient_address);
        locks.total_locks = locks.total_locks - 1;
        let now_secs = timestamp::now_seconds();
        assert!(now_secs >= unlock_time_secs, error::invalid_state(ELOCKUP_HAS_NOT_EXPIRED));

        let amount = coin::value(&coins);
        coin::deposit(recipient_address, coins);

        event::emit(Claim {
            sponsor,
            recipient: recipient_address,
            amount,
            claimed_time_secs: now_secs,
        });
    }
}""",

    "fungible_asset": """module my_address::managed_fungible_asset {
    use supra_framework::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata, FungibleAsset};
    use supra_framework::object::{Self, Object, ConstructorRef};
    use supra_framework::primary_fungible_store;
    use std::error;
    use std::signer;
    use std::string::String;
    use std::option;

    const ERR_NOT_OWNER: u64 = 1;

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ManagingRefs has key {
        mint_ref: option::Option<MintRef>,
        transfer_ref: option::Option<TransferRef>,
        burn_ref: option::Option<BurnRef>,
    }

    public fun initialize(
        constructor_ref: &ConstructorRef,
        maximum_supply: u128,
        name: String,
        symbol: String,
        decimals: u8,
        icon_uri: String,
        project_uri: String,
    ) {
        let supply = if (maximum_supply != 0) {
            option::some(maximum_supply)
        } else {
            option::none()
        };
        
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            supply,
            name,
            symbol,
            decimals,
            icon_uri,
            project_uri,
        );

        let mint_ref = option::some(fungible_asset::generate_mint_ref(constructor_ref));
        let transfer_ref = option::some(fungible_asset::generate_transfer_ref(constructor_ref));
        let burn_ref = option::some(fungible_asset::generate_burn_ref(constructor_ref));
        
        let metadata_object_signer = object::generate_signer(constructor_ref);
        move_to(&metadata_object_signer, ManagingRefs { mint_ref, transfer_ref, burn_ref })
    }

    public entry fun mint(
        admin: &signer,
        asset: Object<Metadata>,
        to: address,
        amount: u64,
    ) acquires ManagingRefs {
        let refs = borrow_global<ManagingRefs>(object::object_address(&asset));
        assert!(object::is_owner(asset, signer::address_of(admin)), error::permission_denied(ERR_NOT_OWNER));
        
        let mint_ref = option::borrow(&refs.mint_ref);
        let fa = fungible_asset::mint(mint_ref, amount);
        primary_fungible_store::deposit(to, fa);
    }
}""",

    "aggregator_counter": """module my_address::counter_with_milestone {
    use std::error;
    use std::signer;
    use supra_framework::aggregator_v2::{Self, Aggregator};
    use supra_framework::event;

    const ERESOURCE_NOT_PRESENT: u64 = 2;
    const ECOUNTER_INCREMENT_FAIL: u64 = 4;
    const ENOT_AUTHORIZED: u64 = 5;

    struct MilestoneCounter has key {
        next_milestone: u64,
        milestone_every: u64,
        count: Aggregator<u64>,
    }

    #[event]
    struct MilestoneReached has drop, store {
        milestone: u64,
    }

    public entry fun create(publisher: &signer, milestone_every: u64) {
        assert!(signer::address_of(publisher) == @my_address, ENOT_AUTHORIZED);
        move_to<MilestoneCounter>(
            publisher,
            MilestoneCounter {
                next_milestone: milestone_every,
                milestone_every,
                count: aggregator_v2::create_unbounded_aggregator(),
            }
        );
    }

    public entry fun increment_milestone() acquires MilestoneCounter {
        assert!(exists<MilestoneCounter>(@my_address), error::invalid_argument(ERESOURCE_NOT_PRESENT));
        let milestone_counter = borrow_global_mut<MilestoneCounter>(@my_address);
        assert!(aggregator_v2::try_add(&mut milestone_counter.count, 1), ECOUNTER_INCREMENT_FAIL);
        
        if (aggregator_v2::is_at_least(&milestone_counter.count, milestone_counter.next_milestone) && 
            !aggregator_v2::is_at_least(&milestone_counter.count, milestone_counter.next_milestone + 1)) {
            event::emit(MilestoneReached { milestone: milestone_counter.next_milestone});
            milestone_counter.next_milestone = milestone_counter.next_milestone + milestone_counter.milestone_every;
        }
    }
}""",

    "amm_swap": """module my_address::token_swap_dex {
    use std::error;
    use std::signer;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::event;
    use supra_framework::timestamp;

    struct MyToken {}

    struct LiquidityPool has key {
        custom_coins: Coin<MyToken>,
        supra_coins: Coin<SupraCoin>,
        total_lp_supply: u64,
        fee_rate: u64,
        k_last: u128,
    }

    #[event]
    struct TokenSwapped has drop, store {
        trader: address,
        amount_in: u64,
        amount_out: u64,
        is_custom_to_supra: bool,
        timestamp: u64,
    }

    const EINVALID_AMOUNT: u64 = 2;
    const ESLIPPAGE_EXCEEDED: u64 = 3;

    public entry fun swap_custom_to_supra(
        account: &signer,
        amount_in: u64,
        min_amount_out: u64,
    ) acquires LiquidityPool {
        let pool = borrow_global_mut<LiquidityPool>(@my_address);
        assert!(amount_in > 0, error::invalid_argument(EINVALID_AMOUNT));

        let reserve_custom = coin::value(&pool.custom_coins);
        let reserve_supra = coin::value(&pool.supra_coins);
        
        let amount_in_with_fee = amount_in * (10000 - pool.fee_rate) / 10000;
        let amount_out = (amount_in_with_fee * reserve_supra) / (reserve_custom + amount_in_with_fee);
        
        assert!(amount_out >= min_amount_out, error::invalid_state(ESLIPPAGE_EXCEEDED));

        let custom_coins = coin::withdraw<MyToken>(account, amount_in);
        coin::merge(&mut pool.custom_coins, custom_coins);
        
        let supra_coins = coin::extract(&mut pool.supra_coins, amount_out);
        coin::deposit(signer::address_of(account), supra_coins);

        event::emit(TokenSwapped {
            trader: signer::address_of(account),
            amount_in,
            amount_out,
            is_custom_to_supra: true,
            timestamp: timestamp::now_seconds(),
        });
    }
}""",

    "resource_account_defi": """module resource_account::simple_defi {
    use std::signer;
    use std::string;
    use supra_framework::account;
    use supra_framework::coin::{Self, Coin, MintCapability, BurnCapability};
    use supra_framework::resource_account;
    use supra_framework::supra_coin::SupraCoin;

    struct ModuleData has key {
        resource_signer_cap: account::SignerCapability,
        burn_cap: BurnCapability<ChloesCoin>,
        mint_cap: MintCapability<ChloesCoin>,
    }

    struct ChloesCoin {}

    fun init_module(account: &signer) {
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(account, @source_addr);
        
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<ChloesCoin>(
            account,
            string::utf8(b"Chloe's Coin"),
            string::utf8(b"CCOIN"),
            8,
            false,
        );
        
        move_to(account, ModuleData {
            resource_signer_cap,
            burn_cap,
            mint_cap,
        });
        
        coin::destroy_freeze_cap(freeze_cap);
        coin::register<SupraCoin>(account);
        coin::register<ChloesCoin>(account);
    }

    public fun exchange_to(a_coin: Coin<SupraCoin>): Coin<ChloesCoin> acquires ModuleData {
        let coin_cap = borrow_global_mut<ModuleData>(@resource_account);
        let amount = coin::value(&a_coin);
        coin::deposit(@resource_account, a_coin);
        coin::mint<ChloesCoin>(amount, &coin_cap.mint_cap)
    }

    public fun exchange_from(c_coin: Coin<ChloesCoin>): Coin<SupraCoin> acquires ModuleData {
        let amount = coin::value(&c_coin);
        let coin_cap = borrow_global_mut<ModuleData>(@resource_account);
        coin::burn<ChloesCoin>(c_coin, &coin_cap.burn_cap);

        let module_data = borrow_global_mut<ModuleData>(@resource_account);
        let resource_signer = account::create_signer_with_capability(&module_data.resource_signer_cap);
        coin::withdraw<SupraCoin>(&resource_signer, amount)
    }
}"""
}

async def run_server():
    """Run the MCP server"""
    server = Server("supra-move-helper")
    
    @server.list_tools()
    async def handle_list_tools() -> List[types.Tool]:
        """List available tools"""
        return [
            types.Tool(
                name="get_template",
                description="Get a production-ready Supra Move template",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "template": {
                            "type": "string",
                            "enum": list(CODE_TEMPLATES.keys()),
                            "description": "Template name"
                        }
                    },
                    "required": ["template"]
                }
            ),
            types.Tool(
                name="list_templates",
                description="List all available Supra Move templates",
                inputSchema={
                    "type": "object",
                    "properties": {}
                }
            ),
            types.Tool(
                name="explain_template",
                description="Get detailed explanation of a template",
                inputSchema={
                    "type": "object",
                    "properties": {
                        "template": {
                            "type": "string",
                            "enum": list(CODE_TEMPLATES.keys()),
                            "description": "Template name to explain"
                        }
                    },
                    "required": ["template"]
                }
            )
        ]
    
    @server.call_tool()
    async def handle_call_tool(
        name: str,
        arguments: Dict[str, Any]
    ) -> List[types.TextContent]:
        """Handle tool calls"""
        
        if name == "get_template":
            template_name = arguments.get("template", "hello_world")
            
            if template_name in CODE_TEMPLATES:
                code = CODE_TEMPLATES[template_name]
                response = f"Here's the {template_name} template:\n\n```move\n{code}\n```"
            else:
                response = f"Template '{template_name}' not found. Available: {', '.join(CODE_TEMPLATES.keys())}"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "list_templates":
            templates_info = {
                "hello_world": "Basic event emission pattern",
                "counter": "Simple state management with resources",
                "coin": "Custom coin with init_module",
                "nft_with_signature": "NFT minting with ed25519 signature verification (anti-bot)",
                "locked_coins": "Time-locked coin transfers with vesting schedules",
                "fungible_asset": "Managed fungible asset with mint/burn/transfer refs",
                "aggregator_counter": "Parallel counter with milestones using AggregatorV2",
                "amm_swap": "AMM DEX with constant product formula",
                "resource_account_defi": "Resource account pattern for autonomous DeFi"
            }
            
            response = "Available Supra Move Templates (from production code):\n\n"
            for name, desc in templates_info.items():
                response += f"• {name}: {desc}\n"
            
            return [types.TextContent(type="text", text=response)]
        
        elif name == "explain_template":
            template_name = arguments.get("template")
            
            explanations = {
                "hello_world": "Basic pattern for event emission in Supra Move. Events are logged on-chain and can be queried.",
                "counter": "Shows resource storage with 'has key', global state access with 'acquires', and #[view] for read-only functions.",
                "coin": "Standard coin creation pattern. Uses init_module for automatic setup when package is published.",
                "nft_with_signature": "Production NFT with ed25519 signature verification to prevent bot spam. Only requests with valid signatures from backend can mint.",
                "locked_coins": "Vesting/time-locked transfers. Sponsors lock coins for recipients until a specific timestamp. Uses Table for efficient storage.",
                "fungible_asset": "Modern fungible asset pattern with primary store support. More flexible than coins - supports features like freezing.",
                "aggregator_counter": "Uses AggregatorV2 for high-parallelism counters. Milestone detection with minimal contention - perfect for NFT mint tracking.",
                "amm_swap": "Automated Market Maker with constant product (x*y=k) formula. Includes fee calculation and slippage protection.",
                "resource_account_defi": "Resource accounts enable programmatic signing. Essential for DeFi protocols that need autonomous operations."
            }
            
            if template_name in explanations:
                response = f"{template_name}:\n{explanations[template_name]}"
            else:
                response = f"No explanation available for '{template_name}'"
            
            return [types.TextContent(type="text", text=response)]
        
        else:
            return [types.TextContent(
                type="text",
                text=f"Unknown tool: {name}"
            )]
    
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="supra-move-helper",
                server_version="3.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={}
                )
            )
        )

def main():
    """Main entry point"""
    try:
        asyncio.run(run_server())
    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
EOPYTHON

chmod +x "$INSTALL_DIR/supra_mcp.py"
echo "   ✓ MCP server created at $INSTALL_DIR/supra_mcp.py"
echo "[6/6] Configuring Claude Desktop..."

mkdir -p "$CLAUDE_CONFIG_DIR"
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    cp "$CLAUDE_CONFIG_FILE" "$CLAUDE_CONFIG_FILE.backup"
    echo "   ✓ Backed up existing config to $CLAUDE_CONFIG_FILE.backup"
fi
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    python3 << EOPYTHON
import json
import sys

config_file = "$CLAUDE_CONFIG_FILE"
install_dir = "$INSTALL_DIR"

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['supra'] = {
    'command': 'python3',
    'args': [f'{install_dir}/supra_mcp.py']
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)

print("   ✓ Updated Claude Desktop config")
EOPYTHON
else
    cat > "$CLAUDE_CONFIG_FILE" << EOJSON
{
  "mcpServers": {
    "supra": {
      "command": "python3",
      "args": ["$INSTALL_DIR/supra_mcp.py"]
    }
  }
}
EOJSON
    echo "   ✓ Created new Claude Desktop config"
fi

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║     Installation Complete! ✓          ║"
echo "╔═══════════════════════════════════════╗"
echo ""
echo "📁 Installed to: $INSTALL_DIR"
echo "⚙️  Config file: $CLAUDE_CONFIG_FILE"
echo ""
echo "Next steps:"
echo "1. Restart Claude Desktop application"
echo "2. Look for 🔌 icon in Claude to verify MCP is connected"
echo "3. Test with: 'List available Supra Move templates'"
echo ""
echo "Uninstall: rm -rf $INSTALL_DIR && remove 'supra' entry from $CLAUDE_CONFIG_FILE"
echo ""