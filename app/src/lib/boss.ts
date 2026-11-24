// Auswertung des Dungeonkompendiums für den Boss-Reiter: was ist für Rolle und Spezialisierung wichtig?

import type { Character, Fight, JournalEncounter, JournalSection, WowEvent } from './types';
import { dps, hps } from './analyse';

/** Symbole des Kompendiums (C_EncounterJournal.GetSectionIconFlags) */
export const FLAG = {
  tank: 0, damage: 1, healer: 2, heroic: 3, deadly: 4, important: 5, interrupt: 6,
  magic: 7, curse: 8, poison: 9, disease: 10, enrage: 11, mythic: 12, bleed: 13,
} as const;

export const ROLE_FLAG: Record<string, number> = { TANK: FLAG.tank, DAMAGER: FLAG.damage, HEALER: FLAG.healer };

/** Kurzbeschriftung und Farbe der Symbole (deutsche Schlüssel für t()) */
export const FLAG_INFO: Record<number, { label: string; color: string }> = {
  0: { label: 'Tank', color: '#4f9dff' },
  1: { label: 'Schaden', color: '#ff6b5a' },
  2: { label: 'Heiler', color: '#4cd964' },
  3: { label: 'Heroisch', color: '#c9a24a' },
  4: { label: 'Tödlich', color: '#ff4d4d' },
  5: { label: 'Wichtig', color: '#f0a030' },
  6: { label: 'Unterbrechbar', color: '#4fd6e8' },
  7: { label: 'Magie', color: '#5aa8ff' },
  8: { label: 'Fluch', color: '#c27aff' },
  9: { label: 'Gift', color: '#7bd44f' },
  10: { label: 'Krankheit', color: '#d4b04f' },
  11: { label: 'effekt|Wut', color: '#ff8a3d' },
  12: { label: 'Mythisch', color: '#c27aff' },
  13: { label: 'Blutung', color: '#e04040' },
};

export interface SpecKit {
  /** hat ein Unterbrechen in der Grundausstattung */
  interrupt: boolean;
  /** kann diese Effekte entfernen (Flags 7–11): Verbündete reinigen, Magie von Gegnern bannen, Wut besänftigen */
  removes: number[];
}

// Grundausstattung je Spezialisierung (ohne Talente). Magie zählt auch, wenn man sie nur von Gegnern bannen kann.
const M = FLAG.magic, C = FLAG.curse, P = FLAG.poison, D = FLAG.disease, E = FLAG.enrage;
const KITS: Record<number, number[]> = {
  // Todesritter, Dämonenjäger (Magie verschlingen), Krieger
  250: [], 251: [], 252: [], 577: [M], 581: [M], 1480: [M], 71: [], 72: [], 73: [],
  // Druide: Fluch/Gift, Wiederherstellung zusätzlich Magie; alle besänftigen
  102: [C, P, E], 103: [C, P, E], 104: [C, P, E], 105: [M, C, P, E],
  // Rufer: Gift; Bewahrung zusätzlich Magie
  1467: [P], 1468: [M, P], 1473: [P],
  // Jäger: Beruhigender Schuss (Magie, Wut)
  253: [M, E], 254: [M, E], 255: [M, E],
  // Magier: Fluch, Zauberraub
  62: [M, C], 63: [M, C], 64: [M, C],
  // Mönch: Gift/Krankheit, Nebelwirker zusätzlich Magie
  268: [P, D], 269: [P, D], 270: [M, P, D],
  // Paladin: Gift/Krankheit, Heilig zusätzlich Magie
  65: [M, P, D], 66: [P, D], 70: [P, D],
  // Priester: Magie (Bannen), Krankheit
  256: [M, D], 257: [M, D], 258: [M, D],
  // Schurke: Giftmesser besänftigt Wut
  259: [E], 260: [E], 261: [E],
  // Schamane: Fluch, Wiederherstellung zusätzlich Magie; Reinigen (Gegner) für alle
  262: [M, C], 263: [M, C], 264: [M, C],
  // Hexenmeister: Wichtel/Teufelsjäger bannen Magie
  265: [M], 266: [M], 267: [M],
};
/** ohne Unterbrechen: Disziplin, Heilig (Priester), Wiederherstellung (Druide) */
const NO_INTERRUPT = new Set([256, 257, 105]);

export function specKit(specId?: number): SpecKit | null {
  if (!specId || !(specId in KITS)) return null;
  return { interrupt: !NO_INTERRUPT.has(specId), removes: KITS[specId] };
}

