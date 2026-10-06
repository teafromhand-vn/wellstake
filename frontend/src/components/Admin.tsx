import { useEffect, useState } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card, Field, Row } from "./Ui";
import { liquidWalletAbi } from "../abi";
import { CONTRACTS, ZERO_ADDRESS } from "../config";
import { errMessage, shortAddr } from "../lib";
import { useVaultData } from "../useVault";

export function Admin() {
  const { tr } = useI18n();
  const { address } = useAccount();
  const d = useVaultData();
  const [nav, setNav] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const isManager = !!address && !!d.manager && address.toLowerCase() === d.manager.toLowerCase();

  useEffect(() => {
    if (isSuccess && txHash) d.refetch();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  async function doSetNav() {
    setErr(null);
    try {
      const v = BigInt(Math.round(Number(nav) * 1e6));
      if (v <= 0n) throw new Error("NAV must be > 0");
      const hash = await writeContractAsync({
        abi: liquidWalletAbi,
        address: CONTRACTS.liquidWallet,
        functionName: "setNav",
        args: [v],
      });
      setTxHash(hash);
    } catch (e) {
      setErr(errMessage(e));
    }
  }

  return (
    <Card title={tr("admin")}>
      {!isManager ? (
        <p className="text-sm text-gray-500">{tr("notManager")}</p>
      ) : (
        <div className="space-y-3">
          <Row k="Manager" v={shortAddr(d.manager)} />
          <Row
            k={tr("vaultLinked")}
            v={d.liquidVault && d.liquidVault !== ZERO_ADDRESS ? shortAddr(d.liquidVault) : "-"}
          />
          <Field
            label={tr("newNav")}
            value={nav}
            onChange={setNav}
            placeholder="e.g. 100.00"
            suffix="USDC"
          />
          <Button onClick={doSetNav} disabled={isPending || confirming}>
            {tr("update")}
          </Button>
          {err && <div className="rounded-lg border border-bad/40 bg-bad/10 p-2 text-xs text-bad">{err}</div>}
          {txHash && !err && (
            <div className="text-xs text-gray-400">
              {confirming ? tr("loading") : isSuccess ? tr("txSuccess") : tr("txSubmitted")}{" "}
              <a
                className="text-accent underline"
                href={`https://explorer.testnet.arc.io/tx/${txHash}`}
                target="_blank"
                rel="noreferrer"
              >
                {txHash.slice(0, 10)}...
              </a>
            </div>
          )}
        </div>
      )}
    </Card>
  );
}
