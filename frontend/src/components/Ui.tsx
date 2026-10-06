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
    <div className="rounded-xl border border-edge bg-card p-4">
      {(title || right) && (
        <div className="mb-3 flex items-center justify-between">
          {title && <h3 className="text-[13px] font-semibold text-ink">{title}</h3>}
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
    primary: "bg-accent text-white hover:brightness-105",
    ghost: "bg-inset text-ink border border-edge hover:bg-[#ECEEF2]",
    danger: "bg-bad text-white hover:brightness-105",
  };
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={`rounded-lg px-3 py-2 text-[13px] font-semibold transition disabled:cursor-not-allowed disabled:opacity-40 ${styles[variant]} ${className}`}
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
      <span className="mb-1 block text-xs text-muted">{label}</span>
      <div
        className={`flex items-center gap-2 rounded-lg border px-3 py-2 ${
          disabled ? "border-edge bg-inset" : "border-edge bg-card"
        }`}
      >
        <input
          className={`w-full bg-transparent text-sm outline-none ${disabled ? "text-subtle" : "text-ink"}`}
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
            className="rounded border border-edge px-1.5 py-0.5 text-[10px] text-muted hover:border-accent"
          >
            {maxLabel ?? "MAX"}
          </button>
        )}
        {suffix && <span className="text-xs text-muted">{suffix}</span>}
      </div>
    </label>
  );
}

export function Row({ k, v }: { k: string; v: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between border-b border-edge/70 py-1.5 text-sm last:border-0">
      <span className="text-muted">{k}</span>
      <span className="font-medium text-ink">{v}</span>
    </div>
  );
}

export function Badge({ children, tone = "muted" }: { children: React.ReactNode; tone?: string }) {
  const tones: Record<string, string> = {
    muted: "bg-inset text-muted border-edge",
    good: "bg-goodbg text-good border-[#CDEEDD]",
    warn: "bg-warnbg text-warntext border-warnborder",
    bad: "bg-bad/10 text-bad border-bad/20",
  };
  return (
    <span className={`rounded-full border px-2.5 py-0.5 text-[11px] font-medium ${tones[tone] ?? tones.muted}`}>
      {children}
    </span>
  );
}
