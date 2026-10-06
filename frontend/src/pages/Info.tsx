import { useI18n } from "../i18n-react";
import { LineChart } from "../components/LineChart";
import { MOCK } from "../mock";
import { CONTRACTS, EXPLORER, SHARE } from "../config";

function StatCard({
  label,
  value,
  sub,
}: {
  label: string;
  value: string;
  sub?: string;
}) {
  return (
    <div className="rounded-xl border border-edge bg-card p-4">
      <div className="text-[10px] font-semibold uppercase tracking-wider text-subtle">{label}</div>
      <div className="mt-2 text-[29px] font-bold leading-none text-ink">{value}</div>
      {sub && <div className="mt-2 text-xs text-subtle">{sub}</div>}
    </div>
  );
}

export function Info() {
  const { tr } = useI18n();

  const pricePoints = MOCK.priceHistory.map((p) => ({
    label: `Epoch ${p.epoch}`,
    value: p.price,
  }));
  const supplyPoints = MOCK.priceHistory.map((p) => ({
    label: `Epoch ${p.epoch}`,
    value: p.supply,
  }));

  return (
    <div className="space-y-4">
      {/* 1. Testnet warning banner */}
      <div className="flex items-center justify-between rounded-xl border border-warnborder bg-warnbg px-3 py-2.5 text-[12px] text-warntext">
        <span>{tr("beta")}</span>
        <a
          href={`${EXPLORER}/address/${CONTRACTS.liquidWallet}`}
          target="_blank"
          rel="noreferrer"
          className="text-link underline"
        >
          {SHARE.symbol} · {CONTRACTS.liquidWallet.slice(0, 8)}...
        </a>
      </div>

      {/* 2. Overview header */}
      <div className="flex items-center justify-between px-0.5">
        <h2 className="text-[13px] font-semibold text-ink">{tr("overview")}</h2>
        <span className="inline-flex items-center gap-1.5 rounded-full border border-[#CDEEDD] bg-goodbg px-2.5 py-0.5 text-[11px] font-medium text-good">
          <span className="h-1.5 w-1.5 rounded-full bg-good" />
          Active
        </span>
      </div>

      {/* 3. Statistic cards 2x2 */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <StatCard label={tr("statActiveEpoch")} value={`#${MOCK.activeEpoch}`} sub={MOCK.epochStart} />
        <StatCard label={tr("statFundNav")} value={MOCK.fundNav} />
        <StatCard label={tr("statTotalSupply")} value={MOCK.totalSupply} />
        <StatCard label={tr("statTokenPrice")} value={MOCK.wskBVPrice} sub={MOCK.priceUnit} />
      </div>

      {/* 4. Charts 2x2 */}
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div className="rounded-xl border border-edge bg-card p-3.5">
          <div className="mb-2 text-[12px] font-semibold text-ink">{tr("chartRate")}</div>
          <LineChart
            data={pricePoints}
            stroke="#6C7CF5"
            area="rgba(108,124,245,0.13)"
            format={(n) => n.toFixed(6)}
          />
        </div>
        <div className="rounded-xl border border-edge bg-card p-3.5">
          <div className="mb-2 text-[12px] font-semibold text-ink">{tr("chartSupply")}</div>
          <LineChart
            data={supplyPoints}
            stroke="#5FD4A8"
            area="rgba(95,212,168,0.15)"
            format={(n) => n.toFixed(2)}
          />
        </div>
      </div>
    </div>
  );
}
