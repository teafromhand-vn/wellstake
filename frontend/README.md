# Wellstake V1 - Beta Frontend

Static React app (Vite + TypeScript + Tailwind + wagmi/viem) for the Wellstake V1 preview
on **Arc Testnet** (chain `5042002`). Deploys to Vercel as a static site.

## Features

- Injected wallet (MetaMask) connect / disconnect
- Add + switch to Arc Testnet
- Overview: fund NAV, rate, share supply, liquid USDC, your balances
- Mint: approve USDC -> `requestMint` -> claim tWSK
- Redeem: approve tWSK -> `requestRedeem` -> claim USDC
- Request table (read directly on-chain) with single/batch claim and "mine only" filter
- Admin tab (manager only): `setNav`
- Bilingual EN / VI

## Active deployment (Arc Testnet)

| Contract | Address |
|---|---|
| LiquidWallet | `0xab3bc58786c8a2B8149A49F5fEB3B15F7afC054C` |
| WellstakeVault | `0x6D0448BA63Bb2dD8dED5cE73e4faa424f6F39b0a` |
| tWSK | `0xF5FC3F9839dab245b3fD3f54059d2Fa1642ba85a` |
| PendingRequestNFT | `0xDE64b96874c5Beb052F3fC11af82dF888EbbFE44` |
| USDC (settlement) | `0x3600000000000000000000000000000000000000` |

Addresses live in `src/config.ts`.

## Local development

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # outputs dist/
npm run preview
```

## Deploy to Vercel

### Option A - dashboard
1. Push this repo to GitHub (already done).
2. In Vercel: **Add New -> Project -> Import** the repo.
3. Set **Root Directory** to `frontend`.
4. Framework preset: **Vite**. Build `npm run build`, output `dist`.
5. Deploy.

### Option B - CLI
```bash
npm i -g vercel
cd frontend
vercel          # preview
vercel --prod   # production
```

`vercel.json` already contains the SPA rewrite.

## Notes

- USDC is a real ERC-20 on Arc; users need test USDC to mint. Gas is the native Arc testnet
  currency.
- `forge script` simulation does not work on Arc because of a custom blocklist precompile; this
  does not affect the static frontend, which talks to the RPC directly.
