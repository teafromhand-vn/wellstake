import { useEffect, useMemo, useState } from "react";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card } from "./Ui";
import { usePopup } from "./Popup";
import { liquidWalletAbi } from "../abi";
import { CONTRACTS } from "../config";
import { format6, errMessage } from "../lib";
import { useVaultData } from "../useVault";

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

  return (
    <Card
      title={tr("myRequests")}
      right={
        <div className="flex items-center gap-2">
          <span className="hidden text-[11px] text-muted sm:inline">{tr("claimAllHint")}</span>
          <Button variant="ghost" disabled={claimable.length === 0 || isPending || confirming} onClick={claimAll}>
            {tr("claimMany")} ({claimable.length})
          </Button>
        </div>
      }
    >
      {!address ? (
        <p className="py-6 text-center text-sm text-muted">{tr("connect")}</p>
      ) : reqs.length === 0 ? (
        <p className="py-6 text-center text-sm text-muted">{tr("noRequests")}</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-edge text-left text-xs text-muted">
                <th className="py-2 pr-2">{tr("id")}</th>
                <th className="py-2 pr-2">{tr("type")}</th>
                <th className="py-2 pr-2">{tr("epoch")}</th>
                <th className="py-2 pr-2 text-right">{tr("amount")}</th>
                <th className="py-2 pr-2">{tr("status")}</th>
              </tr>
            </thead>
            <tbody>
              {reqs.map((r) => {
                const ready = !r.claimed && r.epoch < d.currentEpoch;
                return (
                  <tr key={r.id.toString()} className="border-b border-edge/40">
                    <td className="py-2 pr-2 text-ink">#{r.id.toString()}</td>
                    <td className="py-2 pr-2">
                      <span
                        className={`rounded px-1.5 py-0.5 text-[11px] ${
                          r.requestType === 0 ? "bg-good/10 text-good" : "bg-accent/10 text-accent"
                        }`}
                      >
                        {r.requestType === 0 ? "MINT" : "REDEEM"}
                      </span>
                    </td>
                    <td className="py-2 pr-2 text-muted">{r.epoch.toString()}</td>
                    <td className="py-2 pr-2 text-right text-ink">
                      {r.requestType === 0 ? `${format6(r.amount)} USDC` : `${format6(r.amount)} tWSK`}
                    </td>
                    <td className="py-2 pr-2">
                      {r.claimed ? (
                        <span className="text-xs text-muted">{tr("claimed")}</span>
                      ) : ready ? (
                        <span className="text-xs text-yellow-300">{tr("pending")}</span>
                      ) : (
                        <span className="text-xs text-muted">{tr("notFinalized")}</span>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
