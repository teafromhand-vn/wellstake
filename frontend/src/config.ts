import { defineChain } from "viem";

/// Arc Testnet. Gas token is the native chain currency; settlement uses WUSDC (ERC-20, 6dp).
export const arcTestnet = defineChain({
  id: 5042002,
  name: "Arc Testnet",
  nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc.testnet.arc.io"] },
  },
  blockExplorers: {
    default: { name: "Arc Explorer", url: "https://explorer.testnet.arc.io" },
  },
  testnet: true,
});

/// Active deployment (WUSDC stack on Arc Testnet).
export const CONTRACTS = {
  liquidWallet: "0x34EFa1dE4a3f6432d65cBACb1c77783745f6b963",
  vault: "0x464aDcb56298B5226D6a4ee5F9D5ed023fA0EF6A",
  wsk: "0x4943e1Add5bAA4caf62c2aAc225445dC9465BE0a",
  nft: "0x3C67B98454637ae21B61Df03C38Bd28e124cEb7e",
  usdc: "0x3600000000000000000000000000000000000000",
} as const;

/// Secondary deployment (QT stack) kept for reference / future switch.
export const QT_DEPLOYMENT = {
  liquidWallet: "0x4e97eDad6fD91eb347114d86e0D339735938B1c9",
  vault: "0x21F9f020b4F4587178d31AD22a0917Ad52b2F567",
  wsk: "0x7D6DA06d6a4ECA1B9BBDed64742641356221Bd1e",
  nft: "0x483328624b77F33ee284570B299D29aAe377C3c2",
  usdc: "0xE8B907D58c70959c80BB53afD8DF07C121c08171",
} as const;

export const EXPLORER = "https://explorer.testnet.arc.io";
export const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

/// UI metadata for the active deployment's share token.
export const SHARE = { name: "testWellstake", symbol: "tWSK", decimals: 6 } as const;
export const QUOTE = { name: "Wrapped USDC", symbol: "USDC", decimals: 6 } as const;
