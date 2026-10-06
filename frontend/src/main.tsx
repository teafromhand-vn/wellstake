import React from "react";
import ReactDOM from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { BrowserRouter } from "react-router-dom";
import { wagmiConfig } from "./wagmi";
import { I18nProvider } from "./i18n-react";
import { PopupProvider } from "./components/Popup";
import App from "./App";
import "./index.css";

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <I18nProvider>
          <PopupProvider>
            <BrowserRouter>
              <App />
            </BrowserRouter>
          </PopupProvider>
        </I18nProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
);
