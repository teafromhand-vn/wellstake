import { useI18n } from "../i18n-react";
import { useHoldings } from "../useHoldings";
import { format6, shortAddr } from "../lib";
import { SHARE, EXPLORER } from "../config";

function Cell({ value, symbol }: { value?: bigint; symbol: string }) {
  return (
    <span className="tabular-nums text-ink">
      {value !== undefined ? `${format6(value, 6)} ` : "- "}
      <span className="text-subtle">{symbol}</span>
    </span>
  );
}

export function Holdings() {
  const { tr } = useI18n();
  const h = useHoldings();

  const rows = [
    { key: "manager", label: tr("managerLabel"), addr: h.manager, usdc: h.usdc.manager, wsk: h.wsk.manager },
    { key: "liquid", label: tr("liquidWalletLabel"), addr: h.liquidAddr, usdc: h.usdc.liquid, wsk: h.wsk.liquid },
    { key: "vault", label: tr("vaultLabel"), addr: h.vaultAddr, usdc: h.usdc.vault, wsk: h.wsk.vault },
  ];

  return (
    <div className="rounded-xl border border-edge bg-card p-4">
      <h3 className="text-[13px] font-semibold text-ink">{tr("holdings")}</h3>
      <div className="mt-3 overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-edge text-left text-[11px] font-medium text-subtle">
              <th className="py-2 pr-2 font-medium">Wallet</th>
              <th className="py-2 pr-2 text-right font-medium">{tr("usdcLabel")}</th>
              <th className="py-2 pr-2 text-right font-medium">{tr("wskLabel")}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.key} className="border-b border-edge/60 last:border-0">
                <td className="py-2.5 pr-2">
                  <div className="text-[13px] font-medium text-ink">{r.label}</div>
                  <a
                    href={`${EXPLORER}/address/${r.addr}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-[11px] text-subtle underline hover:text-link"
                  >
                    {shortAddr(r.addr)}
                  </a>
                </td>
                <td className="py-2.5 pr-2 text-right text-[13px]">
                  <Cell value={r.usdc} symbol="USDC" />
                </td>
                <td className="py-2.5 pr-2 text-right text-[13px]">
                  <Cell value={r.wsk} symbol={SHARE.symbol} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
