import React, { createContext, useCallback, useContext, useState } from "react";

export type PopupTone = "info" | "success" | "error";

export type Popup = {
  id: number;
  tone: PopupTone;
  title: string;
  description?: string;
};

type Ctx = {
  notify: (tone: PopupTone, title: string, description?: string) => void;
};

const PopupContext = createContext<Ctx>({ notify: () => {} });

function Icon({ tone }: { tone: PopupTone }) {
  const cfg: Record<PopupTone, { color: string; path: React.ReactNode }> = {
    info: {
      color: "#6ea8fe",
      path: (
        <>
          <circle cx="12" cy="12" r="9" />
          <line x1="12" y1="11" x2="12" y2="16" />
          <circle cx="12" cy="8" r="0.6" fill="#6ea8fe" />
        </>
      ),
    },
    success: {
      color: "#34d399",
      path: (
        <>
          <circle cx="12" cy="12" r="9" />
          <path d="M8 12.5l2.5 2.5L16 9.5" />
        </>
      ),
    },
    error: {
      color: "#f87171",
      path: (
        <>
          <circle cx="12" cy="12" r="9" />
          <line x1="12" y1="8" x2="12" y2="13" />
          <circle cx="12" cy="16" r="0.6" fill="#f87171" />
        </>
      ),
    },
  };
  const c = cfg[tone];
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={c.color} strokeWidth="1.8">
      {c.path}
    </svg>
  );
}

export function PopupProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<Popup[]>([]);

  const notify = useCallback((tone: PopupTone, title: string, description?: string) => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    setItems((prev) => [...prev, { id, tone, title, description }]);
    setTimeout(() => {
      setItems((prev) => prev.filter((t) => t.id !== id));
    }, 5000);
  }, []);

  const toneBorder: Record<PopupTone, string> = {
    info: "border-accent/40",
    success: "border-good/40",
    error: "border-bad/40",
  };

  return (
    <PopupContext.Provider value={{ notify }}>
      {children}
      {/* Desktop: top-right. Mobile: top-left. */}
      <div className="pointer-events-none fixed inset-x-0 top-0 z-50 flex flex-col items-start gap-2 p-3 sm:items-end sm:p-4">
        {items.map((t) => (
          <div
            key={t.id}
            className={`pop-in pointer-events-auto w-[300px] max-w-[85vw] rounded-xl border bg-panel/95 p-3 shadow-xl backdrop-blur ${toneBorder[t.tone]}`}
            role="alert"
          >
            <div className="flex items-start gap-3">
              <div className="mt-0.5 shrink-0">
                <Icon tone={t.tone} />
              </div>
              <div className="min-w-0">
                <div className="text-sm font-semibold text-gray-100">{t.title}</div>
                {t.description && (
                  <div className="mt-0.5 break-words text-xs text-gray-400">{t.description}</div>
                )}
              </div>
              <button
                className="ml-auto shrink-0 text-gray-500 hover:text-gray-300"
                onClick={() => setItems((prev) => prev.filter((x) => x.id !== t.id))}
                aria-label="close"
              >
                ×
              </button>
            </div>
          </div>
        ))}
      </div>
    </PopupContext.Provider>
  );
}

export function usePopup() {
  return useContext(PopupContext);
}
