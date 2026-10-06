import { useMemo } from "react";
import { useReadContracts, useReadContract } from "wagmi";
import { liquidWalletAbi } from "./abi";
import { CONTRACTS } from "./config";

export type EpochPoint = { epoch: number; totalNav: number; rate: number };

/// Builds rate / TVL history by reading the public `epochs(i)` mapping for every epoch from 0 to
/// the current one. This avoids eth_getLogs, which the Arc RPC restricts to ~2000-block ranges.
export function useHistory() {
  const { data: currentEpochData } = useReadContract({
    abi: liquidWalletAbi,
    address: CONTRACTS.liquidWallet,
    functionName: "currentEpoch",
    query: { refetchInterval: 15000 },
  });
  const currentEpoch = (currentEpochData as bigint | undefined) ?? 0n;

  const count = Number(currentEpoch) + 1;

  const { data, isLoading } = useReadContracts({
    contracts: Array.from({ length: count }, (_, i) => ({
      abi: liquidWalletAbi,
      address: CONTRACTS.liquidWallet,
      functionName: "epochs" as const,
      args: [BigInt(i)],
    })),
    query: { refetchInterval: 15000 },
  });

  const points: EpochPoint[] = useMemo(() => {
    if (!data) return [];
    const out: EpochPoint[] = [];
    for (let i = 0; i < count; i++) {
      const r = data[i]?.result as [bigint, bigint, bigint, bigint, boolean] | undefined;
      if (!r) continue;
      out.push({
        epoch: i,
        totalNav: Number(r[0]) / 1e6,
        rate: Number(r[1]) / 1e6,
      });
    }
    return out;
  }, [data, count]);

  return { points, loading: isLoading, error: null as string | null };
}
