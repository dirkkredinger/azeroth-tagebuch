// Datenformat, wie es der Rust-Kern (tagebuch-kern) liefert.

export interface WowEvent {
  t: number;
  e: string;
  m?: number; x?: number; y?: number; mo?: string;
  q?: number; n?: string; c?: string; z?: string; sz?: string;
  xp?: number; g?: number; lv?: number;
  inst?: string; it?: string; diff?: string;
  a?: number; p?: number; txt?: string; dauer?: number; dg?: number;
  il?: number; ilg?: number; sid?: number; spec?: string; rolle?: string; code?: string; lo?: string;
  slot?: number; itemId?: number; quality?: number; ic?: number; alt?: string; altil?: number;
  src?: string; npc?: number; art?: string; sn?: string; items?: LootItem[];
  iid?: number; did?: number; eid?: number; ok?: number; ml?: number; tier?: number; grp?: number; zeit?: number; imzeit?: number;
}

export interface LootItem {
  itemId?: number; name?: string; quality?: number; icon?: number; count?: number; currency?: number; gold?: boolean;
}

export interface GearItem {
  itemId?: number; name?: string; link?: string; quality?: number; itemLevel?: number; icon?: number;
  stats: Record<string, number>;
}

export interface StoredItem { itemId?: number; name?: string; quality?: number; icon?: number; count: number; itemLevel?: number }
export interface StorageTab { name: string; icon?: number; items: StoredItem[] }
export interface Storage { t: number; tabs: StorageTab[]; gold?: number; seenBy?: string }

export interface Character {
  key: string; name: string; realm: string;
  classToken?: string; className?: string; race?: string; faction?: string;
  level?: number; spec?: string; money?: number; account?: string;
  specId?: number; role?: string; specDesc?: string; primaryStat?: number; talentCode?: string;
  itemLevel?: number; guild?: string;
  gear: Record<string, GearItem>;
  bags?: Storage; bank?: Storage;
  events: WowEvent[];
  positionCount: number;
}

export interface FightSpell { name: string; damage: number; healing: number; overheal: number; hits: number; crits: number }
export interface FightKill { guid: string; npcId?: number; name: string; t: number }
export interface Fight {
  char: string; start: number; end: number; zone?: string; mapId?: number;
  encounter?: string; success?: boolean;
  damage: number; healing: number; overheal: number; absorb: number; taken: number; deaths: number;
  itemLevel?: number; target?: string; spells: FightSpell[]; kills: FightKill[];
}

export interface MapInfo { name: string; parent?: number; type?: number }

export interface ArchiveView {
  characters: Character[];
  maps: Record<string, MapInfo>;
  fights: Record<string, Fight[]>;
  warbands: Record<string, Storage>;
  guilds: Record<string, Storage>;
  journal?: Record<string, JournalInstance>;
}

/** Dungeonkompendium (vom Addon im Spiel ausgelesen) */
export interface JournalSection {
  id: number; depth: number; title: string; description?: string; headerType?: number;
  icon?: number; spellId?: number; flags: number[]; filtered: boolean;
}
export interface JournalEncounter { id: number; encounterId?: number; name: string; description?: string; sections: JournalSection[] }
export interface JournalInstance {
  id: number; name: string; description?: string; raid: boolean; mapId?: number; areaMapId?: number;
  difficultyId?: number; locale?: string; t: number; encounters: JournalEncounter[];
}

/** Ort laut Kampflog (ZONE_CHANGE / ENCOUNTER_START) */
export interface LiveLocation {
  char?: string; instanceId: number; name: string; difficultyId: number; t: number;
  encounter?: { id: number; name: string; difficultyId: number; t: number } | null;
}

export interface Snapshot {
  archive: ArchiveView;
  status: string;
  demo: boolean;
  wowFolder: string;
  wowFolderExists: boolean;
  foundFiles: number;
  lastCheck?: number;
  live?: Fight | null;
  location?: LiveLocation | null;
}
