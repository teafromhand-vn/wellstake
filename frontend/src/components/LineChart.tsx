export function LineChart({
  data,
  height = 120,
  color = "#6ea8fe",
  format,
  emptyLabel,
}: {
  data: number[];
  height?: number;
  color?: string;
  format?: (n: number) => string;
  emptyLabel: string;
}) {
  const width = 480;
  const pad = 6;

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
        {format ? format(data[0]) : data[0]}
      </div>
    );
  }

  const min = Math.min(...data);
  const max = Math.max(...data);
  const span = max - min || 1;
  const stepX = (width - pad * 2) / (data.length - 1);

  const pts = data.map((v, i) => {
    const x = pad + i * stepX;
    const y = height - pad - ((v - min) / span) * (height - pad * 2);
    return [x, y] as const;
  });
  const path = pts.map((p, i) => `${i === 0 ? "M" : "L"}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(" ");
  const area = `${path} L${pts[pts.length - 1][0].toFixed(1)},${height - pad} L${pts[0][0].toFixed(1)},${height - pad} Z`;

  const last = data[data.length - 1];
  const lastP = pts[pts.length - 1];

  return (
    <div className="rounded-lg border border-edge bg-panel2 p-2">
      <svg viewBox={`0 0 ${width} ${height}`} className="w-full" style={{ height }} preserveAspectRatio="none">
        <defs>
          <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.35" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path d={area} fill="url(#g)" />
        <path d={path} fill="none" stroke={color} strokeWidth="1.5" />
        <circle cx={lastP[0]} cy={lastP[1]} r="2.5" fill={color} />
      </svg>
      <div className="mt-1 flex justify-between px-1 text-[10px] text-gray-500">
        <span>{format ? format(min) : min.toFixed(2)}</span>
        <span className="text-gray-300">{format ? format(last) : last.toFixed(2)}</span>
        <span>{format ? format(max) : max.toFixed(2)}</span>
      </div>
    </div>
  );
}
