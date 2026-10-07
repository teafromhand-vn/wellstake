import { useEffect, useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useI18n } from "../i18n-react";
import { Card, Field, Row } from "./Ui";
import { usePopup } from "./Popup";
import { vaultAbi } from "../abi";
import { CONTRACTS, EXPLORER } from "../config";
import { format6, parse6, shortAddr, errMessage } from "../lib";
import { useHoldings } from "../useHoldings";

export function VaultPanel() {
  const { tr } = useI18n();
  const { address } = useAccount();
  const h = useHoldings();
  const { notify } = usePopup();
  const [amount, setAmount] = useState("");

  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const isVaultWallet =
    !!address && !!h.vaultWallet && address.toLowerCase() === h.vaultWallet.toLowerCase();

  useEffect(() => {
    if (isSuccess && txHash) {
      h.refetch();
      notify("success", tr("notifySuccessTitle"), tr("notifySuccessDesc"));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  async function call(fn: "pull" | "returnFunds" | "invest") {
    try {
      const v = parse6(amount);
      if (v <= 0n) throw new Error("Amount must be > 0");
      const hash = await writeContractAsync({
        abi: vaultAbi,
        address: CONTRACTS.vault,
        functionName: fn,
        args: [v],
      });
      setTxHash(hash);
      notify("info", tr("notifySubmittedTitle"), tr("notifySubmittedDesc"));
    } catch (e) {
      notify("error", tr("notifyErrorTitle"), errMessage(e));
    }
  }

  return (
    <Card title={tr("vaultPanel")}>
      {!isVaultWallet ? (
        <p className="text-sm text-muted">{tr("notVaultWallet")}</p>
      ) : (
        <div className="space-y-3">
          <Row k={tr("vaultWalletLabel")} v={shortAddr(h.vaultWallet)} />
          <Row k={tr("vaultUsdcHeld")} v={`${format6(h.usdc.vault, 6)} USDC`} />
          <Row k={tr("liquidUsdcAvail")} v={`${format6(h.usdc.liquid, 6)} USDC`} />

          <Field
            label={tr("amountUsdc")}
            value={amount}
            onChange={setAmount}
            placeholder="0.0"
            suffix="USDC"
            onMax={() => h.usdc.liquid !== undefined && setAmount(format6(h.usdc.liquid, 6))}
            maxLabel={tr("max")}
          />

          <div className="flex flex-wrap gap-2">
            <button
              disabled={isPending || confirming}
              onClick={() => call("pull")}
              className="rounded-lg bg-accent px-3 py-2 text-[12px] font-semibold text-white transition hover:brightness-105 disabled:opacity-40"
            >
              {tr("pull")}
            </button>
            <button
              disabled={isPending || confirming}
              onClick={() => call("returnFunds")}
              className="rounded-lg border border-edge bg-inset px-3 py-2 text-[12px] font-semibold text-ink transition hover:bg-[#ECEEF2] disabled:opacity-40"
            >
              {tr("returnFunds")}
            </button>
            <button
              disabled={isPending || confirming}
              onClick={() => call("invest")}
              className="rounded-lg border border-edge bg-inset px-3 py-2 text-[12px] font-semibold text-ink transition hover:bg-[#ECEEF2] disabled:opacity-40"
            >
              {tr("invest")}
            </button>
          </div>

          {txHash && (
            <div className="text-xs text-muted">
              {confirming ? tr("loading") : isSuccess ? tr("txSuccess") : tr("txSubmitted")}{" "}
              <a
                className="text-accent underline"
                href={`${EXPLORER}/tx/${txHash}`}
                target="_blank"
                rel="noreferrer"
              >
                {txHash.slice(0, 12)}...
              </a>
            </div>
          )}
        </div>
      )}
    </Card>
  );
}
