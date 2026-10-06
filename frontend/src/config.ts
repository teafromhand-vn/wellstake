import { defineChain } from "viem";

/// Optimism Mainnet.
export const opMainnet = defineChain({
  id: 10,
  name: "OP Mainnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://optimism-rpc.publicnode.com"] },
  },
  blockExplorers: {
    default: { name: "OP Mainnet Explorer", url: "https://optimistic.etherscan.io" },
  },
});

/// Active deployment (OP Mainnet). Addresses are filled in after deployment.
export const CONTRACTS = {
  liquidWallet: "0x0000000000000000000000000000000000000000",
  vault: "0x0000000000000000000000000000000000000000",
  wsk: "0x0000000000000000000000000000000000000000",
  nft: "0x0000000000000000000000000000000000000000",
  usdc: "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85",
} as const;

export const EXPLORER = "https://optimistic.etherscan.io";
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

/// UI metadata for the active deployment's share token.
export const SHARE = { name: "Wellstake Beta Vault", symbol: "wskBV", decimals: 6 } as const;
export const QUOTE = { name: "USD Coin", symbol: "USDC", decimals: 6 } as const;
