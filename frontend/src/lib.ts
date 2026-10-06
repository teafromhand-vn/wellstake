import { formatUnits, parseUnits } from "viem";

export function format6(value: bigint | undefined, maxFrac = 4): string {
  if (value === undefined) return "-";
  const s = formatUnits(value, 6);
  const [int, frac = ""] = s.split(".");
  const f = frac.slice(0, maxFrac).replace(/0+$/, "");
  return f ? `${int}.${f}` : int;
}

export function parse6(value: string): bigint {
  if (!value || isNaN(Number(value))) return 0n;
  try {
    return parseUnits(value, 6);
  } catch {
    return 0n;
  }
}

export function shortAddr(a?: string): string {
  if (!a) return "-";
  return `${a.slice(0, 6)}...${a.slice(-4)}`;
}

export function errMessage(e: unknown): string {
  const anyE = e as { shortMessage?: string; message?: string };
  const msg = anyE?.shortMessage || anyE?.message || String(e);
  return msg.length > 180 ? msg.slice(0, 180) + "..." : msg;
}
