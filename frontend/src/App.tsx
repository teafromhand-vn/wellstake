import { Routes, Route, Navigate } from "react-router-dom";
import { TopBar } from "./components/TopBar";
import { Info } from "./pages/Info";
import { Mint } from "./pages/Mint";
import { Redeem } from "./pages/Redeem";
import { AdminPage } from "./pages/AdminPage";
import { useI18n } from "./i18n-react";
import { CONTRACTS, EXPLORER, SHARE } from "./config";

export default function App() {
  const { tr } = useI18n();

  return (
    <div className="min-h-screen">
      <TopBar />
      <main className="mx-auto max-w-5xl px-4 py-6">
        <div className="mb-4 flex items-center justify-between rounded-lg border border-yellow-500/30 bg-yellow-500/10 px-3 py-2 text-xs text-yellow-200">
          <span>{tr("beta")}</span>
          <a
            className="text-accent underline"
            href={`${EXPLORER}/address/${CONTRACTS.liquidWallet}`}
            target="_blank"
            rel="noreferrer"
          >
            {SHARE.symbol} · {CONTRACTS.liquidWallet.slice(0, 8)}...
          </a>
        </div>

        <Routes>
          <Route path="/" element={<Navigate to="/info" replace />} />
          <Route path="/info" element={<Info />} />
          <Route path="/mint" element={<Mint />} />
          <Route path="/redeem" element={<Redeem />} />
          <Route path="/docs" element={<Navigate to="/info" replace />} />
          <Route path="/admin" element={<AdminPage />} />
          <Route path="*" element={<Navigate to="/info" replace />} />
        </Routes>

        <footer className="mt-8 border-t border-edge pt-4 text-center text-xs text-gray-600">
          Wellstake V1 beta · Arc Testnet ({5042002}) ·{" "}
          <a
            className="underline"
            href={`${EXPLORER}/address/${CONTRACTS.wsk}`}
            target="_blank"
            rel="noreferrer"
          >
            {SHARE.name} ({SHARE.symbol})
          </a>
        </footer>
      </main>
    </div>
  );
}
