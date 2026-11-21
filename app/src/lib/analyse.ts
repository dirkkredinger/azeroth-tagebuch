// Auswertungen über das Archiv (laufen in der Oberfläche, damit Handy und Web sie genauso nutzen)

import type { Character, Fight, WowEvent } from './types';

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
export const fightTitle = (f: Fight) => f.encounter ?? f.target ?? 'Kampf';

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
  const source = (key: string, init: () => LootSource) => {
    let s = byKey.get(key);
    if (!s) { s = init(); byKey.set(key, s); }
    return s;
  };

  for (const c of chars) {
    for (const f of fights[c.key] ?? []) {
      for (const k of f.kills ?? []) {
        nameForGuid.set(k.guid, k.name);
        if (k.npcId) nameForNpc.set(k.npcId, k.name);
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
    for (const ev of lootEvents(c)) {
      const isObject = ev.art === 'GameObject';
      const name: string = ev.sn ?? (ev.src ? nameForGuid.get(ev.src) : undefined) ?? (ev.npc ? nameForNpc.get(ev.npc) : undefined)
        ?? (ev.npc ? (isObject ? `Vorkommen #${ev.npc}` : `Gegner #${ev.npc}`) : 'Unbekannte Quelle');
      const key = ev.npc ? `${isObject ? 'obj' : 'npc'}${ev.npc}` : `name${name}`;
      const s = source(key, () => ({ key, npcId: ev.npc, name, isObject, kills: 0, looted: 0, lastSeen: 0, zones: new Set(), items: new Map() }));
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
