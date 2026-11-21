// Sprache der Oberfläche (Deutsch/Englisch).
// Der deutsche Text ist zugleich der Schlüssel – fehlt eine Übersetzung, erscheint er unverändert.
// Namen aus dem Spiel (Quests, Zonen, Gegenstände) kommen in der Sprache des WoW-Clients und bleiben, wie sie sind.

import { en } from './sprache/en';

export type Lang = 'de' | 'en';
const KEY = 'sprache';

function detect(): Lang {
  try {
    const saved = localStorage.getItem(KEY);
    if (saved === 'de' || saved === 'en') return saved;
  } catch { /* kein Speicher, z. B. privates Fenster */ }
  const nav = typeof navigator !== 'undefined' ? navigator.language ?? '' : '';
  return nav.toLowerCase().startsWith('de') ? 'de' : 'en';
}

export const i18n = $state({ lang: detect() as Lang });

export function setLang(l: Lang) {
  i18n.lang = l;
  try { localStorage.setItem(KEY, l); } catch { /* egal */ }
  if (typeof document !== 'undefined') document.documentElement.lang = l;
}

export const locale = () => (i18n.lang === 'de' ? 'de-DE' : 'en-US');

const missing = new Set<string>();

/** Übersetzt einen deutschen Text; Platzhalter wie {n} werden ersetzt */
export function t(de: string, p?: Record<string, string | number | undefined | null>): string {
  // „kontext|Text“: gleicher deutscher Text, aber eigene Übersetzung (z. B. Stufe = Level bzw. Tier)
  const bar = de.indexOf('|');
  let s = bar > 0 && bar < 12 ? de.slice(bar + 1) : de;
  if (i18n.lang === 'en') {
    const tr = en[de];
    if (tr !== undefined) s = tr;
    else if (import.meta.env.DEV && !missing.has(de)) {
      missing.add(de);
      console.warn('[i18n] fehlt:', de);
    }
  }
  if (p) s = s.replace(/\{(\w+)\}/g, (_, k) => String(p[k] ?? ''));
  return s;
}

/** Einzahl/Mehrzahl: tn(3, '{n} Boss', '{n} Bosse') */
export const tn = (n: number, one: string, many: string, p?: Record<string, string | number>) =>
  t(n === 1 ? one : many, { n, ...p });

/** Statusmeldungen der Desktop-Hülle (kommen auf Deutsch aus Rust) übersetzen */
export function statusText(s: string): string {
  const m = s.match(/^(\d+) neue Einträge, (\d+) neue Kämpfe$/);
  if (m) return t('{a} neue Einträge, {b} neue Kämpfe', { a: m[1], b: m[2] });
  for (const prefix of ['Fehler: ', 'Archiv konnte nicht gespeichert werden: ']) {
    if (s.startsWith(prefix)) return t(prefix + '{msg}', { msg: s.slice(prefix.length) });
  }
  return t(s);
}
