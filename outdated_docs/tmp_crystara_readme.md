# Crystara SDK

This is the official repository for the Crystara SDK.

Here you can find simple, prebuilt examples for Blind Box integrations into your website, powered by Crystara's NFT Marketplace.

## SDK Installation

```bash
npm install crystara-sdk
```

## Prerequisites

Your website must have Tailwind CSS installed. The SDK utilizes brand color configurations that allow you to style components to match your branding.

```bash
npm install tailwindcss
```

### Required Tailwind Configuration

The Blind Box component works with the following brand variables: primary, secondary, accent, dark, and light. Configure your `tailwind.config.ts` as follows:

```typescript
content: [
  //Your Content files
  './node_modules/crystara-sdk/dist/**/*.{js,jsx}' // Include the Crystara SDK components
],
theme: {
  extend: {
    colors: {
      background: "var(--background)",
      foreground: "var(--foreground)",
      brand: {
        primary: "#6E44FF",
        secondary: "#FF44E3",
        accent: "#44FFED",
        dark: "#1A1A2E",
        light: "#F7F7FF",
      },
    },
  },
},
```

## Getting Started

### Step 1. Create a Blind Box on Crystara

Before integrating with your website, you must first create a blind box collection:

1. Create your blind box collections with on-chain rarities via Crystara's Creator Portal
2. Note the URL of your collection (e.g., `https://crystara.trade/marketplace/mycollection`)
   * You will use the collection name (e.g., `mycollection`) in your integration

### Step 2. NextJS Integration

To integrate with NextJS, you'll need to implement several API routes that serve as wrappers for the SDK's server actions.

#### Required API Routes

Create the following API routes:

* `batch-metadata/route.ts`
* `lootbox/route.ts`
* `lootbox-info/route.ts`
* `metadata/route.ts`
* `whitelist-amount/route.ts`

These routes are necessary, you will find the exact routes to copy seamlessly from the NextJS Example. This implementation makes use of server actions which require your Crystara API key from .env in a server-side protected way.

#### Environment Variables

Configure the following environment variables:
```
CRYSTARA_PRIVATE_API_KEY=<< SEND A REGISTRATION EMAIL TO developers@crystara.trade with 1. Purpose and 2. Registration Email >>

NEXT_PUBLIC_CRYSTARA_API_URL=https://api.crystara.trade/mainnet
NEXT_PUBLIC_SUPRA_RPC_URL="https://rpc-mainnet.supra.com/rpc/v1"

NEXT_PUBLIC_CRYSTARA_ADR=0xfd566b048d7ea241ebd4d28a3d60a9eaaaa29a718dfff52f2ff4ca8581363b85
NEXT_PUBLIC_COLLECTIONS_MODULE_NAME=crystara_blindbox_v1

NEXT_PUBLIC_SUPRA_CHAIN_ID=8
```


* `NEXT_PUBLIC_CRYSTARA_API_URL`: Indexer API route
* `NEXT_PUBLIC_SUPRA_RPC_URL`: Your preferred Supra RPC route
* `NEXT_PUBLIC_CRYSTARA_ADR`: Account address where Crystara modules are deployed
* `NEXT_PUBLIC_COLLECTIONS_MODULE_NAME`: Module deployed for Crystara blind boxes
* `NEXT_PUBLIC_SUPRA_CHAIN_ID`: 8 for mainnet, 6 for testnet

To obtain your `CRYSTARA_PRIVATE_API_KEY`, contact us at developers@crystara.trade.

### Step 3. Wallet Integration

You'll need a wallet provider setup. The SDK example repository includes a simplified wallet hook for Starkey Wallet on Supra.

The SDK uses an event-based architecture for transactions. When a user clicks the buy button, a `TRANSACTION_START` event is emitted, which your code must handle to send the transaction to your wallet provider.

### Step 4. Create the BlindBoxClient Component

Create a `BlindBoxClient.tsx` component as shown below:

