import React from "react";

export function Card({
  title,
  right,
  children,
}: {
  title?: string;
  right?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="rounded-xl border border-edge bg-panel p-4">
      {(title || right) && (
        <div className="mb-3 flex items-center justify-between">
          {title && <h3 className="text-sm font-semibold text-gray-900">{title}</h3>}
          {right}
        </div>
      )}
      {children}
    </div>
  );
}

export function Button({
  children,
  onClick,
  disabled,
  variant = "primary",
  className = "",
  type = "button",
}: {
  children: React.ReactNode;
  onClick?: () => void;
  disabled?: boolean;
  variant?: "primary" | "ghost" | "danger";
  className?: string;
  type?: "button" | "submit";
}) {
  const styles: Record<string, string> = {
    primary: "bg-accent text-ink hover:brightness-110",
    ghost: "bg-panel2 text-gray-900 border border-edge hover:border-accent",
    danger: "bg-bad/90 text-white hover:brightness-110",
  };
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`rounded-lg px-3 py-2 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-40 ${styles[variant]} ${className}`}
    >
      {children}
    </button>
  );
}

export function Field({
  label,
  value,
  onChange,
  placeholder,
  suffix,
  onMax,
  maxLabel,
  disabled,
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  suffix?: React.ReactNode;
  onMax?: () => void;
  maxLabel?: string;
  disabled?: boolean;
}) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs text-gray-500">{label}</span>
      <div
        className={`flex items-center gap-2 rounded-lg border px-3 py-2 ${
          disabled ? "border-edge bg-gray-100" : "border-edge bg-panel2"
        }`}
      >
        <input
          className={`w-full bg-transparent text-sm outline-none ${
            disabled ? "text-gray-500" : "text-gray-900"
          }`}
          value={value}
          placeholder={placeholder}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value)}
          inputMode="decimal"
        />
        {onMax && !disabled && (
          <button
            type="button"
            onClick={onMax}
            className="rounded border border-edge px-1.5 py-0.5 text-[10px] text-gray-500 hover:border-accent"
          >
            {maxLabel ?? "MAX"}
          </button>
        )}
        {suffix && <span className="text-xs text-gray-500">{suffix}</span>}
      </div>
    </label>
  );
}

export function Row({ k, v }: { k: string; v: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between border-b border-edge/60 py-1.5 text-sm last:border-0">
      <span className="text-gray-500">{k}</span>
      <span className="font-medium text-gray-900">{v}</span>
    </div>
  );
}

export function Badge({ children, tone = "muted" }: { children: React.ReactNode; tone?: string }) {
  const tones: Record<string, string> = {
    muted: "bg-panel2 text-gray-700 border-edge",
    good: "bg-good/10 text-good border-good/30",
    warn: "bg-yellow-500/10 text-yellow-800 border-yellow-500/40",
    bad: "bg-bad/10 text-bad border-bad/30",
  };
  return (
    <span className={`rounded-full border px-2 py-0.5 text-[11px] ${tones[tone] ?? tones.muted}`}>
      {children}
    </span>
  );
}
