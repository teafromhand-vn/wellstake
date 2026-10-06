import { useEffect, useMemo, useState } from "react";
import { useReadContracts, useReadContract } from "wagmi";
import { erc20Abi, liquidWalletAbi } from "./abi";
import { CONTRACTS } from "./config";

export type EpochPoint = { epoch: number; totalNav: number; rate: number; supply: number };

const STORE_KEY = "wellstake.supplyByEpoch";

function loadSnapshots(): Record<string, number> {
  try {
    return JSON.parse(localStorage.getItem(STORE_KEY) || "{}");
  } catch {
    return {};
  }
}

/// Builds epoch history by reading the public `epochs(i)` mapping for every epoch from 0 to the
/// current one (avoids eth_getLogs, which the Arc RPC restricts). Total supply per epoch is not
/// stored on-chain, so the current supply is snapshotted per epoch in localStorage and merged in.
export function useHistory() {
  const { data: currentEpochData } = useReadContract({
    abi: liquidWalletAbi,
    address: CONTRACTS.liquidWallet,
    functionName: "currentEpoch",
    query: { refetchInterval: 15000 },
  });
  const currentEpoch = (currentEpochData as bigint | undefined) ?? 0n;

  const { data: supplyData } = useReadContract({
    abi: erc20Abi,
    address: CONTRACTS.wsk,
    functionName: "totalSupply",
    query: { refetchInterval: 15000 },
  });
  const liveSupply = supplyData !== undefined ? Number(supplyData as bigint) / 1e6 : 0;

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

  const [snapshots, setSnapshots] = useState<Record<string, number>>({});
  useEffect(() => {
    setSnapshots(loadSnapshots());
  }, []);

  // Record the live supply for the open epoch whenever it changes.
  useEffect(() => {
    if (supplyData === undefined) return;
    const key = Number(currentEpoch).toString();
    const cur = loadSnapshots();
    if (cur[key] !== liveSupply) {
      cur[key] = liveSupply;
      localStorage.setItem(STORE_KEY, JSON.stringify(cur));
      setSnapshots(cur);
    }
  }, [liveSupply, currentEpoch, supplyData]);

  const points: EpochPoint[] = useMemo(() => {
    if (!data) return [];
    const out: EpochPoint[] = [];
    for (let i = 0; i < count; i++) {
      const r = data[i]?.result as [bigint, bigint, bigint, bigint, boolean] | undefined;
      if (!r) continue;
      const snap = snapshots[String(i)];
      out.push({
        epoch: i,
        totalNav: Number(r[0]) / 1e6,
        rate: Number(r[1]) / 1e6,
        supply: snap !== undefined ? snap : i === Number(currentEpoch) ? liveSupply : 0,
      });
    }
    return out;
  }, [data, count, snapshots, liveSupply, currentEpoch]);

  return { points, loading: isLoading, error: null as string | null };
}
