<script lang="ts">
  import Segmented from '$lib/components/Segmented.svelte';
  import ItemIcon from '$lib/components/ItemIcon.svelte';
  import Box from '$lib/components/Box.svelte';
  import { store } from '$lib/store.svelte';
  import { dateTime, gold, num } from '$lib/format';
  import { qualityColor } from '$lib/wow';
  import type { Character, Storage } from '$lib/types';

  let { c }: { c: Character } = $props();
  let kind = $state('bags');
  let view = $state('grid');
  let search = $state('');

  const warbands = $derived(store.snapshot?.archive.warbands ?? {});
  const guilds = $derived(store.snapshot?.archive.guilds ?? {});
  const storage = $derived<Storage | undefined>(
    kind === 'bags' ? c.bags : kind === 'bank' ? c.bank
      : kind === 'warband' ? (warbands[c.account ?? ''] ?? Object.values(warbands).sort((a, b) => b.t - a.t)[0])
      : c.guild ? guilds[c.guild] : undefined,
  );
  const count = $derived(storage ? storage.tabs.reduce((s, t) => s + t.items.reduce((x, i) => x + i.count, 0), 0) : 0);
  const hint = $derived(({
    bags: 'Die Taschen speichert das Addon (ab Version 1.3) beim Ausloggen und beim Schließen der Bank.',
    bank: 'Öffne im Spiel einmal deine Bank – das Addon (ab Version 1.3) merkt sich dann den Inhalt.',
    warband: 'Öffne im Spiel einmal die Bank mit dem Kriegsmeuten-Reiter. Der Inhalt gilt für alle Charaktere des Accounts.',
    guild: c.guild ? 'Öffne im Spiel einmal die Gildenbank – erfasst werden alle Fächer, die du sehen darfst.' : 'Dieser Charakter ist (laut Addon) in keiner Gilde.',
  } as Record<string, string>)[kind]);
</script>

<div class="bar">
  <Segmented bind:value={kind} options={[{ id: 'bags', label: 'Taschen' }, { id: 'bank', label: 'Bank' }, { id: 'warband', label: 'Kriegsmeute' }, { id: 'guild', label: 'Gildenbank' }]} />
  <Segmented bind:value={view} options={[{ id: 'grid', label: 'Raster' }, { id: 'list', label: 'Liste' }]} />
  <span class="sp"></span>
  <input type="search" placeholder="Gegenstand suchen" bind:value={search} />
</div>

{#if storage}
  <div class="sum">
    <span>Stand: {dateTime(storage.t)}</span><span>{num(count)} Gegenstände</span>
    {#if storage.gold}<span class="gold">{gold(storage.gold)}</span>{/if}
    {#if kind === 'guild' && storage.seenBy}<span class="dim">zuletzt gesehen von {storage.seenBy.split('-')[0]}</span>{/if}
    {#if kind === 'warband'}<span class="dim">gemeinsam für alle Charaktere des Accounts</span>{/if}
  </div>
  {#each storage.tabs as tab, ti (ti)}
    {@const items = tab.items.filter((i) => !search || (i.name ?? '').toLowerCase().includes(search.toLowerCase()))}
    {#if items.length || !search}
      <Box title="{tab.name} · {items.length} Plätze belegt">
        {#if !items.length}<span class="dim">leer</span>
        {:else if view === 'grid'}
          <div class="grid">{#each items as i, k (k)}<ItemIcon icon={i.icon} quality={i.quality} size={44} count={i.count} tip={{ name: i.name, quality: i.quality, icon: i.icon, itemLevel: i.itemLevel, count: i.count, lines: [{ text: tab.name, color: '#bfb091' }] }} />{/each}</div>
        {:else}
          {#each [...items].sort((a, b) => (b.quality ?? 0) - (a.quality ?? 0) || b.count - a.count) as i, k (k)}
            <div class="li"><ItemIcon icon={i.icon} quality={i.quality} size={26} tip={{ name: i.name, quality: i.quality, icon: i.icon, itemLevel: i.itemLevel, count: i.count }} /><span style="color:{qualityColor(i.quality)}">{i.name ?? '?'}</span>{#if i.itemLevel}<span class="gold sm">GS {Math.round(i.itemLevel)}</span>{/if}<span class="sp"></span><span>{i.count}×</span></div>
          {/each}
        {/if}
      </Box>
    {/if}
  {/each}
{:else}
  <div class="panel box"><h3>Noch kein Inhalt erfasst</h3><p class="dim">{hint}</p></div>
{/if}

<style>
  .bar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .sp { flex: 1; }
  input[type='search'] { width: 240px; }
  .sum { display: flex; gap: 18px; font-size: 13px; }
  .grid { display: flex; flex-wrap: wrap; gap: 6px; }
  .li { display: flex; gap: 10px; align-items: center; padding: 2px 0; }
  .sm { font-size: 11.5px; }
</style>
