// Zentraler Zustand der Oberfläche. Holt die Daten über Tauri-Befehle vom Rust-Kern
// und aktualisiert sich bei Änderungen (Ereignisse "tagebuch-aktualisiert" und "live-kampf").

import { invoke } from '@tauri-apps/api/core';
import { i18n, t } from './i18n.svelte';
import { listen } from '@tauri-apps/api/event';
import { open } from '@tauri-apps/plugin-dialog';
import type { Character, Fight, Snapshot, WowEvent } from './types';

class TagebuchStore {
  snapshot = $state<Snapshot | null>(null);
  live = $state<Fight | null>(null);
  /** null = Account-Übersicht */
  selection = $state<string | null>(null);
  search = $state('');
  error = $state<string | null>(null);

  characters = $derived<Character[]>(
    (this.snapshot?.archive.characters ?? []).slice().sort((a, b) => (b.level ?? 0) - (a.level ?? 0) || a.name.localeCompare(b.name)),
  );
  selected = $derived(this.characters.find((c) => c.key === this.selection) ?? null);
  fights = $derived(this.snapshot?.archive.fights ?? {});

  private started = false;
  /** nur Browser-Vorschau: Positionsproben je Charakter */
  private demoPositions = new Map<string, WowEvent[]>();

  /** Positionsproben eines Charakters (werden getrennt geladen, weil es sehr viele sind) */
  async positions(key: string): Promise<WowEvent[]> {
    if (!this.inApp) return this.demoPositions.get(key) ?? [];
    return invoke<WowEvent[]>('positionen', { key });
  }

  async start() {
    if (this.started) return;
    this.started = true;
    if (!('__TAURI_INTERNALS__' in window)) {
      // Im Browser (Vorschau, später Web-Version): Beispieldaten aus demo.json
      await this.loadBrowserDemo();
      return;
    }
    await this.reload();
    await listen('tagebuch-aktualisiert', () => this.reload());
    await listen<Fight | null>('live-kampf', (e) => (this.live = e.payload));
  }

  private async loadBrowserDemo() {
    try {
      const a = await (await fetch(i18n.lang === 'en' ? '/demo-en.json' : '/demo.json')).json();
      const characters = Object.values(a.characters as Record<string, Character>).map((c) => {
        const pos = c.events.filter((e) => e.e === 'pos');
        this.demoPositions.set(c.key, pos);
        return { ...c, events: c.events.filter((e) => e.e !== 'pos'), positionCount: pos.length };
      });
      this.apply({
        archive: { characters, maps: a.maps, fights: a.fights, warbands: a.warbands, guilds: a.guilds },
        status: 'Browser-Vorschau mit Beispieldaten',
        demo: true, wowFolder: '', wowFolderExists: false, foundFiles: 0,
      });
    } catch (e) {
      this.error = `Beispieldaten nicht ladbar: ${e}`;
    }
  }

  private get inApp() { return '__TAURI_INTERNALS__' in window; }

  async reload() {
    try {
      this.apply(await invoke<Snapshot>('lade_daten'));
    } catch (e) {
      this.error = String(e);
    }
  }

  private apply(s: Snapshot) {
    this.snapshot = s;
    this.live = s.live ?? null;
    if (this.selection && !s.archive.characters.some((c) => c.key === this.selection)) this.selection = null;
  }

  async rescan() { if (this.inApp) this.apply(await invoke<Snapshot>('neu_einlesen')); }
  async demo() {
    if (this.inApp) this.apply(await invoke<Snapshot>('beispieldaten', { sprache: i18n.lang }));
    else await this.loadBrowserDemo();
  }

  async chooseFolder() {
    if (!this.inApp) return;
    const dir = await open({ directory: true, title: t('Ordner „_retail_“ deiner WoW-Installation wählen'), defaultPath: this.snapshot?.wowFolder });
    if (typeof dir === 'string') this.apply(await invoke<Snapshot>('setze_wow_ordner', { pfad: dir }));
  }

  show(key: string | null) {
    this.selection = key;
    this.search = '';
  }
}

export const store = new TagebuchStore();
