import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from "wagmi";
import { useI18n } from "../i18n-react";
import { shortAddr } from "../lib";
import { arcTestnet } from "../config";
import { Button } from "./Ui";

export function TopBar() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const { lang, setLang, tr } = useI18n();

  const onArc = chainId === arcTestnet.id;

  return (
    <header className="sticky top-0 z-20 border-b border-edge bg-ink/90 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between gap-3 px-4 py-3">
        <div className="flex items-center gap-2">
          <div className="h-6 w-6 rounded-md bg-gradient-to-br from-accent to-good" />
          <div>
            <div className="text-sm font-semibold text-gray-100">{tr("appTitle")}</div>
            <div className="text-[11px] text-gray-500">{tr("appSubtitle")}</div>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex overflow-hidden rounded-lg border border-edge text-xs">
            <button
              className={`px-2 py-1 ${lang === "en" ? "bg-accent text-ink" : "text-gray-400"}`}
              onClick={() => setLang("en")}
            >
              EN
            </button>
            <button
              className={`px-2 py-1 ${lang === "vi" ? "bg-accent text-ink" : "text-gray-400"}`}
              onClick={() => setLang("vi")}
            >
              VI
            </button>
          </div>

          {isConnected && !onArc && (
            <Button variant="ghost" onClick={() => switchChain({ chainId: arcTestnet.id })}>
              {tr("switchNetwork")}
            </Button>
          )}

          {isConnected ? (
            <div className="flex items-center gap-2">
              <span className="rounded-lg border border-edge bg-panel2 px-2 py-1 text-xs text-gray-300">
                {shortAddr(address)}
              </span>
              <Button variant="ghost" onClick={() => disconnect()}>
                {tr("disconnect")}
              </Button>
            </div>
          ) : (
            <Button
              disabled={isPending}
              onClick={() => connect({ connector: connectors[0] })}
            >
              {tr("connect")}
            </Button>
          )}
        </div>
      </div>
    </header>
  );
}
