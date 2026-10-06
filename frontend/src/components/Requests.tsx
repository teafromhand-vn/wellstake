import { useEffect, useMemo, useState } from "react";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { useI18n } from "../i18n-react";
import { usePopup } from "./Popup";
import { liquidWalletAbi } from "../abi";
import { CONTRACTS } from "../config";
import { format6, errMessage } from "../lib";
import { useVaultData } from "../useVault";
import { DEMO, MOCK_REQUESTS } from "../mock";

type Req = {
  id: bigint;
  requestType: number;
  owner: `0x${string}`;
  epoch: bigint;
  amount: bigint;
  claimed: boolean;
};

export function Requests() {
  const { tr } = useI18n();
  const { address } = useAccount();
  const d = useVaultData();
  const { notify } = usePopup();

  const { data: nextIdData, refetch: refetchNext } = useReadContract({
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
    if (!data || !address) return [];
    return ids
      .map((id, i) => {
        const r = data[i]?.result as
          | [number, `0x${string}`, bigint, bigint, bigint, bigint, boolean]
          | undefined;
        if (!r) return null;
        return {
          id,
          requestType: Number(r[0]),
          owner: r[1],
          epoch: r[2],
          amount: r[3],
          claimed: r[6],
        } as Req;
      })
      .filter((x): x is Req => x !== null && x.owner.toLowerCase() === address.toLowerCase())
      .sort((a, b) => (a.id < b.id ? 1 : -1));
  }, [data, ids, address]);

  const claimable = reqs.filter((r) => !r.claimed && r.epoch < d.currentEpoch);

  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (isSuccess && txHash) {
      refetch();
      refetchNext();
      d.refetch();
      notify("success", tr("notifySuccessTitle"), tr("notifySuccessDesc"));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  async function claimAll() {
    try {
      const list = claimable.map((r) => r.id);
      if (list.length === 0) return;
      const hash = await writeContractAsync({
        abi: liquidWalletAbi,
        address: CONTRACTS.liquidWallet,
        functionName: "claimMany",
        args: [list],
      });
      setTxHash(hash);
      notify("info", tr("notifyClaimTitle"), tr("notifySubmittedDesc"));
    } catch (e) {
      notify("error", tr("notifyErrorTitle"), errMessage(e));
    }
  }

  const showDemo = DEMO && (!address || reqs.length === 0);
  const demoRows = showDemo ? MOCK_REQUESTS : [];

  return (
    <div className="rounded-xl border border-edge bg-card p-4">
      <div className="flex items-center justify-between">
        <h3 className="text-[13px] font-semibold text-ink">{tr("myRequests")}</h3>
        <div className="flex items-center gap-3">
          <span className="hidden text-[11px] text-muted sm:inline">{tr("claimAllHint")}</span>
          <button
            disabled={claimable.length === 0 || isPending || confirming}
            onClick={claimAll}
            className="rounded-lg border border-edge bg-inset px-3 py-1.5 text-[12px] font-semibold text-ink transition hover:bg-[#ECEEF2] disabled:cursor-not-allowed disabled:opacity-40"
          >
            {tr("claimMany")} ({claimable.length})
          </button>
        </div>
      </div>

      <div className="mt-3 overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-edge text-left text-[11px] font-medium text-subtle">
              <th className="py-2 pr-2 font-medium">{tr("id")}</th>
              <th className="py-2 pr-2 font-medium">{tr("type")}</th>
              <th className="py-2 pr-2 font-medium">{tr("epoch")}</th>
              <th className="py-2 pr-2 text-right font-medium">{tr("amount")}</th>
              <th className="py-2 pr-2 font-medium">{tr("status")}</th>
            </tr>
          </thead>
          <tbody>
            {demoRows.map((r) => (
              <tr key={`demo-${r.id}`} className="border-b border-edge/60 last:border-0">
                <td className="py-2.5 pr-2 text-[13px] text-ink">#{r.id}</td>
                <td className="py-2.5 pr-2">
                  <span className="rounded bg-goodbg px-1.5 py-0.5 text-[10px] font-semibold text-good">
                    {r.type}
                  </span>
                </td>
                <td className="py-2.5 pr-2 text-[13px] text-muted">{r.epoch}</td>
                <td className="py-2.5 pr-2 text-right text-[13px] text-ink">{r.amount}</td>
                <td className="py-2.5 pr-2 text-[12px] text-muted">{r.status}</td>
              </tr>
            ))}

            {!showDemo &&
              reqs.map((r) => {
                const ready = !r.claimed && r.epoch < d.currentEpoch;
                return (
                  <tr key={r.id.toString()} className="border-b border-edge/60 last:border-0">
                    <td className="py-2.5 pr-2 text-[13px] text-ink">#{r.id.toString()}</td>
                    <td className="py-2.5 pr-2">
                      <span
                        className={`rounded px-1.5 py-0.5 text-[10px] font-semibold ${
                          r.requestType === 0 ? "bg-goodbg text-good" : "bg-accent/10 text-accent"
                        }`}
                      >
                        {r.requestType === 0 ? "MINT" : "REDEEM"}
                      </span>
                    </td>
                    <td className="py-2.5 pr-2 text-[13px] text-muted">{r.epoch.toString()}</td>
                    <td className="py-2.5 pr-2 text-right text-[13px] text-ink">
                      {r.requestType === 0 ? `${format6(r.amount)} USDC` : `${format6(r.amount)} tWSK`}
                    </td>
                    <td className="py-2.5 pr-2 text-[12px]">
                      {r.claimed ? (
                        <span className="text-muted">{tr("claimed")}</span>
                      ) : ready ? (
                        <span className="text-[#B98900]">{tr("pending")}</span>
                      ) : (
                        <span className="text-muted">{tr("notFinalized")}</span>
                      )}
                    </td>
                  </tr>
                );
              })}

            {!showDemo && reqs.length === 0 && (
              <tr>
                <td colSpan={5} className="py-6 text-center text-[13px] text-muted">
                  {tr("noRequests")}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