/** Text aus dem Kompendium lesbar machen (Farbcodes, Links, Symbole) */
export function cleanText(s?: string): string {
  if (!s) return '';
  return s
    .replace(/\|c[nN][^:|]*:/g, '')
    .replace(/\|c[0-9a-fA-F]{8}/g, '')
    .replace(/\|r/g, '')
    .replace(/\|H[^|]*\|h(.*?)\|h/g, '$1')
    .replace(/\|T[^|]*\|t/g, '')
    .replace(/\|A[^|]*\|a/g, '')
    .replace(/\$bullet;?/g, '•')
    .replace(/\r\n?/g, '\n')
    .trim();
}

export interface SectionNode { s: JournalSection; children: SectionNode[] }

/** Flache Liste (mit Tiefe) wieder als Baum */
export function tree(sections: JournalSection[]): SectionNode[] {
  const roots: SectionNode[] = [];
  const stack: SectionNode[] = [];
  for (const s of sections) {
    if (s.filtered) continue;
    const node = { s, children: [] };
    while (stack.length > s.depth) stack.pop();
    (stack.length ? stack[stack.length - 1].children : roots).push(node);
    stack.push(node);
  }
  return roots;
}

const OVERVIEW = 3;

export interface BossGuide {
  /** Überblick ohne Rollen-Teile */
  overview: SectionNode[];
  /** Hinweise aus dem Überblick für die gewählte Rolle */
  roleTips: SectionNode[];
  /** Fähigkeiten mit dem Symbol der Rolle */
  roleAbilities: JournalSection[];
  deadly: JournalSection[];
  interrupts: JournalSection[];
  removable: JournalSection[];
  /** alle Fähigkeiten als Baum */
  abilities: SectionNode[];
}

const has = (s: JournalSection, f: number) => s.flags.includes(f);
const flat = (nodes: SectionNode[]): JournalSection[] => nodes.flatMap((n) => [n.s, ...flat(n.children)]);

export function guide(enc: JournalEncounter, role: string | undefined, kit: SpecKit | null): BossGuide {
  const roots = tree(enc.sections);
  const ov = roots.filter((n) => n.s.headerType === OVERVIEW);
  const abilities = roots.filter((n) => n.s.headerType !== OVERVIEW);
  const rf = role ? ROLE_FLAG[role] : undefined;
  const isRole = (n: SectionNode) => n.s.flags.some((f) => f <= 2);
  const roleTips: SectionNode[] = [];
  const overview: SectionNode[] = [];
  for (const root of ov) {
    // Überblick: Wurzel mit allgemeinem Text, Kinder je Rolle („Tanks“, „Heiler“, „Schadensverursacher“)
    const general = { s: root.s, children: root.children.filter((c) => !isRole(c)) };
    overview.push(general);
    for (const c of root.children) if (rf !== undefined && has(c.s, rf)) roleTips.push(c);
  }
  const all = flat(abilities);
  return {
    overview,
    roleTips,
    roleAbilities: rf === undefined ? [] : all.filter((s) => has(s, rf)),
    deadly: all.filter((s) => has(s, FLAG.deadly) || has(s, FLAG.important)),
    interrupts: kit?.interrupt ? all.filter((s) => has(s, FLAG.interrupt)) : [],
    removable: kit ? all.filter((s) => s.flags.some((f) => kit.removes.includes(f))) : [],
    abilities,
  };
}

export interface BossHistory {
  kills: number; wipes: number; fastest?: number; last?: number;
  bestDps?: number; bestHps?: number; deaths: number; pulls: number;
}

/** Eigene Erfahrung mit einem Boss: Ereignisse "boss" vom Addon und Kämpfe aus dem Kampflog */
export function history(c: Character, fights: Fight[], enc: JournalEncounter): BossHistory {
  const name = enc.name.toLowerCase();
  const match = (e: WowEvent) => e.e === 'boss' && ((enc.encounterId && e.eid === enc.encounterId) || e.n?.toLowerCase() === name);
  const ev = c.events.filter(match);
  const fs = fights.filter((f) => f.encounter?.toLowerCase() === name);
  const kills = ev.filter((e) => e.ok === 1);
  const fastest = kills.map((e) => e.dauer ?? 0).filter((d) => d > 0);
  return {
    kills: kills.length,
    wipes: ev.filter((e) => e.ok === 0).length,
    fastest: fastest.length ? Math.min(...fastest) : undefined,
    last: ev.length ? ev[ev.length - 1].t : undefined,
    bestDps: fs.length ? Math.max(...fs.map(dps)) : undefined,
    bestHps: fs.length ? Math.max(...fs.map(hps)) : undefined,
    deaths: fs.reduce((s, f) => s + f.deaths, 0),
    pulls: Math.max(ev.length, fs.length),
  };
}
