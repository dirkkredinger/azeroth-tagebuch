// Farben, Bezeichnungen und Texte rund um WoW-Daten

import type { Character, WowEvent } from './types';
import { duration, gold, num, num1 } from './format';
import { i18n, t, tn } from './i18n.svelte';

export const classColors: Record<string, string> = {
  WARRIOR: '#c79c6e', PALADIN: '#f58cba', HUNTER: '#abd473', ROGUE: '#fff569', PRIEST: '#e6e6e6',
  DEATHKNIGHT: '#c41f3b', SHAMAN: '#0070de', MAGE: '#40c7eb', WARLOCK: '#8787ed', MONK: '#00ff96',
  DRUID: '#ff7d0a', DEMONHUNTER: '#a330c9', EVOKER: '#33937f',
};
export const classColor = (token?: string) => classColors[token ?? ''] ?? '#a89878';

export function qualityColor(q?: number): string {
  switch (q ?? 1) {
    case 0: return '#9d9d9d';
    case 1: return '#f2f2f2';
    case 2: return '#1eff00';
    case 3: return '#0070dd';
    case 4: return '#a335ee';
    case 5: return '#ff8000';
    case 6: return '#e6cc80';
    default: return '#00ccff';
  }
}

export function subtitle(c: Character): string {
  return [c.level ? t('Stufe {n}', { n: c.level }) : null, c.race, c.className].filter(Boolean).join(' · ');
}

export function questKind(c?: string): string {
  const map: Record<string, string> = {
    Campaign: 'Kampagne', WorldQuest: 'Weltquest', Important: 'Wichtig', Legendary: 'Legendär', Calling: 'Berufung',
    Meta: 'Meta', Recurring: 'Wiederholbar', Questline: 'Questreihe', BonusObjective: 'Bonusziel', Threat: 'Bedrohung',
    Normal: 'Normal',
  };
  const de = map[c ?? 'Normal'];
  return de ? t(de) : c ?? t('Normal');
}

/** Titel eines Tagebucheintrags */
export function eventTitle(ev: WowEvent, questNames: Map<number, string> = new Map()): string {
  const sub = (z?: string, sz?: string) => (z || '?') + (sz ? ` – ${sz}` : '');
  switch (ev.e) {
    case 'login': return ev.lv ? t('Eingeloggt (Stufe {lv})', { lv: ev.lv }) : t('Eingeloggt');
    case 'logout': return t('Ausgeloggt nach {d}', { d: duration(ev.dauer ?? 0) });
    case 'zone':
      if (ev.inst) return t('Instanz betreten: {name}', { name: ev.inst }) + (ev.diff ? ` (${ev.diff})` : '');
      return t('Unterwegs in {ort}', { ort: sub(ev.z, ev.sz) });
    case 'quest_an': return t('Quest angenommen: {name}', { name: ev.n ?? '?' });
    case 'quest_ab': return t('Quest abgeschlossen: {name}', { name: ev.n ?? '?' });
    case 'quest_weg': return t('Quest abgebrochen: {name}', { name: (ev.q && questNames.get(ev.q)) || '#' + (ev.q ?? 0) });
    case 'level': return t('Stufe {n} erreicht!', { n: ev.lv ?? 0 });
    case 'erfolg': return t('Erfolg errungen: {name}', { name: ev.n ?? '?' }) + (ev.p ? ' ' + t('({n} Punkte)', { n: ev.p }) : '');
    case 'tod': return t('Gestorben in {ort}', { ort: sub(ev.z, ev.sz) });
    case 'taxi_start': return t('Flug mit dem Flugmeister gestartet');
    case 'taxi_ende': return t('Mit dem Flugmeister gelandet');
    case 'notiz': return i18n.lang === 'de' ? `„${ev.txt ?? ''}“` : `“${ev.txt ?? ''}”`;
    case 'ausr': return t('Gegenstandsstufe {n}', { n: num1(ev.il ?? 0) });
    case 'talente': return t('Talente: {spec}', { spec: ev.spec ?? '?' }) + (ev.lo ? ` – ${ev.lo}` : '');
    case 'gegenstand': return t('Neu angelegt: {name}', { name: ev.n ?? '?' }) + (ev.il ? ` (${Math.round(ev.il)})` : '');
    case 'beute': {
      const n = ev.items?.length ?? 0;
      return t('Beute von {von}', { von: ev.sn ?? t('Gegner') }) + ' (' + tn(n, '{n} Gegenstand', '{n} Gegenstände') + ')';
    }
    case 'inst_an': return t('Instanz betreten: {name}', { name: ev.inst ?? '?' }) + (ev.tier ? ' ' + t('(Stufe {n})', { n: ev.tier }) : ev.ml ? ` (+${ev.ml})` : ev.diff ? ` (${ev.diff})` : '');
    case 'inst_ab': return t('Instanz verlassen: {name}', { name: ev.inst ?? '?' });
    case 'inst_fertig': return t('Abgeschlossen: {name}', { name: ev.inst ?? '?' }) + (ev.ml ? ` (+${ev.ml})` : '');
    case 'boss': return ev.ok ? t('Boss besiegt: {name}', { name: ev.n ?? '?' }) : t('Gescheitert an: {name}', { name: ev.n ?? '?' });
    default: return ev.e;
  }
}

