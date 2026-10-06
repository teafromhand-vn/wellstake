import { useEffect, useState } from "react";
import { useReadContract } from "wagmi";
import { createPublicClient, http } from "viem";
import { opMainnet, CONTRACTS } from "./config";
import { liquidWalletAbi } from "./abi";

const client = createPublicClient({ chain: opMainnet, transport: http() });

/// Returns the open epoch's start time (UTC) by reading its startBlock and fetching the block
/// timestamp.
export function useEpochStart(epoch: bigint) {
  const [timestamp, setTimestamp] = useState<bigint | null>(null);

  const { data } = useReadContract({
    abi: liquidWalletAbi,
    address: CONTRACTS.liquidWallet,
    functionName: "epochs",
    args: [epoch],
    query: { refetchInterval: 15000 },
  });

  const startBlock = (data as [bigint, bigint, bigint, bigint, boolean] | undefined)?.[2];

  useEffect(() => {
    let cancelled = false;
    async function load() {
      if (startBlock === undefined) return;
      try {
        const block = await client.getBlock({ blockNumber: startBlock });
        if (!cancelled) setTimestamp(block.timestamp);
      } catch {
        /* ignore */
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [startBlock]);

  return timestamp;
}