```tsx
"use client";

import { BlindBoxPage, WALLET_EVENTS } from 'crystara-sdk';
import { walletEvents } from 'crystara-sdk';
import useStarkeyWallet from '@/app/hooks/starkeyExampleHook';
import { useEffect } from 'react';
import { toast, Toaster } from 'sonner';
import { motion } from 'framer-motion';

export function BlindBoxClient() {
  const starkey = useStarkeyWallet();

  useEffect(() => {
    let lastTxHash = '';
    
    const transactionStartEvent = async (event: any) => {
      if (!event || !event.contractAddress || !event.moduleName || !event.functionName) {
        console.error("Invalid transaction event data:", event);
        return;
      }
      
      const moduleAddress = event.contractAddress;
      const moduleName = event.moduleName;
      const functionName = event.functionName;
      const params = event.args || []; 
      const runTimeParams = event.typeArgs || [];
      
      try {
        const tx = await starkey.sendRawTransaction(
          moduleAddress,
          moduleName,
          functionName,
          params,
          runTimeParams
        );
        
        if (tx && tx !== lastTxHash) {
          lastTxHash = tx;
          console.log("Transaction successful:", tx);
          
          const txHash = tx;
          walletEvents.emit(WALLET_EVENTS.TRANSACTION_SUCCESS, {txHash});
          
          setTimeout(() => {
            if (lastTxHash === txHash) {
              lastTxHash = '';
            }
          }, 5000);
        }
      } catch (error) {
        console.error("Transaction failed:", error);
      }
    };

    const toastHandler = (event: any) => {
      console.log("Notification received:", event);
      if(event.type === "win") {
        showCustomWinningToast(event);
      }
    };
    
    const unsubscribe = walletEvents.on(WALLET_EVENTS.TRANSACTION_START, transactionStartEvent);
    const unsubscribe2 = walletEvents.on(WALLET_EVENTS.NOTIFICATION, toastHandler);
    
    return () => {
      unsubscribe();
      unsubscribe2();
    };
  }, [starkey]);

  const showCustomWinningToast = (event: any) => {
    toast.custom((t) => (
      <motion.div
        initial={{ opacity: 0, y: -100 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -100 }}
        className="bg-brand-dark p-6 rounded-lg shadow-xl"
      >
        <h3 className="text-xl font-bold text-white mb-2">Congratulations!</h3>
        <img
          src={event.image || ''} 
          alt={event.name} 
          className="w-32 h-32 object-cover rounded-lg mb-2"
        />
        <p className="text-white">{event.name}</p>
        <p className="text-gray-400">{event.rarity}</p>
      </motion.div>
    ), {
      duration: 3500,
    });
  }

  // API wrapper functions
  const fetchMetadata = async (url: string) => {
    const response = await fetch(`/api/metadata?url=${encodeURIComponent(url)}`);
    if (!response.ok) throw new Error('Failed to fetch metadata');
    return response.json();
  };
  
  const fetchLootboxStats = async (url: string, viewer?: string) => {
    const response = await fetch(`/api/lootbox?url=${encodeURIComponent(url)}${viewer ? `&viewer=${viewer}` : ''}`);
    if (!response.ok) throw new Error('Failed to fetch lootbox stats');
    return response.json();
  };

  const batchFetchMetadata = async (urls: string[], bustCache?: boolean) => {
    const response = await fetch('/api/batch-metadata', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ urls, bustCache }),
    });
    if (!response.ok) throw new Error('Failed to batch fetch metadata');
    return response.json();
  };

  const fetchLootboxInfo = async (lootboxCreatorAddress: string, collectionName: string, viewerAddress: string | null) => {
    const response = await fetch('/api/lootbox-info', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ lootboxCreatorAddress, collectionName, viewerAddress }),
    });
    if (!response.ok) throw new Error('Failed to fetch lootbox info');
    return response.json();
  };

  const fetchWhitelistAmount = async (lootboxCreatorAddress: string, collectionName: string, currentAddress: string) => {
    const response = await fetch('/api/whitelist-amount', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ lootboxCreatorAddress, collectionName, currentAddress }),
    });
    if (!response.ok) throw new Error('Failed to fetch whitelist amount');
    return response.json();
  };

  return (
    <div className="min-h-screen bg-black">
      <BlindBoxPage 
        params={{
          contractAddress: process.env.NEXT_PUBLIC_CRYSTARA_ADR || "",
          contractModuleName: process.env.NEXT_PUBLIC_COLLECTIONS_MODULE_NAME || "",
          supraRPCUrl: process.env.NEXT_PUBLIC_SUPRA_RPC_URL || "",
          lootboxUrl: "uglies",
          viewerAddress: starkey.accounts[0],
          sounds: {
            "open": "/sounds/opencrate.mp3",
            "win": "/sounds/woosh.wav",
            "tick": "/sounds/cratetick.mp3",
            "error": "/sounds/error.mp3"
          }
        }}
        fetchMetadata={fetchMetadata}
        fetchLootboxStats={fetchLootboxStats}
        batchFetchMetadata={batchFetchMetadata}
        fetchLootboxInfo={fetchLootboxInfo}
        fetchWhitelistAmount={fetchWhitelistAmount}
      />
      <Toaster />
    </div>
  );
}
```

### Step 5. Sound Effects

The SDK does not include sound effects for the blind box experience. You can refer to the NextJS example, Crystara's SFX are located under `public/sounds`. You can use the provided sounds or replace them with your own.

## Additional Resources

If you encounter any issues or need further assistance, please contact our developer support at developers@crystara.trade.

You can also download our NextJS example repository for a complete implementation reference.
