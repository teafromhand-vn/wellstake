import { useEffect, useState } from "react";
import { useAccount, useConfig, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { waitForTransactionReceipt } from "wagmi/actions";
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
  const config = useConfig();
  const h = useHoldings();
  const { notify } = usePopup();
  const [amount, setAmount] = useState("");
  const [step, setStep] = useState<string | null>(null);

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

  const busy = isPending || confirming;

  // Pull from LiquidWallet into the Vault, then forward it to the vaultWallet EOA (2 txs).
  async function pullAndInvest() {
    try {
      const v = parse6(amount);
      if (v <= 0n) throw new Error("Amount must be > 0");

      setStep(tr("pulling"));
      const pullHash = await writeContractAsync({
        abi: vaultAbi,
        address: CONTRACTS.vault,
        functionName: "pull",
        args: [v],
      });
      await waitForTransactionReceipt(config, { hash: pullHash });

      setStep(tr("investing"));
      const investHash = await writeContractAsync({
        abi: vaultAbi,
        address: CONTRACTS.vault,
        functionName: "invest",
        args: [v],
      });
      setTxHash(investHash);
      notify("info", tr("notifySubmittedTitle"), tr("notifySubmittedDesc"));
    } catch (e) {
      notify("error", tr("notifyErrorTitle"), errMessage(e));
    } finally {
      setStep(null);
    }
  }

  async function returnFunds() {
    try {
      const v = parse6(amount);
      if (v <= 0n) throw new Error("Amount must be > 0");
      const hash = await writeContractAsync({
        abi: vaultAbi,
        address: CONTRACTS.vault,
        functionName: "returnFunds",
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

          <div className="flex flex-wrap items-center gap-2">
            <button
              disabled={busy}
              onClick={pullAndInvest}
              className="rounded-lg bg-accent px-3 py-2 text-[12px] font-semibold text-white transition hover:brightness-105 disabled:opacity-40"
            >
              {tr("pullInvest")}
            </button>
            <button
              disabled={busy}
              onClick={returnFunds}
              className="rounded-lg border border-edge bg-inset px-3 py-2 text-[12px] font-semibold text-ink transition hover:bg-[#ECEEF2] disabled:opacity-40"
            >
              {tr("returnFunds")}
            </button>
            {busy && <span className="text-xs text-muted">{step ?? tr("loading")}</span>}
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
