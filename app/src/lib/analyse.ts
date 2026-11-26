// Auswertungen über das Archiv (laufen in der Oberfläche, damit Handy und Web sie genauso nutzen)

import type { Character, Fight, FightKill, WowEvent } from './types';
import { t } from './i18n.svelte';

export const turnIns = (c: Character) => c.events.filter((e) => e.e === 'quest_ab');
export const deaths = (c: Character) => c.events.filter((e) => e.e === 'tod').length;
export const achievements = (c: Character) => c.events.filter((e) => e.e === 'erfolg');
export const levelUps = (c: Character) => c.events.filter((e) => e.e === 'level').length;
export const notes = (c: Character) => c.events.filter((e) => e.e === 'notiz');
export const playSeconds = (c: Character) => c.events.reduce((s, e) => s + (e.e === 'logout' ? e.dauer ?? 0 : 0), 0);
export const lastSeen = (c: Character) => (c.events.length ? c.events[c.events.length - 1].t : undefined);
export const lootEvents = (c: Character) => c.events.filter((e) => e.e === 'beute');

export function questNames(c: Character): Map<number, string> {
  const m = new Map<number, string>();
  for (const e of c.events) if (e.q && e.n) m.set(e.q, e.n);
  return m;
}

/** Quests, die angenommen, aber (noch) nicht abgegeben oder abgebrochen wurden */
export function openQuests(c: Character): WowEvent[] {
  const last = new Map<number, WowEvent>();
  for (const e of c.events) if (e.e.startsWith('quest_') && e.q) last.set(e.q, e);
  return [...last.values()].filter((e) => e.e === 'quest_an').sort((a, b) => b.t - a.t);
}

export const dps = (f: Fight) => f.damage / Math.max(f.end - f.start, 1);
export const hps = (f: Fight) => f.healing / Math.max(f.end - f.start, 1);
export const fightTitle = (f: Fight) => f.encounter ?? f.target ?? t('Kampf');

// ---------- Beute & Dropraten ----------

export interface ItemDrop {
  key: string; itemId?: number; name: string; quality?: number; icon?: number;
  times: number; total: number;
}
export interface LootSource {
  key: string; npcId?: number; name: string; isObject: boolean;
  kills: number; looted: number; lastSeen: number; zones: Set<string>;
  items: Map<string, ItemDrop>;
}
export const effectiveKills = (s: LootSource) => (s.isObject ? 0 : Math.max(s.kills, s.looted));
export const dropRate = (s: LootSource, i: ItemDrop) => (s.looted > 0 ? i.times / s.looted : 0);

const itemKey = (it: { itemId?: number; currency?: number; gold?: boolean; name?: string }) =>
  it.itemId ? `i${it.itemId}` : it.currency ? `c${it.currency}` : it.gold ? 'gold' : `n${it.name ?? '?'}`;

