import { useI18n } from "../i18n-react";
import { useHistory } from "../useHistory";
import { Card } from "./Ui";
import { LineChart } from "./LineChart";

export function History() {
  const { tr } = useI18n();
  const { points, loading } = useHistory();

  const rates = points.map((p) => p.rate);
  const tvls = points.map((p) => p.totalNav);

  return (
    <Card title={tr("chartRate") + " / " + tr("chartTvl")} right={loading ? <span className="text-xs text-gray-500">{tr("loading")}</span> : undefined}>
      <div className="space-y-3">
        <div>
          <div className="mb-1 text-xs text-gray-400">{tr("chartRate")}</div>
          <LineChart data={rates} color="#6ea8fe" format={(n) => n.toFixed(4)} emptyLabel={tr("noHistory")} />
        </div>
        <div>
          <div className="mb-1 text-xs text-gray-400">{tr("chartTvl")}</div>
          <LineChart data={tvls} color="#34d399" format={(n) => n.toFixed(2)} emptyLabel={tr("noHistory")} />
        </div>
      </div>
    </Card>
  );
}
