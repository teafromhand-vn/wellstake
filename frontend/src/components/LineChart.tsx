import { useState } from "react";

export type ChartPoint = { label: string; value: number };

export function LineChart({
  data,
  height = 150,
  stroke = "#6C7CF5",
  area = "rgba(108,124,245,0.14)",
  format,
}: {
  data: ChartPoint[];
  height?: number;
  stroke?: string;
  area?: string;
  format?: (n: number) => string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const width = 520;
  const padX = 6;
  const padTop = 14;
  const padBottom = 18;

  const fmt = (n: number) => (format ? format(n) : n.toFixed(2));

  if (data.length === 0) {
    return (
      <div
        className="flex items-center justify-center rounded-lg border border-edge bg-inset text-xs text-subtle"
        style={{ height }}
      >
        —
      </div>
    );
  }

  if (data.length === 1) {
    return (
      <div
        className="flex items-center justify-center rounded-lg border border-edge bg-inset text-xs text-muted"
        style={{ height }}
      >
        {data[0].label}: {fmt(data[0].value)}
      </div>
    );
  }

  const values = data.map((d) => d.value);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const span = max - min || 1;
  const stepX = data.length > 1 ? (width - padX * 2) / (data.length - 1) : 0;

  const pts = values.map((v, i) => {
    const x = data.length > 1 ? padX + i * stepX : width / 2;
    const y = padTop + (1 - (v - min) / span) * (height - padTop - padBottom);
    return [x, y] as const;
  });

  const path = pts
    .map((p, i) => `${i === 0 ? "M" : "L"}${p[0].toFixed(1)},${p[1].toFixed(1)}`)
    .join(" ");
  const areaPath = `${path} L${pts[pts.length - 1][0].toFixed(1)},${height - padBottom} L${pts[0][0].toFixed(1)},${height - padBottom} Z`;

  const active = hover ?? data.length - 1;
  const activeP = pts[active];

  return (
    <div className="relative">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full"
        style={{ height }}
        preserveAspectRatio="none"
        onMouseLeave={() => setHover(null)}
      >
        <path d={areaPath} fill={area} />
        <path d={path} fill="none" stroke={stroke} strokeWidth="2" strokeLinejoin="round" />

        {activeP && (
          <line
            x1={activeP[0]}
            y1={padTop}
            x2={activeP[0]}
            y2={height - padBottom}
            stroke={stroke}
            strokeOpacity="0.25"
            strokeDasharray="3 3"
          />
        )}

        {pts.map((p, i) => (
          <circle
            key={i}
            cx={p[0]}
            cy={p[1]}
            r={i === active ? 3.5 : 2.5}
            fill="#fff"
            stroke={stroke}
            strokeWidth="2"
          />
        ))}
      </svg>

      {/* hover hit areas */}
      <div className="absolute inset-0 flex" style={{ height }} onMouseLeave={() => setHover(null)}>
        {data.map((_, i) => (
          <div key={i} className="h-full flex-1" onMouseEnter={() => setHover(i)} />
        ))}
      </div>

      {/* tooltip */}
      {activeP && (
        <div
          className="pointer-events-none absolute -translate-x-1/2 rounded-lg border border-edge bg-card px-2.5 py-1.5 text-[11px] shadow-sm"
          style={{ left: `${(activeP[0] / width) * 100}%`, top: -4 }}
        >
          <div className="font-semibold text-ink">{data[active].label}</div>
          <div className="text-muted">{fmt(data[active].value)}</div>
        </div>
      )}

      {/* minimal axis labels */}
      <div className="mt-1 flex justify-between px-0.5 text-[10px] text-subtle">
        <span>{fmt(min)}</span>
        <span>{fmt(max)}</span>
      </div>
    </div>
  );
}
