import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card, Field, Row } from "../components/Ui";
import { usePopup } from "../components/Popup";
import { liquidWalletAbi } from "../abi";
import { CONTRACTS, ZERO_ADDRESS } from "../config";
import { errMessage, shortAddr } from "../lib";
import { useVaultData } from "../useVault";
import { useNoindex } from "../useNoindex";

export function AdminPage() {
  useNoindex();
  const { tr } = useI18n();
  const { address } = useAccount();
  const d = useVaultData();
  const { notify } = usePopup();

  const [finalNav, setFinalNav] = useState("");
  const [pauseNav, setPauseNav] = useState("");
  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const isManager = !!address && !!d.manager && address.toLowerCase() === d.manager.toLowerCase();

  useEffect(() => {
    if (isSuccess && txHash) {
      d.refetch();
      notify("success", tr("notifySuccessTitle"), tr("notifySuccessDesc"));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  function toUnits(v: string): bigint {
    if (!v || isNaN(Number(v))) throw new Error("Invalid number");
    return BigInt(Math.round(Number(v) * 1e6));
  }

  async function call(functionName: "finalizeEpoch" | "pause", value: string) {
    try {
      const v = toUnits(value);
      if (v <= 0n) throw new Error("Value must be > 0");
      const hash = await writeContractAsync({
        abi: liquidWalletAbi,
        address: CONTRACTS.liquidWallet,
        functionName,
        args: [v],
      });
      setTxHash(hash);
      notify(
        "info",
        functionName === "finalizeEpoch" ? tr("notifyFinalizeTitle") : tr("notifyPauseTitle"),
        tr("notifySubmittedDesc"),
      );
    } catch (e) {
      notify("error", tr("notifyErrorTitle"), errMessage(e));
    }
  }

  function onFinalize() {
    if (!window.confirm(tr("confirmFinalize"))) return;
    call("finalizeEpoch", finalNav);
  }

  function onPause() {
    if (!window.confirm(tr("confirmPause"))) return;
    call("pause", pauseNav || finalNav);
  }

  return (
    <div className="space-y-4">
      <div className="text-xs text-gray-500">
        <Link className="text-accent underline" to="/">
          ← {tr("appTitle")}
        </Link>
      </div>

      <Card title={tr("admin")}>
        {!isManager ? (
          <p className="text-sm text-gray-500">{tr("notManager")}</p>
        ) : (
          <div className="space-y-2">
            <Row k="Manager" v={shortAddr(d.manager)} />
            <Row
              k={tr("vaultLinked")}
              v={d.liquidVault && d.liquidVault !== ZERO_ADDRESS ? shortAddr(d.liquidVault) : "-"}
            />
            <Row k={tr("activeEpoch")} v={d.currentEpoch.toString()} />
            <Row k={tr("nav")} v={`${d.totalNav ? Number(d.totalNav) / 1e6 : 0} USDC`} />
            <Row k={tr("rate")} v={d.rate ? (Number(d.rate) / 1e6).toString() : "-"} />
            <Row k={tr("woundDown")} v={d.woundDown ? "yes" : "no"} />
          </div>
        )}
      </Card>

      {isManager && (
        <>
          <Card title={tr("finalizeEpoch")}>
            <p className="mb-2 text-xs text-gray-500">{tr("confirmFinalize")}</p>
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <Field
                  label={tr("newNav")}
                  value={finalNav}
                  onChange={setFinalNav}
                  placeholder="100.00"
                  suffix="USDC"
                />
              </div>
              <Button onClick={onFinalize} disabled={isPending || confirming || d.woundDown}>
                {tr("finalizeEpoch")}
              </Button>
            </div>
          </Card>

          <Card title={tr("pauseProtocol")}>
            <p className="mb-2 text-xs text-gray-500">{tr("confirmPause")}</p>
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <Field
                  label={tr("finalNav")}
                  value={pauseNav}
                  onChange={setPauseNav}
                  placeholder="100.00"
                  suffix="USDC"
                />
              </div>
              <Button
                variant="danger"
                onClick={onPause}
                disabled={isPending || confirming || d.woundDown}
              >
                {tr("pauseProtocol")}
              </Button>
            </div>
          </Card>
        </>
      )}

      {txHash && (
        <div className="text-xs text-gray-400">
          {confirming ? tr("loading") : isSuccess ? tr("txSuccess") : tr("txSubmitted")}{" "}
          <a
            className="text-accent underline"
            href={`https://explorer.testnet.arc.io/tx/${txHash}`}
            target="_blank"
            rel="noreferrer"
          >
            {txHash.slice(0, 12)}...
          </a>
        </div>
      )}
    </div>
  );
}