export function eventDetail(ev: WowEvent): string | null {
  switch (ev.e) {
    case 'quest_ab': {
      const parts: string[] = [];
      if (ev.z) parts.push(ev.z);
      if (ev.xp) parts.push(t('{n} EP', { n: num(ev.xp) }));
      if (ev.g) parts.push(gold(ev.g));
      if (ev.c && ev.c !== 'Normal') parts.push(questKind(ev.c));
      return parts.length ? parts.join(' · ') : null;
    }
    case 'logout': return ev.dg ? (ev.dg > 0 ? '+' : '−') + gold(Math.abs(ev.dg)) : null;
    case 'notiz': return ev.z ?? null;
    case 'inst_fertig': case 'inst_ab': case 'boss': return ev.dauer ? duration(ev.dauer) : null;
    default: return null;
  }
}

/** Symbolname (Lucide) und Farbe je Eintragstyp */
export function eventStyle(ev: WowEvent): { icon: string; color: string } {
  switch (ev.e) {
    case 'login': return { icon: 'log-in', color: '#a89878' };
    case 'logout': return { icon: 'log-out', color: '#a89878' };
    case 'zone': return { icon: ev.inst ? 'shield' : 'map', color: '#a89878' };
    case 'quest_an': return { icon: 'circle-alert', color: '#f0a030' };
    case 'quest_ab': return { icon: 'badge-check', color: '#f5d742' };
    case 'quest_weg': return { icon: 'circle-x', color: '#888' };
    case 'level': return { icon: 'circle-arrow-up', color: '#4cd964' };
    case 'erfolg': return { icon: 'trophy', color: '#d9a521' };
    case 'tod': return { icon: 'heart-crack', color: '#ff4d4d' };
    case 'taxi_start': case 'taxi_ende': return { icon: 'plane', color: '#7b7bff' };
    case 'notiz': return { icon: 'notebook-pen', color: '#c27aff' };
    case 'ausr': return { icon: 'shield-check', color: '#4fd6e8' };
    case 'talente': return { icon: 'sparkles', color: '#5ee6b5' };
    case 'gegenstand': return { icon: 'shirt', color: qualityColor(ev.quality) };
    case 'beute': return { icon: 'backpack', color: '#fbcc5c' };
    case 'inst_an': case 'inst_ab': return { icon: ev.it === 'delve' ? 'pickaxe' : 'castle', color: '#4f9dff' };
    case 'inst_fertig': return { icon: 'badge-check', color: '#4cd964' };
    case 'boss': return { icon: 'skull', color: ev.ok ? '#ff6a4d' : '#888' };
    default: return { icon: 'circle', color: '#a89878' };
  }
}

// ---------- Ausrüstung ----------

const SLOT_DE: Record<string, string> = {
  '1': 'Kopf', '2': 'Hals', '3': 'Schultern', '4': 'Hemd', '5': 'Brust', '6': 'Taille', '7': 'Beine', '8': 'Füße',
  '9': 'Handgelenke', '10': 'Hände', '11': 'Finger 1', '12': 'Finger 2', '13': 'Schmuck 1', '14': 'Schmuck 2',
  '15': 'Rücken', '16': 'Waffenhand', '17': 'Schildhand', '19': 'Wappenrock',
};
const STAT_DE: Record<string, string> = {
  str: 'Stärke', bew: 'Beweglichkeit', int: 'Intellekt', aus: 'Ausdauer',
  krit: 'Krit', tempo: 'Tempo', meist: 'Meisterschaft', viel: 'Vielseitigkeit',
};
export const slotName = (slot: string | number) => { const d = SLOT_DE[String(slot)]; return d ? t(d) : String(slot); };
export const statLabel = (k: string) => { const d = STAT_DE[k]; return d ? t(d) : k; };
export const STAT_ORDER = ['str', 'bew', 'int', 'aus', 'krit', 'tempo', 'meist', 'viel'];
export function qualityName(q?: number): string {
  const d = ['Schlecht', 'Gewöhnlich', 'Selten', 'Rar', 'Episch', 'Legendär', 'Artefakt', 'Erbstück'][q ?? 1];
  return d ? t(d) : '–';
}
/** Wowhead in der Sprache der Oberfläche */
export const wowheadBase = () => (i18n.lang === 'de' ? 'https://www.wowhead.com/de' : 'https://www.wowhead.com');
export const wowheadItem = (id?: number) => (id ? `${wowheadBase()}/item=${id}` : null);

