import { useEffect, useMemo, useState } from "react";
import { useAccount, useReadContract, useReadContracts, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card } from "./Ui";
import { liquidWalletAbi } from "../abi";
import { CONTRACTS } from "../config";
import { format6, shortAddr, errMessage } from "../lib";
import { useVaultData } from "../useVault";

type Req = {
  id: bigint;
  requestType: number;
  owner: `0x${string}`;
  amount: bigint;
  fee: bigint;
  net: bigint;
  claimed: boolean;
};

export function Requests() {
  const { tr } = useI18n();
  const { address } = useAccount();
  const d = useVaultData();
  const [mineOnly, setMineOnly] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [err, setErr] = useState<string | null>(null);

  const { data: nextIdData } = useReadContract({
    abi: liquidWalletAbi,
    address: CONTRACTS.liquidWallet,
    functionName: "nextRequestId",
    query: { refetchInterval: 8000 },
  });
  const nextId = (nextIdData as bigint | undefined) ?? 1n;

  const ids = useMemo(() => {
    const arr: bigint[] = [];
    for (let i = 1n; i < nextId; i++) arr.push(i);
    return arr;
  }, [nextId]);

  const { data, refetch } = useReadContracts({
    contracts: ids.map((id) => ({
      abi: liquidWalletAbi,
      address: CONTRACTS.liquidWallet,
      functionName: "requests",
      args: [id],
    })),
    query: { refetchInterval: 8000 },
  });

  const reqs: Req[] = useMemo(() => {
    if (!data) return [];
    return ids
      .map((id, i) => {
        const r = data[i]?.result as
          | [number, `0x${string}`, bigint, bigint, bigint, boolean]
          | undefined;
        if (!r) return null;
        return {
          id,
          requestType: Number(r[0]),
          owner: r[1],
          amount: r[2],
          fee: r[3],
          net: r[4],
          claimed: r[5],
        } as Req;
      })
      .filter((x): x is Req => x !== null && x.owner !== "0x0000000000000000000000000000000000000000")
      .sort((a, b) => (a.id < b.id ? 1 : -1));
  }, [data, ids]);

  const shown = mineOnly && address ? reqs.filter((r) => r.owner.toLowerCase() === address.toLowerCase()) : reqs;

  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess && txHash) {
      refetch();
      d.refetch();
      setSelected(new Set());
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  async function claim(id: bigint) {
    setErr(null);
    try {
      const hash = await writeContractAsync({
        abi: liquidWalletAbi,
        address: CONTRACTS.liquidWallet,
        functionName: "claim",
        args: [id],
      });
      setTxHash(hash);
    } catch (e) {
      setErr(errMessage(e));
    }
  }

  async function claimMany() {
    setErr(null);
    try {
      const list = Array.from(selected).map((s) => BigInt(s));
      if (list.length === 0) return;
      const hash = await writeContractAsync({
        abi: liquidWalletAbi,
        address: CONTRACTS.liquidWallet,
        functionName: "claimMany",
        args: [list],
      });
      setTxHash(hash);
    } catch (e) {
      setErr(errMessage(e));
    }
  }

  function toggle(id: bigint) {
    const key = id.toString();
    setSelected((prev) => {
      const n = new Set(prev);
      if (n.has(key)) n.delete(key);
      else n.add(key);
      return n;
    });
  }

  return (
    <Card
      title={tr("allRequests")}
      right={
        <div className="flex items-center gap-2">
          <label className="flex items-center gap-1 text-xs text-gray-400">
            <input type="checkbox" checked={mineOnly} onChange={(e) => setMineOnly(e.target.checked)} />
            {tr("filterMine")}
          </label>
          <Button variant="ghost" disabled={selected.size === 0 || isPending || confirming} onClick={claimMany}>
            {tr("claimMany")} ({selected.size})
          </Button>
        </div>
      }
    >
      {shown.length === 0 ? (
        <p className="py-6 text-center text-sm text-gray-500">{tr("noRequests")}</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-edge text-left text-xs text-gray-500">
                <th className="py-2 pr-2"></th>
                <th className="py-2 pr-2">{tr("id")}</th>
                <th className="py-2 pr-2">{tr("type")}</th>
                <th className="py-2 pr-2">{tr("owner")}</th>
                <th className="py-2 pr-2 text-right">{tr("amount")}</th>
                <th className="py-2 pr-2">{tr("status")}</th>
                <th className="py-2 pr-2 text-right">{tr("action")}</th>
              </tr>
            </thead>
            <tbody>
              {shown.map((r) => (
                <tr key={r.id.toString()} className="border-b border-edge/40">
                  <td className="py-2 pr-2">
                    {!r.claimed && (
                      <input
                        type="checkbox"
                        checked={selected.has(r.id.toString())}
                        onChange={() => toggle(r.id)}
                      />
                    )}
                  </td>
                  <td className="py-2 pr-2 text-gray-300">#{r.id.toString()}</td>
                  <td className="py-2 pr-2">
                    <span
                      className={`rounded px-1.5 py-0.5 text-[11px] ${
                        r.requestType === 0 ? "bg-good/10 text-good" : "bg-accent/10 text-accent"
                      }`}
                    >
                      {r.requestType === 0 ? "MINT" : "REDEEM"}
                    </span>
                  </td>
                  <td className="py-2 pr-2 text-gray-400">{shortAddr(r.owner)}</td>
                  <td className="py-2 pr-2 text-right text-gray-200">
                    {r.requestType === 0 ? `${format6(r.amount)} USDC` : `${format6(r.amount)} tWSK`}
                  </td>
                  <td className="py-2 pr-2">
                    {r.claimed ? (
                      <span className="text-xs text-gray-500">{tr("claimed")}</span>
                    ) : (
                      <span className="text-xs text-yellow-300">{tr("pending")}</span>
                    )}
                  </td>
                  <td className="py-2 pr-2 text-right">
                    <Button
                      variant="ghost"
                      disabled={r.claimed || isPending || confirming}
                      onClick={() => claim(r.id)}
                    >
                      {tr("claim")}
                    </Button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {err && <div className="mt-3 rounded-lg border border-bad/40 bg-bad/10 p-2 text-xs text-bad">{err}</div>}
    </Card>
  );
}
