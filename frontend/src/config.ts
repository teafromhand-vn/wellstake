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
  liquidWallet: "0x61acb88ae559b578ee9a73cc8c7786b5975a287b",
  vault: "0xf656313dF3A5F6B57d7a01D0162546E257a631a0",
  wsk: "0x382cbB7ADcA783800fF79c8a1cfDc6c24D941161",
  nft: "0xE3a727a6C47b7B539eA0A7c7D6Dae4756a95F377",
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
