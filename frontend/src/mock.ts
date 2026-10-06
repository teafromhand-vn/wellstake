// Mock data so the Info dashboard can be built and reviewed independently of chain state.

export type EpochPoint = { epoch: number; price: number; supply: number };

export const MOCK = {
  activeEpoch: 4,
  epochStart: "18:23 UTC · 06 Oct 2026",
  fundNav: "0.0827 USDC",
  totalSupply: "0.2599 tWSK",
  tWSKPrice: "0.318204 USDC",
  priceUnit: "USDC / tWSK",
  token: { symbol: "tWSK", address: "0x34FEa..." },
  // Shape roughly: low -> flat -> strong increase -> decrease -> flat
  priceHistory: [
    { epoch: 0, price: 0.038462, supply: 0.2599 },
    { epoch: 1, price: 0.039, supply: 0.0 },
    { epoch: 2, price: 0.039, supply: 0.0 },
    { epoch: 3, price: 0.24, supply: 0.0 },
    { epoch: 4, price: 0.318204, supply: 0.2599 },
  ] as EpochPoint[],
};
