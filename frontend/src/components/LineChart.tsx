import { useState } from "react";

export type ChartPoint = { label: string; value: number };

export function LineChart({
  data,
  height = 120,
  color = "#6ea8fe",
  format,
  emptyLabel,
}: {
  data: ChartPoint[];
  height?: number;
  color?: string;
  format?: (n: number) => string;
  emptyLabel: string;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const width = 480;
  const pad = 8;

  const fmt = (n: number) => (format ? format(n) : n.toFixed(2));

  if (data.length === 0) {
    return (
      <div
        className="flex items-center justify-center rounded-lg border border-edge bg-panel2 text-xs text-gray-500"
        style={{ height }}
      >
        {emptyLabel}
      </div>
    );
  }

  if (data.length === 1) {
    return (
      <div
        className="flex items-center justify-center rounded-lg border border-edge bg-panel2 text-xs text-gray-300"
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
  const stepX = (width - pad * 2) / (data.length - 1);

  const pts = values.map((v, i) => {
    const x = pad + i * stepX;
    const y = height - pad - ((v - min) / span) * (height - pad * 2);
    return [x, y] as const;
  });
  const path = pts
    .map((p, i) => `${i === 0 ? "M" : "L"}${p[0].toFixed(1)},${p[1].toFixed(1)}`)
    .join(" ");
  const area = `${path} L${pts[pts.length - 1][0].toFixed(1)},${height - pad} L${pts[0][0].toFixed(1)},${height - pad} Z`;

  const active = hover ?? data.length - 1;
  const activeP = pts[active];

  return (
    <div className="relative rounded-lg border border-edge bg-panel2 p-2">
      <svg
        viewBox={`0 0 ${width} ${height}`}
        className="w-full"
        style={{ height }}
        preserveAspectRatio="none"
        onMouseLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id={`g-${color.replace("#", "")}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.35" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={area} fill={`url(#g-${color.replace("#", "")})`} />
        <path d={path} fill="none" stroke={color} strokeWidth="1.5" />

        {/* hover guides */}
        <line
          x1={activeP[0]}
          y1={pad}
          x2={activeP[0]}
          y2={height - pad}
          stroke={color}
          strokeOpacity="0.35"
          strokeDasharray="3 3"
        />

        {pts.map((p, i) => (
          <circle
            key={i}
            cx={p[0]}
            cy={p[1]}
            r={i === active ? 3.2 : 2}
            fill={i === active ? color : "#0f1522"}
            stroke={color}
            strokeWidth="1.2"
          />
        ))}
      </svg>

      {/* tooltip */}
      <div
        className="pointer-events-none absolute -translate-x-1/2 rounded-md border border-edge bg-ink/95 px-2 py-1 text-[10px] text-gray-200 shadow-lg"
        style={{
          left: `${(activeP[0] / width) * 100}%`,
          top: 0,
        }}
      >
        <span className="text-gray-400">{data[active].label}</span>{" "}
        <span className="font-semibold text-gray-100">{fmt(data[active].value)}</span>
      </div>

      {/* hit areas for hover (on top) */}
      <div className="absolute inset-0 flex" onMouseLeave={() => setHover(null)}>
        {data.map((_, i) => (
          <div key={i} className="h-full flex-1" onMouseEnter={() => setHover(i)} />
        ))}
      </div>

      <div className="mt-1 flex justify-between px-1 text-[10px] text-gray-500">
        <span>{fmt(min)}</span>
        <span>{fmt(max)}</span>
      </div>
    </div>
  );
}
