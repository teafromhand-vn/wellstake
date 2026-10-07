import { useEffect, useState } from "react";
import {
  useAccount,
  useWriteContract,
  useWaitForTransactionReceipt,
  useChainId,
  useSwitchChain,
} from "wagmi";
import { useI18n } from "../i18n-react";
import { usePopup } from "./Popup";
import { erc20Abi, liquidWalletAbi } from "../abi";
import { CONTRACTS, opMainnet } from "../config";
import { format6, parse6, errMessage } from "../lib";
import { useVaultData } from "../useVault";
import { DEMO, MOCK_MINT } from "../mock";

type Mode = "mint" | "redeem";

function ReadOnlyBox({ label, value, token }: { label: string; value: string; token: string }) {
  return (
    <div>
      <div className="mb-1 text-[11px] text-muted">{label}</div>
      <div className="flex items-center justify-between rounded-lg border border-edge bg-inset px-3 py-2">
        <span className="text-sm text-subtle">{value}</span>
        <span className="text-xs font-medium text-subtle">{token}</span>
      </div>
    </div>
  );
}

export function MintModule({ mode }: { mode: Mode }) {
  const { tr } = useI18n();
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const { switchChain, isPending: switching } = useSwitchChain();
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
  const onArc = chainId === opMainnet.id;

  const rate = d.rate ?? 0n;
  const feeValue = mode === "redeem" ? (value * 50n) / 10000n : 0n;
  const netValue = mode === "redeem" ? value - feeValue : 0n;
  // Estimated output, in 6-decimals, mirroring the contract math exactly:
  //   mint:   wskOut  = floor(usdcIn * 1e6 / rate)
  //   redeem: usdcOut = floor(netWsk * rate / 1e6)
  const receiveRaw =
    value <= 0n || rate <= 0n
      ? 0n
      : mode === "mint"
        ? (value * 1_000_000n) / rate
        : (netValue * rate) / 1_000_000n;

  // Balance display (real when connected, demo otherwise).
  const tWskBal = d.wskBalance !== undefined ? `${format6(d.wskBalance)} wskBV` : MOCK_MINT.wskBVBalance;
  const usdcAvail = d.usdcBalance !== undefined ? `${format6(d.usdcBalance)} USDC` : MOCK_MINT.usdcAvailable;

  const insufficient = isConnected && balance !== undefined && value > balance;
  const canSubmit = isConnected && onArc && value > 0n && !insufficient && !isPending && !confirming;

  useEffect(() => {
    if (isSuccess && txHash) {
      d.refetch();
      setAmount("");
      notify("success", tr("notifySuccessTitle"), tr("notifySuccessDesc"));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isSuccess, txHash]);

  async function run() {
    setStatus(null);
    try {
      if (!isConnected) throw new Error(tr("connect"));
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

  const inputToken = mode === "mint" ? "USDC" : "tWSK";

  return (
    <div className="relative">
      {/* Dark balance header */}
      <div className="rounded-t-xl bg-[#141A24] px-5 pb-6 pt-4 text-white">
        <div className="flex items-start justify-between">
          <div>
            <div className="text-[11px] font-medium uppercase tracking-wide text-white/50">
              tWSK balance
            </div>
            <div className="mt-1 text-[22px] font-bold leading-none">{tWskBal}</div>
          </div>
          <div className="text-right">
            <div className="text-[11px] font-medium uppercase tracking-wide text-white/50">
              USDC available
            </div>
            <div className="mt-1 text-[22px] font-bold leading-none">{usdcAvail}</div>
          </div>
        </div>
      </div>

      {/* White form card, overlapping the header */}
      <div className="-mt-4 rounded-xl border border-edge bg-card p-5 shadow-sm">
        <h3 className="text-[15px] font-bold text-ink">
          {mode === "mint" ? tr("mint") : tr("burn")}
        </h3>
        <p className="mt-1 text-[12px] text-muted">
          {mode === "mint" ? tr("mintDesc") : tr("redeemDesc")}
        </p>

        {isConnected && !onArc && (
          <div className="mt-3 flex items-center justify-between rounded-lg border border-warnborder bg-warnbg px-3 py-2 text-[12px] text-warntext">
            <span>{tr("wrongNetwork")}</span>
            <button
              disabled={switching}
              onClick={() => switchChain({ chainId: opMainnet.id })}
              className="rounded-md bg-accent px-2.5 py-1 text-[12px] font-semibold text-white transition hover:brightness-105 disabled:opacity-50"
            >
              {tr("switchNetwork")}
            </button>
          </div>
        )}

        {/* Amount */}
        <div className="mt-4">
          <div className="mb-1 text-[11px] text-muted">{tr("amount")}</div>
          <div className="flex items-center gap-2 rounded-lg border border-edge bg-inset px-3 py-2">
            <input
              className="w-full bg-transparent text-[15px] font-medium text-ink outline-none placeholder:text-subtle"
              placeholder="0.0"
              value={amount}
              inputMode="decimal"
              onChange={(e) => setAmount(e.target.value)}
            />
            <button
              type="button"
              onClick={() => balance !== undefined && setAmount(format6(balance, 6))}
              className="rounded border border-edge bg-card px-1.5 py-0.5 text-[10px] font-semibold text-muted hover:border-accent hover:text-accent"
            >
              {tr("max")}
            </button>
            <span className="text-[12px] font-semibold text-muted">{inputToken}</span>
          </div>
        </div>

        {/* Balance */}
        <div className="mt-2 text-[11px] text-muted">
          {tr("balance")}: {format6(balance) || (DEMO ? "1.2506" : "0")} {inputToken}
        </div>

        {/* Output previews: Fee + Receive (estimated) */}
        <div className="mt-3 grid grid-cols-2 gap-3">
          <ReadOnlyBox
            label={tr("fee")}
            value={mode === "redeem" && value > 0n ? format6(feeValue, 6) : "0"}
            token="tWSK"
          />
          <ReadOnlyBox
            label={tr("receiveEstimate")}
            value={value > 0n ? format6(receiveRaw, 6) : "0"}
            token={mode === "mint" ? "tWSK" : "USDC"}
          />
        </div>

        {/* Submit */}
        <button
          onClick={run}
          disabled={!canSubmit}
          className="mt-4 h-[36px] rounded-lg bg-accent px-4 text-[13px] font-semibold text-white transition hover:brightness-105 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {needsApproval
            ? tr("approveFirst")
            : mode === "mint"
              ? tr("requestMint")
              : tr("requestRedeem")}
        </button>
        {(isPending || confirming) && (
          <span className="ml-3 text-[12px] text-muted">{status ?? tr("loading")}</span>
        )}
      </div>
    </div>
  );
}
