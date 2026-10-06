type IconProps = { size?: number; className?: string };

const base = (size: number) => ({
  width: size,
  height: size,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.7,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
});

export function InfoIcon({ size = 16, className }: IconProps) {
  return (
    <svg {...base(size)} className={className}>
      <circle cx="12" cy="12" r="9" />
      <line x1="12" y1="11" x2="12" y2="16" />
      <circle cx="12" cy="8" r="0.5" fill="currentColor" />
    </svg>
  );
}

export function PickaxeIcon({ size = 16, className }: IconProps) {
  return (
    <svg {...base(size)} className={className}>
      <path d="M14 6c2.5-1 5 .2 6 2-2 .3-3.3 1-4.3 2.2" />
      <path d="M8 10c-1 1-1.8 2.4-2.4 4.4C7.6 13.2 9 12.4 10 11.4" />
      <path d="M10.5 13.5l-4.8 4.8a1.5 1.5 0 0 0 2.1 2.1l4.8-4.8z" />
      <path d="M16 8l3-3" />
    </svg>
  );
}

export function FlameIcon({ size = 16, className }: IconProps) {
  return (
    <svg {...base(size)} className={className}>
      <path d="M12 3c1 3 4 4.5 4 8a4 4 0 1 1-8 0c0-1.2.4-2 1-2.8C9.6 9.7 10 11 11 11c-.5-2.5 1-5 1-8z" />
    </svg>
  );
}

export function DocIcon({ size = 16, className }: IconProps) {
  return (
    <svg {...base(size)} className={className}>
      <path d="M13 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9z" />
      <path d="M13 3v6h6" />
      <line x1="9" y1="13" x2="15" y2="13" />
      <line x1="9" y1="16" x2="13" y2="16" />
    </svg>
  );
}

export function StatusDot({ className }: { className?: string }) {
  return <span className={`inline-block h-1.5 w-1.5 rounded-full bg-mint ${className ?? ""}`} />;
}
