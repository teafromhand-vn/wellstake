import React, { createContext, useCallback, useContext, useState } from "react";

type ToastTone = "info" | "good" | "bad";
type Toast = { id: number; message: string; tone: ToastTone };

type Ctx = {
  push: (message: string, tone?: ToastTone) => void;
};

const ToastContext = createContext<Ctx>({ push: () => {} });

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const push = useCallback((message: string, tone: ToastTone = "info") => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    setToasts((prev) => [...prev, { id, message, tone }]);
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 6000);
  }, []);

  return (
    <ToastContext.Provider value={{ push }}>
      {children}
      {/* Desktop: top-right. Mobile: top-left (left-0) via responsive classes. */}
      <div className="pointer-events-none fixed inset-x-0 top-0 z-50 flex flex-col items-start gap-2 p-3 sm:items-end sm:p-4">
        {toasts.map((t) => {
          const tones: Record<ToastTone, string> = {
            info: "border-accent/40 bg-accent/10 text-accent",
            good: "border-good/40 bg-good/10 text-good",
            bad: "border-bad/40 bg-bad/10 text-bad",
          };
          return (
            <div
              key={t.id}
              className={`pointer-events-auto max-w-xs rounded-lg border px-3 py-2 text-xs shadow-lg backdrop-blur ${tones[t.tone]}`}
            >
              {t.message}
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  return useContext(ToastContext);
}
