import { useI18n } from "../i18n-react";
import { useVaultData } from "../useVault";
import { useEpochStart } from "../useEpochStart";
import { format6 } from "../lib";
import { Card, Row, Badge } from "../components/Ui";
import { LineChart } from "../components/LineChart";
import { useHistory } from "../useHistory";

function fmtUTC(ts: bigint | null): string {
  if (!ts) return "-";
  const d = new Date(Number(ts) * 1000);
  return d.toUTCString();
}

export function Info() {
  const { tr } = useI18n();
  const d = useVaultData();
  const epochStart = useEpochStart(d.currentEpoch);
  const { points, loading } = useHistory();

  const rates = points.map((p) => ({ label: `Epoch ${p.epoch}`, value: p.rate }));
  const tvls = points.map((p) => ({ label: `Epoch ${p.epoch}`, value: p.totalNav }));

  return (
    <div className="space-y-4">
      <Card
        title={tr("overview")}
        right={d.woundDown ? <Badge tone="bad">{tr("woundDown")}</Badge> : <Badge tone="good">Active</Badge>}
      >
        <div className="grid gap-x-8 gap-y-1 sm:grid-cols-2">
          <Row k={tr("activeEpoch")} v={d.currentEpoch.toString()} />
          <Row k={tr("epochStart")} v={fmtUTC(epochStart)} />
          <Row k={tr("nav")} v={`${format6(d.totalNav)} USDC`} />
          <Row k={tr("totalSupply")} v={`${format6(d.totalSupply)} tWSK`} />
          <Row k={tr("convertRate")} v={`${d.rate ? format6(d.rate, 6) : "-"} ${tr("perShare")}`} />
          <Row k={`Liquid USDC`} v={format6(d.liquidUsdc)} />
        </div>
      </Card>

      <div className="grid gap-4 sm:grid-cols-2">
        <Card title={tr("chartRate")} right={loading ? <span className="text-xs text-gray-500">{tr("loading")}</span> : undefined}>
          <LineChart data={rates} color="#6ea8fe" format={(n) => n.toFixed(4)} emptyLabel={tr("noHistory")} />
        </Card>
        <Card title={tr("chartTvl")}>
          <LineChart data={tvls} color="#34d399" format={(n) => n.toFixed(2)} emptyLabel={tr("noHistory")} />
        </Card>
      </div>
    </div>
  );
}
