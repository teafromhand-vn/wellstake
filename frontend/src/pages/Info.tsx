import { useI18n } from "../i18n-react";
import { useVaultData } from "../useVault";
import { useEpochStart } from "../useEpochStart";
import { format6 } from "../lib";
import { Card, Badge } from "../components/Ui";
import { LineChart } from "../components/LineChart";
import { useHistory } from "../useHistory";

function fmtUTC(ts: bigint | null): { time: string; date: string } {
  if (!ts) return { time: "-", date: "-" };
  const d = new Date(Number(ts) * 1000);
  const time = d.toLocaleTimeString("en-GB", { timeZone: "UTC", hour: "2-digit", minute: "2-digit" });
  const date = d.toLocaleDateString("en-GB", { timeZone: "UTC", day: "2-digit", month: "short", year: "numeric" });
  return { time: `${time} UTC`, date };
}

function Stat({
  label,
  value,
  sub,
  big,
}: {
  label: string;
  value: string;
  sub?: string;
  big?: boolean;
}) {
  return (
    <div className="rounded-xl border border-edge bg-panel2 p-4">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className={`mt-1 font-semibold text-gray-100 ${big ? "text-3xl" : "text-xl"}`}>{value}</div>
      {sub && <div className="mt-0.5 text-xs text-gray-400">{sub}</div>}
    </div>
  );
}

export function Info() {
  const { tr } = useI18n();
  const d = useVaultData();
  const epochStart = useEpochStart(d.currentEpoch);
  const { points, loading } = useHistory();

  const start = fmtUTC(epochStart);

  const rates = points.map((p) => ({ label: `Epoch ${p.epoch}`, value: p.rate }));
  const supplies = points.map((p) => ({ label: `Epoch ${p.epoch}`, value: p.supply }));

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-sm font-semibold text-gray-300">{tr("overview")}</h1>
        {d.woundDown ? <Badge tone="bad">{tr("woundDown")}</Badge> : <Badge tone="good">Active</Badge>}
      </div>

      {/* Big overview: 4 key stats */}
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-xl border border-edge bg-panel2 p-4">
          <div className="text-xs uppercase tracking-wide text-gray-500">{tr("activeEpoch")}</div>
          <div className="mt-1 text-4xl font-bold text-gray-100">#{d.currentEpoch.toString()}</div>
          <div className="mt-0.5 text-xs text-gray-400">
            {start.time} · {start.date}
          </div>
        </div>
        <Stat label={tr("nav")} value={`${format6(d.totalNav)} USDC`} big />
        <Stat label={tr("totalSupply")} value={`${format6(d.totalSupply)} tWSK`} big />
        <Stat
          label={tr("wskPrice")}
          value={`${d.rate ? format6(d.rate, 6) : "-"} USDC`}
          sub={tr("perShare")}
          big
        />
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card
          title={tr("chartRate")}
          right={loading ? <span className="text-xs text-gray-500">{tr("loading")}</span> : undefined}
        >
          <LineChart data={rates} color="#6ea8fe" format={(n) => n.toFixed(6)} emptyLabel={tr("noHistory")} />
        </Card>
        <Card title={tr("chartSupply")}>
          <LineChart
            data={supplies}
            color="#34d399"
            format={(n) => n.toFixed(2)}
            emptyLabel={tr("noHistory")}
          />
        </Card>
      </div>
    </div>
  );
}