// ---------- Klassen & Spezialisierungen (eigene Kurztexte, Links zu Wowhead) ----------

export const SPECS: Record<number, { cls: string; slug: string; role: string }> = {
  250: { cls: 'death-knight', slug: 'blood', role: 'TANK' }, 251: { cls: 'death-knight', slug: 'frost', role: 'DAMAGER' }, 252: { cls: 'death-knight', slug: 'unholy', role: 'DAMAGER' },
  577: { cls: 'demon-hunter', slug: 'havoc', role: 'DAMAGER' }, 581: { cls: 'demon-hunter', slug: 'vengeance', role: 'TANK' }, 1480: { cls: 'demon-hunter', slug: 'devourer', role: 'DAMAGER' },
  102: { cls: 'druid', slug: 'balance', role: 'DAMAGER' }, 103: { cls: 'druid', slug: 'feral', role: 'DAMAGER' }, 104: { cls: 'druid', slug: 'guardian', role: 'TANK' }, 105: { cls: 'druid', slug: 'restoration', role: 'HEALER' },
  1467: { cls: 'evoker', slug: 'devastation', role: 'DAMAGER' }, 1468: { cls: 'evoker', slug: 'preservation', role: 'HEALER' }, 1473: { cls: 'evoker', slug: 'augmentation', role: 'DAMAGER' },
  253: { cls: 'hunter', slug: 'beast-mastery', role: 'DAMAGER' }, 254: { cls: 'hunter', slug: 'marksmanship', role: 'DAMAGER' }, 255: { cls: 'hunter', slug: 'survival', role: 'DAMAGER' },
  62: { cls: 'mage', slug: 'arcane', role: 'DAMAGER' }, 63: { cls: 'mage', slug: 'fire', role: 'DAMAGER' }, 64: { cls: 'mage', slug: 'frost', role: 'DAMAGER' },
  268: { cls: 'monk', slug: 'brewmaster', role: 'TANK' }, 269: { cls: 'monk', slug: 'windwalker', role: 'DAMAGER' }, 270: { cls: 'monk', slug: 'mistweaver', role: 'HEALER' },
  65: { cls: 'paladin', slug: 'holy', role: 'HEALER' }, 66: { cls: 'paladin', slug: 'protection', role: 'TANK' }, 70: { cls: 'paladin', slug: 'retribution', role: 'DAMAGER' },
  256: { cls: 'priest', slug: 'discipline', role: 'HEALER' }, 257: { cls: 'priest', slug: 'holy', role: 'HEALER' }, 258: { cls: 'priest', slug: 'shadow', role: 'DAMAGER' },
  259: { cls: 'rogue', slug: 'assassination', role: 'DAMAGER' }, 260: { cls: 'rogue', slug: 'outlaw', role: 'DAMAGER' }, 261: { cls: 'rogue', slug: 'subtlety', role: 'DAMAGER' },
  262: { cls: 'shaman', slug: 'elemental', role: 'DAMAGER' }, 263: { cls: 'shaman', slug: 'enhancement', role: 'DAMAGER' }, 264: { cls: 'shaman', slug: 'restoration', role: 'HEALER' },
  265: { cls: 'warlock', slug: 'affliction', role: 'DAMAGER' }, 266: { cls: 'warlock', slug: 'demonology', role: 'DAMAGER' }, 267: { cls: 'warlock', slug: 'destruction', role: 'DAMAGER' },
  71: { cls: 'warrior', slug: 'arms', role: 'DAMAGER' }, 72: { cls: 'warrior', slug: 'fury', role: 'DAMAGER' }, 73: { cls: 'warrior', slug: 'protection', role: 'TANK' },
};