export function lootStats(chars: Character[], fights: Record<string, Fight[]>): LootSource[] {
  const byKey = new Map<string, LootSource>();
  const nameForGuid = new Map<string, string>();
  const nameForNpc = new Map<number, string>();
  /** Boss-Beute (direkt in die Taschen) kennt nur den Bossnamen – darüber zum Gegner aus dem Kampflog */
  const npcForName = new Map<string, number>();
  const source = (key: string, init: () => LootSource) => {
    let s = byKey.get(key);
    if (!s) { s = init(); byKey.set(key, s); }
    return s;
  };

  for (const c of chars) {
    for (const f of fights[c.key] ?? []) {
      for (const k of f.kills ?? []) {
        nameForGuid.set(k.guid, k.name);
        if (k.npcId) { nameForNpc.set(k.npcId, k.name); npcForName.set(k.name.toLowerCase(), k.npcId); }
        const key = k.npcId ? `npc${k.npcId}` : `name${k.name}`;
        const s = source(key, () => ({ key, npcId: k.npcId, name: k.name, isObject: false, kills: 0, looted: 0, lastSeen: 0, zones: new Set(), items: new Map() }));
        s.kills++;
        s.lastSeen = Math.max(s.lastSeen, k.t);
        if (f.zone) s.zones.add(f.zone);
      }
    }
    for (const ev of lootEvents(c)) if (ev.npc && ev.sn) nameForNpc.set(ev.npc, ev.sn);
  }
  for (const c of chars) {
    // Persönliche Beute ohne Boss (Encounter 0) kennt keine Quelle: dem zuletzt getöteten Gegner zuordnen
    const kills = (fights[c.key] ?? []).flatMap((f) => f.kills ?? []).sort((a, b) => a.t - b.t);
    const killBefore = (t: number) => {
      let best: FightKill | undefined;
      for (const k of kills) { if (k.t > t + 1) break; best = k; }
      return best && t - best.t <= 30 ? best : undefined;
    };
    for (const raw of lootEvents(c)) {
      let ev = raw;
      if (ev.src?.startsWith('Encounter-0-')) {
        const k = killBefore(ev.t);
        ev = k ? { ...ev, src: k.guid, npc: k.npcId, sn: k.name, art: 'Creature' } : { ...ev, sn: ev.sn ?? t('Persönliche Beute') };
      }
      const isObject = ev.art === 'GameObject';
      const name: string = ev.sn ?? (ev.src ? nameForGuid.get(ev.src) : undefined) ?? (ev.npc ? nameForNpc.get(ev.npc) : undefined)
        ?? (ev.npc ? (isObject ? t('Vorkommen #{n}', { n: ev.npc }) : t('Gegner #{n}', { n: ev.npc })) : t('Unbekannte Quelle'));
      const npc = ev.npc ?? npcForName.get(name.toLowerCase());
      const key = npc ? `${isObject ? 'obj' : 'npc'}${npc}` : `name${name}`;
      const s = source(key, () => ({ key, npcId: npc, name, isObject, kills: 0, looted: 0, lastSeen: 0, zones: new Set(), items: new Map() }));
      if (/^(Gegner|Vorkommen) #/.test(s.name)) s.name = name;
      s.looted++;
      s.lastSeen = Math.max(s.lastSeen, ev.t);
      if (ev.z) s.zones.add(ev.z);
      const seen = new Set<string>();
      for (const it of ev.items ?? []) {
        const k = itemKey(it);
        let d = s.items.get(k);
        if (!d) { d = { key: k, itemId: it.itemId, name: it.name ?? '?', quality: it.quality, icon: it.icon, times: 0, total: 0 }; s.items.set(k, d); }
        if (!seen.has(k)) { d.times++; seen.add(k); }
        d.total += it.count ?? 1;
      }
    }
  }
  return [...byKey.values()];
}

// ---------- Spielzeit pro Tag ----------

export interface DayPlay { day: number; minutes: Record<string, number> }

/** Spielzeit (Minuten) der letzten `days` Tage je Charakter-Schlüssel */
export function playPerDay(chars: Character[], days = 14): DayPlay[] {
  const newest = Math.max(0, ...chars.map((c) => lastSeen(c) ?? 0));
  const end = new Date((newest || Date.now() / 1000) * 1000);
  end.setHours(0, 0, 0, 0);
  const out: DayPlay[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(end);
    d.setDate(d.getDate() - i);
    out.push({ day: d.getTime() / 1000, minutes: {} });
  }
  const first = out[0].day;
  for (const c of chars) {
    for (const e of c.events) {
      if (e.e !== 'logout' || e.t < first) continue;
      const d = new Date(e.t * 1000);
      d.setHours(0, 0, 0, 0);
      const slot = out.find((x) => x.day === d.getTime() / 1000);
      if (slot) slot.minutes[c.key] = (slot.minutes[c.key] ?? 0) + (e.dauer ?? 0) / 60;
    }
  }
  return out;
}

// ---------- Instanzen & Tiefen ----------

export type RunKind = 'dungeon' | 'delve' | 'raid' | 'scenario' | 'pvp' | 'other';
export interface RunBoss { eid?: number; name: string; t: number; ok: boolean; secs?: number }
export interface RunLoot { itemId?: number; name: string; quality?: number; icon?: number; count: number; gold?: boolean; from?: string }
export interface InstanceRun {
  key: string; char: string; iid?: number; name: string; kind: RunKind;
  difficulty?: string; did?: number; tier?: number; keyLevel?: number;
  start: number; end: number; completed: boolean; timed?: boolean; timer?: number;
  level?: number; itemLevel?: number; group?: number;
  bosses: RunBoss[]; deaths: number; loot: RunLoot[]; gold: number;
}
export interface InstanceSummary {
  key: string; name: string; kind: RunKind; runs: InstanceRun[];
  completed: number; bossKills: number; wipes: number;
  bosses: Map<string, { name: string; kills: number; wipes: number; fastest?: number }>;
  loot: Map<string, RunLoot & { times: number }>;
  difficulties: Map<string, number>; bestTier?: number; bestKey?: number; fastest?: number; last: number;
}

const DELVE_DIFFICULTY = 208;
/** Neu betreten derselben Instanz (z. B. nach einem Tod) gilt bis zu dieser Pause als derselbe Lauf */
const REENTER_SECONDS = 20 * 60;

export function runKind(it?: string, did?: number, diff?: string): RunKind {
  if (it === 'delve' || did === DELVE_DIFFICULTY || /tiefe|delve/i.test(diff ?? '')) return 'delve';
  if (it === 'party') return 'dungeon';
  if (it === 'raid') return 'raid';
  if (it === 'scenario') return 'scenario';
  if (it === 'pvp' || it === 'arena') return 'pvp';
  return 'other';
}

export function instanceRuns(c: Character): InstanceRun[] {
  const runs: InstanceRun[] = [];
  let cur = null as InstanceRun | null;
  const close = (t: number) => { if (cur) { cur.end = Math.max(cur.end, t); cur = null; } };
  const open = (e: WowEvent) => {
    const name = e.inst ?? '?';
    const kind = runKind(e.it, e.did, e.diff);
    // Wiedereinstieg in einen unfertigen Lauf?
    const last = runs[runs.length - 1];
    if (last && last.name === name && !last.completed && e.t - last.end < REENTER_SECONDS
        && (e.did === undefined || last.did === undefined || last.did === e.did)) {
      cur = last;
    } else {
      cur = { key: `${c.key}|${e.t}|${runs.length}`, char: c.key, name, kind, start: e.t, end: e.t, completed: false,
              bosses: [], deaths: 0, loot: [], gold: 0 };
      runs.push(cur);
    }
  };
  for (const e of c.events) {
    if (e.e === 'zone') {
      if (e.inst) { if (!cur || cur.name !== e.inst) { close(e.t); open(e); } }
      else close(e.t);
    } else if (e.e === 'inst_an') {
      if (!cur || cur.name !== e.inst) { close(e.t); open(e); }
      const r = cur!;
      r.iid = e.iid ?? r.iid; r.did = e.did ?? r.did; r.difficulty = e.diff ?? r.difficulty;
      r.kind = runKind(e.it, e.did, e.diff);
      r.tier = e.tier ?? r.tier; r.keyLevel = e.ml ?? r.keyLevel;
      r.level ??= e.lv; r.itemLevel ??= e.il; r.group ??= e.grp;
    } else if (e.e === 'inst_ab' || e.e === 'logout' || e.e === 'login') {
      close(e.t);
    } else if (cur) {
      const r: InstanceRun = cur;
      r.end = Math.max(r.end, e.t);
      if (e.e === 'boss') r.bosses.push({ eid: e.eid, name: e.n ?? '?', t: e.t, ok: e.ok === 1, secs: e.dauer });
      else if (e.e === 'tod') r.deaths++;
      else if (e.e === 'inst_fertig') {
        r.completed = true;
        if (e.ml) r.keyLevel = e.ml;
        if (e.zeit) r.timer = e.zeit;
        if (e.imzeit !== undefined) r.timed = e.imzeit === 1;
      } else if (e.e === 'beute') {
        for (const it of e.items ?? []) {
          if (it.gold) { r.gold += it.count ?? 0; continue; }
          r.loot.push({ itemId: it.itemId, name: it.name ?? '?', quality: it.quality, icon: it.icon, count: it.count ?? 1, from: e.sn });
        }
      }
    }
  }
  // Läufe ohne Abschluss-Ereignis (ältere Addon-Versionen): Dungeon gilt als geschafft, wenn alle Bosse fielen,
  // die dort je besiegt wurden
  const bossesPer = new Map<string, Set<string>>();
  for (const r of runs) for (const b of r.bosses) if (b.ok) {
    const s = bossesPer.get(r.name) ?? new Set(); s.add(b.name); bossesPer.set(r.name, s);
  }
  for (const r of runs) {
    if (r.completed || r.kind !== 'dungeon') continue;
    const all = bossesPer.get(r.name);
    const killed = new Set(r.bosses.filter((b) => b.ok).map((b) => b.name));
    if (all && all.size > 1 && killed.size === all.size) r.completed = true;
  }
  return runs;
}

export function instanceSummaries(runs: InstanceRun[]): InstanceSummary[] {
  const by = new Map<string, InstanceSummary>();
  for (const r of runs) {
    const key = `${r.kind}|${r.name}`;
    let s = by.get(key);
    if (!s) {
      s = { key, name: r.name, kind: r.kind, runs: [], completed: 0, bossKills: 0, wipes: 0, bosses: new Map(),
            loot: new Map(), difficulties: new Map(), last: 0 };
      by.set(key, s);
    }
    s.runs.push(r);
    if (r.completed) {
      s.completed++;
      const secs = r.timer ?? r.end - r.start;
      if (secs > 0 && (s.fastest === undefined || secs < s.fastest)) s.fastest = secs;
    }
    s.last = Math.max(s.last, r.end);
    const d = runLabel(r);
    if (d) s.difficulties.set(d, (s.difficulties.get(d) ?? 0) + 1);
    if (r.tier && r.completed) s.bestTier = Math.max(s.bestTier ?? 0, r.tier);
    if (r.keyLevel && r.completed) s.bestKey = Math.max(s.bestKey ?? 0, r.keyLevel);
    for (const b of r.bosses) {
      const e = s.bosses.get(b.name) ?? { name: b.name, kills: 0, wipes: 0 };
      if (b.ok) {
        e.kills++; s.bossKills++;
        if (b.secs && (e.fastest === undefined || b.secs < e.fastest)) e.fastest = b.secs;
      } else { e.wipes++; s.wipes++; }
      s.bosses.set(b.name, e);
    }
    for (const l of r.loot) {
      const k = l.itemId ? `i${l.itemId}` : `n${l.name}`;
      const e = s.loot.get(k) ?? { ...l, count: 0, times: 0 };
      e.count += l.count; e.times++;
      s.loot.set(k, e);
    }
  }
  return [...by.values()].sort((a, b) => b.last - a.last);
}

/** Kurzbezeichnung eines Laufs: Schwierigkeit, Tiefenstufe oder Schlüsselstein */
export function runLabel(r: InstanceRun): string {
  if (r.kind === 'delve' && r.tier) return `T${r.tier}`;
  if (r.keyLevel) return `+${r.keyLevel}`;
  return r.difficulty ?? '';
}
