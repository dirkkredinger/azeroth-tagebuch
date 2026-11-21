<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Icon from './Icon.svelte';
  import Avatar from './Avatar.svelte';
  import StatTile from './StatTile.svelte';
  import EventRow from './EventRow.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import { big, duration, gold, num } from '$lib/format';
  import type { Character } from '$lib/types';
  import Quests from '$lib/tabs/Quests.svelte';
  import Zeitleiste from '$lib/tabs/Zeitleiste.svelte';
  import Statistik from '$lib/tabs/Statistik.svelte';
  import Karte from '$lib/tabs/Karte.svelte';
  import Kampf from '$lib/tabs/Kampf.svelte';
  import Ausruestung from '$lib/tabs/Ausruestung.svelte';
  import Beute from '$lib/tabs/Beute.svelte';
  import Lager from '$lib/tabs/Lager.svelte';
  import Klasse from '$lib/tabs/Klasse.svelte';
  import Instanzen from '$lib/tabs/Instanzen.svelte';

  let { c }: { c: Character } = $props();

  const tabs = [
    { id: 'uebersicht', label: 'Übersicht', icon: 'house' },
    { id: 'quests', label: 'Quests', icon: 'circle-alert' },
    { id: 'karte', label: 'Karte', icon: 'map' },
    { id: 'zeitleiste', label: 'Zeitleiste', icon: 'scroll-text' },
    { id: 'statistik', label: 'Statistik', icon: 'chart' },
    { id: 'kampf', label: 'Kampf', icon: 'flame' },
    { id: 'heilung', label: 'Heilung', icon: 'heart-pulse' },
    { id: 'ausruestung', label: 'Ausrüstung', icon: 'shirt' },
    { id: 'instanzen', label: 'Instanzen', icon: 'castle' },
    { id: 'beute', label: 'Beute', icon: 'backpack' },
    { id: 'lager', label: 'Lager', icon: 'archive' },
    { id: 'klasse', label: 'Klasse', icon: 'user' },
  ];
  let tab = $state('uebersicht');

  const fights = $derived(store.fights[c.key] ?? []);
  const names = $derived(A.questNames(c));
  const recent = $derived(c.events.filter((e) => e.e !== 'zone' && e.e !== 'inst_ab').slice(-12).reverse());
  const live = $derived(store.live && store.live.char === c.key ? store.live : null);
  const zones = $derived(new Set(c.events.filter((e) => e.e === 'zone' && e.z && !e.inst).map((e) => e.z)).size);
  const questGold = $derived(A.turnIns(c).reduce((s, e) => s + (e.g ?? 0), 0));
  const questXp = $derived(A.turnIns(c).reduce((s, e) => s + (e.xp ?? 0), 0));
</script>