export const CLASSES: Record<string, { slug: string; armor: string; resource: string; text: string }> = {
  DEATHKNIGHT: { slug: 'death-knight', armor: 'Platte', resource: 'Runen & Runenmacht', text: 'Untote Ritter, die Frost, Seuche und Blut beherrschen.' },
  DEMONHUNTER: { slug: 'demon-hunter', armor: 'Leder', resource: 'Zorn / Qual', text: 'Wendige Jäger, die dämonische Kräfte gegen ihre Feinde wenden.' },
  DRUID: { slug: 'druid', armor: 'Leder', resource: 'Mana, Energie, Wut, Astrale Macht', text: 'Gestaltwandler, die jede Rolle übernehmen können.' },
  EVOKER: { slug: 'evoker', armor: 'Kette', resource: 'Mana & Essenz', text: 'Drachenblütige Zauberwirker mit aufladbaren Fähigkeiten.' },
  HUNTER: { slug: 'hunter', armor: 'Kette', resource: 'Fokus', text: 'Fernkämpfer mit Tiergefährten und Fallen.' },
  MAGE: { slug: 'mage', armor: 'Stoff', resource: 'Mana', text: 'Gelehrte der Arkan-, Feuer- und Frostmagie.' },
  MONK: { slug: 'monk', armor: 'Leder', resource: 'Energie, Chi, Mana', text: 'Kampfkünstler, die Chi lenken.' },
  PALADIN: { slug: 'paladin', armor: 'Platte', resource: 'Mana & Heilige Kraft', text: 'Streiter des Lichts für Schutz, Heilung und Vergeltung.' },
  PRIEST: { slug: 'priest', armor: 'Stoff', resource: 'Mana / Wahnsinn', text: 'Heiler und Schattenwirker.' },
  ROGUE: { slug: 'rogue', armor: 'Leder', resource: 'Energie & Combopunkte', text: 'Meister der Klingen, Gifte und Heimlichkeit.' },
  SHAMAN: { slug: 'shaman', armor: 'Kette', resource: 'Mana / Mahlstrom', text: 'Rufen die Elemente und stellen Totems auf.' },
  WARLOCK: { slug: 'warlock', armor: 'Stoff', resource: 'Mana & Seelensplitter', text: 'Beschwören Dämonen und lassen Gebrechen wirken.' },
  WARRIOR: { slug: 'warrior', armor: 'Platte', resource: 'Wut', text: 'Waffenmeister in Rüstung, im Angriff wie in der Verteidigung.' },
};

export const roleName = (r?: string) => { const d = ({ TANK: 'Tank', HEALER: 'Heiler', DAMAGER: 'Schaden' } as Record<string, string>)[r ?? '']; return d ? t(d) : '–'; };
export const statName = (s?: number) => { const d = ({ 1: 'Stärke', 2: 'Beweglichkeit', 4: 'Intellekt' } as Record<number, string>)[s ?? 0]; return d ? t(d) : undefined; };

/** Links zu den Wowhead-Guides (nur verlinkt, nicht übernommen) */
export function guideLinks(specId?: number, role?: string, classToken?: string, talentCode?: string) {
  const base = wowheadBase();
  const out: { title: string; icon: string; url: string }[] = [];
  const spec = specId ? SPECS[specId] : undefined;
  if (spec) {
    const r = ({ TANK: 'tank', HEALER: 'healer' } as Record<string, string>)[role ?? spec.role] ?? 'dps';
    const g = `${base}/guide/classes/${spec.cls}/${spec.slug}`;
    out.push({ title: t('Talent-Builds'), icon: 'sparkles', url: `${g}/talent-builds-pve-${r}` });
    out.push({ title: t('Überblick'), icon: 'book-open', url: `${g}/overview-pve-${r}` });
    out.push({ title: t('Rotation & Abklingzeiten'), icon: 'refresh-cw', url: `${g}/rotation-cooldowns-pve-${r}` });
    out.push({ title: t('Werte-Prioritäten'), icon: 'chart', url: `${g}/stat-priority-pve-${r}` });
    out.push({ title: t('Ausrüstung (Best in Slot)'), icon: 'shield-check', url: `${g}/bis-gear` });
  } else if (classToken && CLASSES[classToken]) {
    out.push({ title: t('Klassen-Guides'), icon: 'book-open', url: `${base}/guide/classes/${CLASSES[classToken].slug}` });
  }
  if (talentCode && !talentCode.startsWith('DEMO')) {
    out.push({ title: t('Meine Talente im Talentrechner'), icon: 'wand-sparkles', url: `${base}/talent-calc/blizzard/${encodeURIComponent(talentCode)}` });
  }
  return out;
}
