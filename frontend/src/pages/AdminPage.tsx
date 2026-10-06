import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card, Field, Row } from "../components/Ui";
import { useToast } from "../components/Toast";
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
  const { push } = useToast();

  const [nav, setNav] = useState("");
  const [finalNav, setFinalNav] = useState("");
  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const isManager = !!address && !!d.manager && address.toLowerCase() === d.manager.toLowerCase();

  useEffect(() => {
    if (isSuccess && txHash) {
      d.refetch();
      push(tr("txSuccess"), "good");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  function toUnits(v: string): bigint {
    if (!v || isNaN(Number(v))) throw new Error("Invalid number");
    return BigInt(Math.round(Number(v) * 1e6));
  }

  async function call(functionName: "setNav" | "finalizeEpoch" | "pause", value: string) {
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
      push(tr("txSubmitted") + " " + hash.slice(0, 10) + "...", "info");
    } catch (e) {
      push(errMessage(e), "bad");
    }
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
          </div>
        )}
      </Card>

      {isManager && (
        <>
          <Card title={tr("currentNavLabel")}>
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <Field label={tr("newNav")} value={nav} onChange={setNav} placeholder="100.00" suffix="USDC" />
              </div>
              <Button onClick={() => call("setNav", nav)} disabled={isPending || confirming}>
                {tr("update")}
              </Button>
            </div>
          </Card>

          <Card title={tr("finalizeEpoch")}>
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
              <Button onClick={() => call("finalizeEpoch", finalNav)} disabled={isPending || confirming}>
                {tr("finalizeEpoch")}
              </Button>
            </div>
          </Card>

          <Card title={tr("pauseProtocol")}>
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <Field
                  label={tr("finalNav")}
                  value={finalNav}
                  onChange={setFinalNav}
                  placeholder="100.00"
                  suffix="USDC"
                />
              </div>
              <Button
                variant="danger"
                onClick={() => call("pause", finalNav)}
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
