import { useI18n } from "../i18n-react";
import { format6 } from "../lib";
import { Card, Row, Badge } from "./Ui";
import { useVaultData } from "../useVault";

export function Overview() {
  const { tr } = useI18n();
  const d = useVaultData();

  return (
    <Card
      title={tr("overview")}
      right={d.woundDown ? <Badge tone="bad">{tr("woundDown")}</Badge> : <Badge tone="good">Active</Badge>}
    >
      <div className="grid grid-cols-2 gap-x-6">
        <Row k={tr("nav")} v={`${format6(d.totalNav)} USDC`} />
        <Row k={tr("rate")} v={d.rate ? `${format6(d.rate, 6)}` : "-"} />
        <Row k={tr("totalSupply")} v={`${format6(d.totalSupply)} tWSK`} />
        <Row k={`Liquid USDC`} v={`${format6(d.liquidUsdc)}`} />
        <Row k={tr("usdcBalance")} v={`${format6(d.usdcBalance)}`} />
        <Row k={tr("wskBalance")} v={`${format6(d.wskBalance)}`} />
      </div>
    </Card>
  );
}
