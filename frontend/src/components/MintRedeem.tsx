import { useEffect, useState } from "react";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
  useChainId,
} from "wagmi";
import { useI18n } from "../i18n-react";
import { Button, Card, Field } from "./Ui";
import { usePopup } from "./Popup";
import { erc20Abi, liquidWalletAbi } from "../abi";
import { CONTRACTS, arcTestnet } from "../config";
import { format6, parse6, errMessage } from "../lib";
import { useVaultData } from "../useVault";

type Mode = "mint" | "redeem";

export function MintRedeem({ mode, onDone }: { mode: Mode; onDone: () => void }) {
  const { tr } = useI18n();
  const { address } = useAccount();
  const chainId = useChainId();
  const d = useVaultData();
  const { notify } = usePopup();
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

  // Derived read-only values (mirror the contract math, rounded down).
  const feeValue = mode === "redeem" ? (value * 50n) / 10000n : 0n;
  const netValue = mode === "redeem" ? value - feeValue : 0n;
  // Mint: estimated tWSK out = floor(usdcIn * 1e6 / rate)
  const rate = d.rate ?? 0n;
  const receiveValue = mode === "mint" && rate > 0n ? (value * 1_000_000n) / rate : 0n;

  useEffect(() => {
    if (isSuccess && txHash) {
      d.refetch();
      notify("success", tr("notifySuccessTitle"), tr("notifySuccessDesc"));
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
        notify("info", tr("notifyApproveTitle"), tr("notifyApproveDesc"));
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
      notify("info", tr("notifySubmittedTitle"), tr("notifySubmittedDesc"));
    } catch (e) {
      setStatus(null);
      notify("error", tr("notifyErrorTitle"), errMessage(e));
    }
  }

  return (
    <Card title={mode === "mint" ? tr("mint") : tr("redeem")}>
      <p className="mb-3 text-xs text-muted">
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
      <div className="mt-1 text-xs text-muted">
        {tr("balance")}: {format6(balance)} {mode === "mint" ? "USDC" : "tWSK"}
      </div>

      <div className="mt-3 grid grid-cols-2 gap-3">
        <Field
          label={tr("fee")}
          value={value > 0n ? format6(feeValue, 6) : "0"}
          onChange={() => {}}
          suffix="tWSK"
          disabled
        />
        {mode === "redeem" ? (
          <Field
            label={tr("burnAmount")}
            value={value > 0n ? format6(netValue, 6) : "0"}
            onChange={() => {}}
            suffix="tWSK"
            disabled
          />
        ) : (
          <Field
            label={tr("receiveEstimate")}
            value={value > 0n ? format6(receiveValue, 6) : "0"}
            onChange={() => {}}
            suffix="tWSK"
            disabled
          />
        )}
      </div>

      <div className="mt-3 flex items-center gap-2">
        <Button onClick={run} disabled={isPending || confirming || !address}>
          {needsApproval ? tr("approveFirst") : mode === "mint" ? tr("requestMint") : tr("requestRedeem")}
        </Button>
        {(isPending || confirming) && <span className="text-xs text-muted">{status ?? tr("loading")}</span>}
      </div>

      <p className="mt-3 text-[11px] text-muted">{tr("claimNotReady")}</p>
    </Card>
  );
}

