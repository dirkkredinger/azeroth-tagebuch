// Anzeige-Formate – folgen der gewählten Sprache

import { i18n, locale, t } from './i18n.svelte';

// Formatierer je Sprache nur einmal anlegen
const cache = new Map<string, Intl.NumberFormat | Intl.DateTimeFormat | Intl.RelativeTimeFormat>();
function fmt<T>(key: string, make: (loc: string) => T): T {
  const k = `${i18n.lang}|${key}`;
  let f = cache.get(k) as T | undefined;
  if (!f) { f = make(locale()); cache.set(k, f as never); }
  return f;
}
const nf = () => fmt('nf', (l) => new Intl.NumberFormat(l));
const nf1 = () => fmt('nf1', (l) => new Intl.NumberFormat(l, { minimumFractionDigits: 1, maximumFractionDigits: 1 }));

export const num = (v: number) => nf().format(v);
export const num1 = (v: number) => nf1().format(v);

/** Kupfer → "12 G 34 S" bzw. "12g 34s" */
export function gold(copper: number): string {
  const g = Math.floor(copper / 10000);
  const s = Math.floor(copper / 100) % 100;
  const c = copper % 100;
  if (i18n.lang === 'en') {
    if (g > 0) return `${num(g)}g ${s}s`;
    if (s > 0) return `${s}s ${c}c`;
    return `${c}c`;
  }
  if (g > 0) return `${num(g)} G ${s} S`;
  if (s > 0) return `${s} S ${c} K`;
  return `${c} K`;
}

/** Sekunden → "2 Std. 5 Min." bzw. "2 h 5 min" */
/** Dauer lesbar: Minuten, Stunden, ab einem Tag Tage, ab einem Jahr Jahre (jeweils die zwei größten Einheiten) */
export function duration(seconds: number): string {
  const en = i18n.lang === 'en';
  const y = Math.floor(seconds / (365 * 86400));
  const d = Math.floor((seconds % (365 * 86400)) / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (y > 0) return en ? `${y} ${y === 1 ? 'year' : 'years'} ${d} ${d === 1 ? 'day' : 'days'}` : `${y} ${y === 1 ? 'Jahr' : 'Jahre'} ${d} ${d === 1 ? 'Tag' : 'Tage'}`;
  if (d > 0) return en ? `${d} ${d === 1 ? 'day' : 'days'} ${h} h` : `${d} ${d === 1 ? 'Tag' : 'Tage'} ${h} Std.`;
  if (en) return h > 0 ? `${h} h ${m} min` : `${m} min`;
  return h > 0 ? `${h} Std. ${m} Min.` : `${m} Min.`;
}

/** 1.234 · 12,3 Tsd. · 4,5 Mio. (englisch: 12.3K · 4.5M) */
export function big(v: number): string {
  const en = i18n.lang === 'en';
  if (Math.abs(v) >= 1_000_000) return en ? `${num1(v / 1_000_000)}M` : `${num1(v / 1_000_000)} Mio.`;
  if (Math.abs(v) >= 10_000) return en ? `${num1(v / 1000)}K` : `${num1(v / 1000)} Tsd.`;
  return num(Math.round(v));
}

const dtf = () => fmt('dt', (l) => new Intl.DateTimeFormat(l, { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }));
const df = () => fmt('d', (l) => new Intl.DateTimeFormat(l, { day: 'numeric', month: 'short', year: 'numeric' }));
const dshort = () => fmt('ds', (l) => new Intl.DateTimeFormat(l, { day: 'numeric', month: 'short' }));
const rtf = () => fmt('rt', (l) => new Intl.RelativeTimeFormat(l, { numeric: 'auto' }));

export const dateTime = (unix: number) => dtf().format(new Date(unix * 1000));
export const date = (unix: number) => df().format(new Date(unix * 1000));
export const dayShort = (d: Date) => dshort().format(d);

export function relative(unix: number): string {
  const diff = unix - Date.now() / 1000;
  const abs = Math.abs(diff);
  const r = rtf();
  if (abs < 60) return t('gerade eben');
  if (abs < 3600) return r.format(Math.round(diff / 60), 'minute');
  if (abs < 86400) return r.format(Math.round(diff / 3600), 'hour');
  if (abs < 86400 * 30) return r.format(Math.round(diff / 86400), 'day');
  if (abs < 86400 * 365) return r.format(Math.round(diff / (86400 * 30)), 'month');
  return r.format(Math.round(diff / (86400 * 365)), 'year');
}
