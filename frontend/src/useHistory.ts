import { useEffect, useState } from "react";
import { createPublicClient, http, parseAbiItem, formatUnits } from "viem";
import { arcTestnet, CONTRACTS } from "./config";

export type NavPoint = { block: bigint; totalNav: number; rate: number };

const epochFinalizedEvent = parseAbiItem(
  "event EpochFinalized(uint256 indexed epoch, uint256 nav, uint256 rate, uint256 endBlock)",
);

const client = createPublicClient({
  chain: arcTestnet,
  transport: http(),
});

/// Reconstructs rate / TVL history from EpochFinalized events. Scans the recent window and,
/// if empty, retries from genesis (bounded RPCs may reject a full scan).
export function useHistory() {
  const [points, setPoints] = useState<NavPoint[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError(null);
      try {
        const latest = await client.getBlockNumber();
        const WINDOW = 500_000n;
        const from = latest > WINDOW ? latest - WINDOW : 0n;
        let logs = await client.getLogs({
          address: CONTRACTS.liquidWallet,
          event: epochFinalizedEvent,
          fromBlock: from,
          toBlock: latest,
        });
        if (logs.length === 0 && from > 0n) {
          logs = await client.getLogs({
            address: CONTRACTS.liquidWallet,
            event: epochFinalizedEvent,
            fromBlock: 0n,
            toBlock: latest,
          });
        }
        const pts: NavPoint[] = logs.map((l) => ({
          block: l.blockNumber ?? 0n,
          totalNav: Number(formatUnits(l.args.nav ?? 0n, 6)),
          rate: Number(formatUnits(l.args.rate ?? 0n, 6)),
        }));
        if (!cancelled) setPoints(pts);
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      } finally {
        if (!cancelled) setLoading(false);
      }
    }
    load();
    const id = setInterval(load, 20000);
    return () => {
      cancelled = true;
      clearInterval(id);
    };
  }, []);

  return { points, loading, error };
}
