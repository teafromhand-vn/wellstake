import { useEffect, useState } from "react";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
  useChainId,
} from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card, Field } from "./Ui";
import { useToast } from "./Toast";
import { erc20Abi, liquidWalletAbi } from "../abi";
import { CONTRACTS, arcTestnet } from "../config";
import { format6, parse6, errMessage } from "../lib";
import { useVaultData } from "../useVault";

type Mode = "mint" | "redeem";

export function MintRedeem({ onDone }: { onDone: () => void }) {
  const { tr } = useI18n();
  const { address } = useAccount();
  const chainId = useChainId();
  const d = useVaultData();
  const { push } = useToast();
  const [mode, setMode] = useState<Mode>("mint");
  const [amount, setAmount] = useState("");
  const [status, setStatus] = useState<string | null>(null);

  const { writeContractAsync, isPending } = useWriteContract();
  const [txHash, setTxHash] = useState<`0x${string}` | undefined>();
  const { isLoading: confirming, isSuccess } = useWaitForTransactionReceipt({ hash: txHash });

  const value = parse6(amount);
  const spender = CONTRACTS.liquidWallet;
  const token = mode === "mint" ? CONTRACTS.usdc : CONTRACTS.wsk;
  const allowance = mode === "mint" ? d.usdcAllowance : d.wskAllowance;
  const balance = mode === "mint" ? d.usdcBalance : d.wskBalance;
  const needsApproval = allowance !== undefined && value > 0n && allowance < value;
  const onArc = chainId === arcTestnet.id;

  useEffect(() => {
    if (isSuccess && txHash) {
      d.refetch();
      push(tr("txSuccess"), "good");
      onDone();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  async function run() {
    setStatus(null);
    try {
      if (!onArc) throw new Error(tr("switchNetwork"));
      if (value <= 0n) throw new Error("Amount must be > 0");
      if (balance !== undefined && value > balance) throw new Error("Insufficient balance");

      if (needsApproval) {
        setStatus(tr("approving"));
        const hash = await writeContractAsync({
          abi: erc20Abi,
          address: token,
          functionName: "approve",
          args: [spender, value],
        });
        setTxHash(hash);
        push(tr("txSubmitted") + " " + hash.slice(0, 10) + "...", "info");
        return;
      }

      setStatus(tr("requesting"));
      const hash =
        mode === "mint"
          ? await writeContractAsync({
              abi: liquidWalletAbi,
              address: spender,
              functionName: "requestMint",
              args: [value],
            })
          : await writeContractAsync({
              abi: liquidWalletAbi,
              address: spender,
              functionName: "requestRedeem",
              args: [value],
            });
      setTxHash(hash);
      push(tr("txSubmitted") + " " + hash.slice(0, 10) + "...", "info");
    } catch (e) {
      setStatus(null);
      push(errMessage(e), "bad");
    }
  }

  return (
    <Card title={tr("mint") + " / " + tr("redeem")}>
      <div className="mb-3 flex gap-2">
        <button
          className={`flex-1 rounded-lg px-3 py-2 text-sm ${mode === "mint" ? "bg-accent text-ink" : "bg-panel2 text-gray-300"}`}
          onClick={() => {
            setMode("mint");
            setAmount("");
            setStatus(null);
          }}
        >
          {tr("mint")}
        </button>
        <button
          className={`flex-1 rounded-lg px-3 py-2 text-sm ${mode === "redeem" ? "bg-accent text-ink" : "bg-panel2 text-gray-300"}`}
          onClick={() => {
            setMode("redeem");
            setAmount("");
            setStatus(null);
          }}
        >
          {tr("redeem")}
        </button>
      </div>

      <p className="mb-3 text-xs text-gray-400">
        {mode === "mint" ? tr("mintDesc") : tr("redeemDesc")}
      </p>

      <Field
        label={tr("amount")}
        value={amount}
        onChange={(v) => setAmount(v)}
        placeholder="0.0"
        onMax={() => {
          if (balance !== undefined) setAmount(format6(balance, 6));
        }}
        maxLabel={tr("max")}
        suffix={mode === "mint" ? "USDC" : "tWSK"}
      />
      <div className="mt-1 text-xs text-gray-500">
        {tr("balance")}: {format6(balance)} {mode === "mint" ? "USDC" : "tWSK"}
      </div>

      <div className="mt-3 flex items-center gap-2">
        <Button onClick={run} disabled={isPending || confirming || !address}>
          {needsApproval ? tr("approveFirst") : mode === "mint" ? tr("requestMint") : tr("requestRedeem")}
        </Button>
        {(isPending || confirming) && <span className="text-xs text-gray-400">{status ?? tr("loading")}</span>}
      </div>

      <p className="mt-3 text-[11px] text-gray-500">{tr("claimNotReady")}</p>
    </Card>
  );
}

