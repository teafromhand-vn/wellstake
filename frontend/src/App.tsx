import { Routes, Route, Navigate } from "react-router-dom";
import { TopBar } from "./components/TopBar";
import { Footer } from "./components/Footer";
import { Info } from "./pages/Info";
import { Mint } from "./pages/Mint";
import { Burn } from "./pages/Burn";
import { AdminPage } from "./pages/AdminPage";

export default function App() {
  return (
    <div className="flex min-h-screen flex-col">
      <TopBar />
      <main className="mx-auto w-full max-w-content flex-1 px-5 py-6">
        <Routes>
          <Route path="/" element={<Navigate to="/info" replace />} />
          <Route path="/info" element={<Info />} />
          <Route path="/mint" element={<Mint />} />
          <Route path="/burn" element={<Burn />} />
          <Route path="/redeem" element={<Navigate to="/burn" replace />} />
          <Route path="/docs" element={<Navigate to="/info" replace />} />
          <Route path="/admin" element={<AdminPage />} />
          <Route path="*" element={<Navigate to="/info" replace />} />
        </Routes>
      </main>
      <Footer />
    </div>
  );
}
