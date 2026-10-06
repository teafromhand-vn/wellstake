import { NavLink } from "react-router-dom";
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

  const navItems = [
    { to: "/info", label: tr("navInfo") },
    { to: "/mint", label: tr("navMint") },
    { to: "/redeem", label: tr("navRedeem") },
    { to: "/docs", label: tr("navDocs") },
  ];

  return (
    <header className="sticky top-0 z-20 border-b border-edge bg-ink/90 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center gap-3 px-4 py-3">
        {/* Left: brand */}
        <NavLink to="/info" className="flex shrink-0 items-center gap-2">
          <div className="h-6 w-6 rounded-md bg-gradient-to-br from-accent to-good" />
          <span className="hidden text-sm font-semibold text-gray-100 sm:inline">
            Wellstake <span className="text-gray-500">beta</span>
          </span>
        </NavLink>

        {/* Center: nav */}
        <nav className="mx-auto flex items-center gap-1 rounded-lg border border-edge bg-panel2 p-0.5">
          {navItems.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              className={({ isActive }) =>
                `rounded-md px-2.5 py-1.5 text-xs font-medium transition ${
                  isActive ? "bg-accent text-ink" : "text-gray-300 hover:text-white"
                }`
              }
            >
              {n.label}
            </NavLink>
          ))}
        </nav>

        {/* Right: wallet + lang */}
        <div className="flex shrink-0 items-center gap-2">
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
              <span className="hidden rounded-lg border border-edge bg-panel2 px-2 py-1 text-xs text-gray-300 sm:inline">
                {shortAddr(address)}
              </span>
              <Button variant="ghost" onClick={() => disconnect()}>
                {tr("disconnect")}
              </Button>
            </div>
          ) : (
            <Button disabled={isPending} onClick={() => connect({ connector: connectors[0] })}>
              {tr("connect")}
            </Button>
          )}
        </div>
      </div>
    </header>
  );
}
