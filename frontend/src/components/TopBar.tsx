import { NavLink } from "react-router-dom";
import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from "wagmi";
import { useI18n } from "../i18n-react";
import { shortAddr } from "../lib";
import { opMainnet } from "../config";
import { InfoIcon, PickaxeIcon, FlameIcon, DocIcon } from "./icons";

export function TopBar() {
  const { address, isConnected } = useAccount();
  const { connectors, connect, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain, isPending: switching } = useSwitchChain();
  const { tr } = useI18n();

  const onOptimism = chainId === opMainnet.id;

  const navItems = [
    { to: "/info", label: tr("navInfo"), icon: <InfoIcon /> },
    { to: "/mint", label: tr("navMint"), icon: <PickaxeIcon /> },
    { to: "/burn", label: tr("navBurn"), icon: <FlameIcon /> },
    { to: "/docs", label: tr("navDocs"), icon: <DocIcon /> },
  ];

  return (
    <header className="border-b border-edge bg-card">
      <div className="mx-auto flex h-16 max-w-content items-center justify-between px-5">
        {/* Left: logo */}
        <NavLink to="/info" className="flex items-center">
          <img src="/logo_hortizontial.png" alt="Wellstake" className="h-8 w-auto" />
        </NavLink>

        {/* Center: nav */}
        <nav className="flex items-center gap-1">
          {navItems.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              className={({ isActive }) =>
                `flex items-center gap-1.5 rounded-lg px-3 py-2 text-[13px] font-medium transition ${
                  isActive ? "text-accent" : "text-muted hover:text-ink"
                }`
              }
            >
              {n.icon}
              <span className="hidden sm:inline">{n.label}</span>
            </NavLink>
          ))}
        </nav>

        {/* Right: switch network (if wrong) + connect/account */}
        <div className="flex items-center gap-2">
          {isConnected && !onOptimism && (
            <button
              disabled={switching}
              onClick={() => switchChain({ chainId: opMainnet.id })}
              className="h-10 rounded-xl bg-accent px-3 text-[13px] font-semibold text-white transition hover:brightness-105 disabled:opacity-50"
            >
              {tr("switchNetwork")}
            </button>
          )}

          {isConnected ? (
            <button
              onClick={() => disconnect()}
              className="h-10 rounded-xl border border-edge bg-inset px-4 text-[13px] font-semibold text-ink transition hover:bg-[#ECEEF2]"
            >
              {shortAddr(address)}
            </button>
          ) : (
            <button
              disabled={isPending}
              onClick={() => connect({ connector: connectors[0] })}
              className="h-10 w-[160px] rounded-xl border border-edge bg-inset text-[13px] font-semibold text-ink transition hover:bg-[#ECEEF2] disabled:opacity-50"
            >
              {tr("connect")}
            </button>
          )}
        </div>
      </div>
    </header>
  );
}

