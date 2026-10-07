import { NavLink } from "react-router-dom";
import { useI18n } from "../i18n-react";
import { CONTRACTS, SHARE } from "../config";

const OP_CHAIN_PARAMS = {
  chainId: "0xa", // 10
  chainName: "OP Mainnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: ["https://mainnet.optimism.io"],
  blockExplorerUrls: ["https://optimistic.etherscan.io"],
};

export function Footer() {
  const { tr } = useI18n();

  const navItems = [
    { to: "/info", label: tr("navInfo") },
    { to: "/mint", label: tr("navMint") },
    { to: "/burn", label: tr("navBurn") },
    { to: "/docs", label: tr("navDocs") },
  ];

  async function addOptimism() {
    const eth = (window as unknown as { ethereum?: { request: (a: unknown) => Promise<unknown> } }).ethereum;
    if (!eth) return;
    try {
      await eth.request({
        method: "wallet_addEthereumChain",
        params: [OP_CHAIN_PARAMS],
      });
    } catch {
      /* ignore */
    }
  }

  async function addToken() {
    const eth = (window as unknown as { ethereum?: { request: (a: unknown) => Promise<unknown> } }).ethereum;
    if (!eth) return;
    try {
      await eth.request({
        method: "wallet_watchAsset",
        params: {
          type: "ERC20",
          options: {
            address: CONTRACTS.wsk,
            symbol: SHARE.symbol,
            decimals: SHARE.decimals,
          },
        },
      });
    } catch {
      /* ignore */
    }
  }

  return (
    <footer className="mt-8 border-t border-edge bg-card">
      <div className="mx-auto grid max-w-content grid-cols-1 gap-6 px-5 py-8 sm:grid-cols-3">
        {/* Left: logo + nav */}
        <div>
          <div className="flex items-center gap-2">
            <img src="/logo_hortizontial.png" alt="Wellstake" className="h-7 w-auto" />
          </div>
          <nav className="mt-3 flex flex-col gap-1.5">
            {navItems.map((n) => (
              <NavLink
                key={n.to}
                to={n.to}
                className="text-[13px] text-muted transition hover:text-ink"
              >
                {n.label}
              </NavLink>
            ))}
          </nav>
        </div>

        {/* Center: empty */}
        <div className="hidden sm:block" />

        {/* Right: add network + token */}
        <div className="flex flex-col items-start gap-2.5 sm:items-end">
          {/* OPScan-style "Add OP Mainnet" button: black pill, Optimism mark + label */}
          <button
            onClick={addOptimism}
            className="flex items-center gap-2 rounded-full bg-black px-3.5 py-1.5 text-[12px] font-semibold text-white transition hover:opacity-90"
          >
            <svg width="16" height="16" viewBox="0 0 32 32" aria-hidden="true">
              <circle cx="16" cy="16" r="16" fill="#FF0420" />
              <text
                x="16"
                y="21"
                textAnchor="middle"
                fontFamily="Manrope, sans-serif"
                fontSize="12"
                fontWeight="800"
                fill="#fff"
              >
                OP
              </text>
            </svg>
            {tr("addOptimism")}
          </button>

          {/* "Add wskBV": square logo + label */}
          <button
            onClick={addToken}
            className="flex items-center gap-2 rounded-full border border-edge bg-inset px-3 py-1.5 text-[12px] font-semibold text-ink transition hover:bg-[#ECEEF2]"
          >
            <img src="/logo.png" alt="" className="h-4 w-4 rounded-sm" />
            {tr("addToken")} {SHARE.symbol}
          </button>
        </div>
      </div>
      <div className="border-t border-edge/70 py-3 text-center text-[11px] text-subtle">
        © {new Date().getFullYear()} Wellstake · {SHARE.name} ({SHARE.symbol})
      </div>
    </footer>
  );
}