<div class="page">
  <button class="back serif" onclick={() => store.show(null)}><Icon name="chevron-left" size={14} /> {t('Alle Charaktere')}</button>

  <header>
    <Avatar name={c.name} token={c.classToken} size={56} round={false} />
    <div class="who">
      <h1 class="serif">{c.name}</h1>
      <div class="dim">{[c.level ? t('Stufe {n}', { n: c.level }) : null, c.race, c.className, c.spec, c.realm].filter(Boolean).join(' · ')}</div>
    </div>
    {#if live}<span class="pill live"><Icon name="flame" size={12} /> {t('Im Kampf')} · {big(A.dps(live))} DPS</span>{/if}
    {#if c.itemLevel}<span class="pill"><Icon name="shield-check" size={12} /> {t('GS {n}', { n: Math.round(c.itemLevel) })}</span>{/if}
    {#if c.faction}<span class="pill" class:horde={c.faction === 'Horde'} class:ally={c.faction === 'Alliance'}>{c.faction === 'Alliance' ? t('Allianz') : c.faction}</span>{/if}
  </header>

  <nav>
    {#each tabs as tb}
      <button class:active={tab === tb.id} onclick={() => (tab = tb.id)}><Icon name={tb.icon} size={12} /> {t(tb.label)}</button>
    {/each}
  </nav>
  <div class="rule"></div>

  {#if tab === 'uebersicht'}
    <div class="grid-tiles">
      <StatTile title={t('Quests abgeschlossen')} value={num(A.turnIns(c).length)} icon="badge-check" tint="#f5d742" />
      <StatTile title={t('Offene Quests')} value={num(A.openQuests(c).length)} icon="circle-alert" tint="#f0a030" />
      <StatTile title={t('Spielzeit')} value={duration(A.playSeconds(c))} icon="clock" tint="#4f9dff" />
      <StatTile title={t('Stufenaufstiege')} value={num(A.levelUps(c))} icon="circle-arrow-up" tint="#4cd964" />
      <StatTile title={t('Gold aus Quests')} value={gold(questGold)} icon="coins" tint="#f5d742" />
      <StatTile title={t('EP aus Quests')} value={num(questXp)} icon="sparkles" tint="#c27aff" />
      <StatTile title={t('Zonen besucht')} value={num(zones)} icon="map" tint="#4fd6e8" />
      <StatTile title={t('Kämpfe')} value={num(fights.length)} icon="swords" tint="var(--damage)" />
      <StatTile title={t('Erfolge')} value={num(A.achievements(c).length)} icon="trophy" tint="#f0a030" />
      <StatTile title={t('Tode')} value={num(A.deaths(c))} icon="heart-crack" tint="#ff4d4d" />
      <StatTile title={t('Gold aktuell')} value={gold(c.money ?? 0)} icon="coins" tint="#f5d742" />
    </div>
    {#if A.notes(c).length}
      <div class="panel box"><h3>{t('Deine Notizen')}</h3>
        {#each A.notes(c).slice(-5).reverse() as e (e.t + (e.txt ?? ''))}<EventRow event={e} />{/each}
      </div>
    {/if}
    <div class="panel box"><h3>{t('Zuletzt passiert')}</h3>
      {#each recent as e (e.t + e.e + (e.q ?? '') + (e.src ?? '') + (e.slot ?? ''))}<EventRow event={e} {names} />{/each}
    </div>
  {:else if tab === 'quests'}<Quests {c} />
  {:else if tab === 'karte'}<Karte {c} />
  {:else if tab === 'zeitleiste'}<Zeitleiste {c} />
  {:else if tab === 'statistik'}<Statistik {c} />
  {:else if tab === 'kampf'}<Kampf {c} mode="damage" />
  {:else if tab === 'heilung'}<Kampf {c} mode="healing" />
  {:else if tab === 'ausruestung'}<Ausruestung {c} />
  {:else if tab === 'instanzen'}<Instanzen {c} />
  {:else if tab === 'beute'}<Beute {c} />
  {:else if tab === 'lager'}<Lager {c} />
  {:else if tab === 'klasse'}<Klasse {c} />
  {/if}
</div>

<style>
  .page { padding: 14px 24px 24px; display: flex; flex-direction: column; gap: 14px; }
  .back { align-self: flex-start; display: inline-flex; align-items: center; gap: 4px; background: none; border: 0; color: var(--gold); cursor: pointer; font-size: 12.5px; font-weight: 600; padding: 0; }
  header { display: flex; align-items: center; gap: 14px; }
  .who { flex: 1; }
  h1 { margin: 0; font-size: 26px; color: var(--gold); text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8); }
  .pill { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; font-weight: 700; padding: 4px 10px; border-radius: 999px; background: rgba(158, 122, 61, 0.25); }
  .pill.live { color: #ff5a5a; background: rgba(255, 60, 60, 0.15); }
  .horde { background: rgba(255, 50, 50, 0.3); }
  .ally { background: rgba(50, 110, 255, 0.3); }
  nav { display: flex; gap: 3px; flex-wrap: wrap; }
  nav button { display: inline-flex; align-items: center; gap: 5px; padding: 6px 9px; border-radius: 6px; cursor: pointer; font-family: var(--serif); font-size: 12.5px; color: var(--parchment-dim); background: rgba(43, 31, 20, 0.8); border: 1px solid rgba(158, 122, 61, 0.4); }
  nav button.active { color: var(--ink); font-weight: 700; background: linear-gradient(180deg, var(--gold), var(--gold-deep)); border-color: rgba(158, 122, 61, 0.9); }
  .rule { height: 1px; background: rgba(158, 122, 61, 0.45); }
</style>
