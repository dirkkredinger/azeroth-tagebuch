// Anzeige-Formate (deutsch)

const nf = new Intl.NumberFormat('de-DE');
const nf1 = new Intl.NumberFormat('de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 });

export const num = (v: number) => nf.format(v);
export const num1 = (v: number) => nf1.format(v);

/** Kupfer → "12 G 34 S" */
export function gold(copper: number): string {
  const g = Math.floor(copper / 10000);
  const s = Math.floor(copper / 100) % 100;
  const c = copper % 100;
  if (g > 0) return `${nf.format(g)} G ${s} S`;
  if (s > 0) return `${s} S ${c} K`;
  return `${c} K`;
}

/** Sekunden → "2 Std. 5 Min." */
export function duration(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return h > 0 ? `${h} Std. ${m} Min.` : `${m} Min.`;
}

/** 1.234 · 12,3 Tsd. · 4,5 Mio. */
export function big(v: number): string {
  if (Math.abs(v) >= 1_000_000) return `${nf1.format(v / 1_000_000)} Mio.`;
  if (Math.abs(v) >= 10_000) return `${nf1.format(v / 1000)} Tsd.`;
  return nf.format(Math.round(v));
}

const dtf = new Intl.DateTimeFormat('de-DE', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const df = new Intl.DateTimeFormat('de-DE', { day: 'numeric', month: 'short', year: 'numeric' });
const dshort = new Intl.DateTimeFormat('de-DE', { day: 'numeric', month: 'short' });

export const dateTime = (unix: number) => dtf.format(new Date(unix * 1000));
export const date = (unix: number) => df.format(new Date(unix * 1000));
export const dayShort = (d: Date) => dshort.format(d);

const rtf = new Intl.RelativeTimeFormat('de-DE', { numeric: 'auto' });
export function relative(unix: number): string {
  const diff = unix - Date.now() / 1000;
  const abs = Math.abs(diff);
  if (abs < 60) return 'gerade eben';
  if (abs < 3600) return rtf.format(Math.round(diff / 60), 'minute');
  if (abs < 86400) return rtf.format(Math.round(diff / 3600), 'hour');
  if (abs < 86400 * 30) return rtf.format(Math.round(diff / 86400), 'day');
  if (abs < 86400 * 365) return rtf.format(Math.round(diff / (86400 * 30)), 'month');
  return rtf.format(Math.round(diff / (86400 * 365)), 'year');
}
