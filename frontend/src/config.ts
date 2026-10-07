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

/// Active deployment (OP Mainnet).
export const CONTRACTS = {
  liquidWallet: "0x003487F13973251Ed953b17c1fE2a246e33787D3",
  vault: "0x262c79E29fCD714fA84F60FF0c0A33405Ca60c40",
  wsk: "0x37501f822375fC169cCCd75c78f782Ac21f0B9e7",
  nft: "0x793980219a0779EE1EbbB0f4550C38A3c5970061",
  usdc: "0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85",
} as const;

export const EXPLORER = "https://optimistic.etherscan.io";
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

/// UI metadata for the active deployment's share token.
export const SHARE = { name: "Wellstake Beta Vault", symbol: "wskBV", decimals: 6 } as const;
export const QUOTE = { name: "USD Coin", symbol: "USDC", decimals: 6 } as const;
