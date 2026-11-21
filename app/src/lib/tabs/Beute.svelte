<script lang="ts">
  import StatTile from '$lib/components/StatTile.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import ItemIcon from '$lib/components/ItemIcon.svelte';
  import ExtLink from '$lib/components/ExtLink.svelte';
  import Box from '$lib/components/Box.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import { num } from '$lib/format';
  import { qualityColor, wowheadItem } from '$lib/wow';
  import type { Character } from '$lib/types';

  let { c }: { c: Character } = $props();
  let all = $state(false);
  let kind = $state('mobs');
  let sort = $state('kills');
  let search = $state('');
  let open = $state<string | null>(null);
  const tip = (s: A.LootSource, i: A.ItemDrop) => ({
    name: i.name, quality: i.quality, icon: i.icon,
    lines: [
      { text: `Droprate: ${Math.round(A.dropRate(s, i) * 100)} % (${i.times} von ${s.looted})` },
      { text: `von ${s.name}`, color: '#bfb091' },
      ...(i.total > i.times ? [{ text: `insgesamt ${i.total} Stück erbeutet`, color: '#bfb091' }] : []),
    ],
    hint: i.itemId ? 'Klicken auf den Namen: auf Wowhead ansehen' : undefined,
  });

  const stats = $derived(A.lootStats(all ? store.characters : [c], store.fights));
  const list = $derived(stats
    .filter((s) => s.isObject === (kind === 'objects'))
    .filter((s) => !search || s.name.toLowerCase().includes(search.toLowerCase()) || [...s.items.values()].some((i) => i.name.toLowerCase().includes(search.toLowerCase())))
    .sort((a, b) => sort === 'name' ? a.name.localeCompare(b.name) : sort === 'recent' ? b.lastSeen - a.lastSeen
      : A.effectiveKills(b) - A.effectiveKills(a) || b.looted - a.looted));
  const items = (s: A.LootSource) => [...s.items.values()].sort((a, b) => b.times - a.times || (b.quality ?? 0) - (a.quality ?? 0));
  const tiles = $derived.by(() => {
    const mobs = stats.filter((s) => !s.isObject);
    return {
      kills: mobs.reduce((a, s) => a + A.effectiveKills(s), 0), kinds: mobs.length,
      looted: stats.reduce((a, s) => a + s.looted, 0),
      items: stats.reduce((a, s) => a + [...s.items.values()].reduce((x, i) => x + i.total, 0), 0),
      rare: stats.reduce((a, s) => a + [...s.items.values()].filter((i) => (i.quality ?? 0) >= 2).reduce((x, i) => x + i.times, 0), 0),
    };
  });
  const finds = $derived(stats.flatMap((s) => [...s.items.values()].filter((i) => (i.quality ?? 0) >= 2).map((i) => ({ s, i })))
    .sort((a, b) => (b.i.quality ?? 0) - (a.i.quality ?? 0) || b.i.times - a.i.times).slice(0, 30));
</script>

<div class="grid-tiles">
  <StatTile title="Gegner besiegt" value={num(tiles.kills)} icon="flame" tint="var(--damage)" />
  <StatTile title="Verschiedene Gegner" value={num(tiles.kinds)} icon="paw-print" tint="#f0a030" />
  <StatTile title="Geplündert" value={num(tiles.looted)} icon="backpack" />
  <StatTile title="Gegenstände erbeutet" value={num(tiles.items)} icon="archive" tint="var(--parchment)" />
  <StatTile title="Seltene Funde (grün+)" value={num(tiles.rare)} icon="sparkles" tint="#0070dd" />
</div>

<div class="bar">
  <Segmented bind:value={kind} options={[{ id: 'mobs', label: 'Gegner' }, { id: 'objects', label: 'Vorkommen & Truhen' }]} />
  <Segmented bind:value={sort} options={[{ id: 'kills', label: 'Kills' }, { id: 'recent', label: 'Zuletzt' }, { id: 'name', label: 'Name' }]} />
  <label class="tog"><input type="checkbox" bind:checked={all} /> Alle Charaktere</label>
  <span class="sp"></span>
  <input type="search" placeholder="Gegner oder Gegenstand suchen" bind:value={search} />
</div>

{#each list as s (s.key)}
  <div class="panel src">
    <button class="head" onclick={() => (open = open === s.key ? null : s.key)}>
      <Icon name={s.isObject ? 'sparkles' : 'paw-print'} size={16} color={s.isObject ? 'var(--healing)' : 'var(--damage)'} />
      <div class="nm"><div class="serif b">{s.name}</div><div class="dim sm">{[...s.zones].sort().join(', ')}</div></div>
      <div class="icons">{#each items(s).slice(0, 5) as i}<ItemIcon icon={i.icon} quality={i.quality} size={24} tip={tip(s, i)} />{/each}</div>
      <div class="cnt">{#if !s.isObject}<div class="b">{A.effectiveKills(s)}× besiegt</div>{/if}<div class="dim sm">{s.looted}× geplündert</div></div>
    </button>
    {#if open === s.key}
      <div class="drops">
        {#each items(s) as i (i.key)}
          {@const r = A.dropRate(s, i)}
          <div class="drop">
            <ItemIcon icon={i.icon} quality={i.quality} size={28} tip={tip(s, i)} />
            <ExtLink href={wowheadItem(i.itemId)}><span class="iname" style="color:{qualityColor(i.quality)}">{i.name}</span></ExtLink>
            <span class="track"><i style="width:{Math.max(1, r * 100)}%; background:{qualityColor(i.quality)}"></i></span>
            <b class="gold pct">{Math.round(r * 100)} %</b>
            <span class="dim sm of">{i.times} von {s.looted}{i.total > i.times ? ` · ${i.total} Stück` : ''}</span>
          </div>
        {:else}<div class="dim sm">{s.looted ? 'Keine Gegenstände.' : 'Nie geplündert – kein Beutefenster erfasst.'}</div>{/each}
      </div>
    {/if}
  </div>
{:else}
  <div class="panel box"><h3>{kind === 'objects' ? 'Noch keine Vorkommen geplündert' : 'Noch keine Beute erfasst'}</h3>
    <p class="dim">Besiegte Gegner kommen aus dem Kampflog, die Beute schreibt das Addon (ab Version 1.2) mit, sobald ein Beutefenster aufgeht – auch mit automatischem Plündern. Droprate = wie oft ein Gegenstand dabei war ÷ geplünderte Leichen dieses Gegners.</p></div>
{/each}

{#if finds.length}
  <Box title="Seltene Funde">
    <div class="finds">
      {#each finds as { s, i } (s.key + i.key)}
        <div class="find"><ItemIcon icon={i.icon} quality={i.quality} size={30} tip={tip(s, i)} /><div><div class="b" style="color:{qualityColor(i.quality)}">{i.name}</div><div class="dim sm">von {s.name} · {Math.round(A.dropRate(s, i) * 100)} %</div></div></div>
      {/each}
    </div>
  </Box>
{/if}

<style>
  .bar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .sp { flex: 1; }
  input[type='search'] { width: 260px; }
  .tog { display: flex; gap: 6px; align-items: center; font-size: 13px; }
  .src { padding: 10px; }
  .head { display: flex; gap: 12px; align-items: center; width: 100%; background: none; border: 0; cursor: pointer; text-align: left; }
  .nm { flex: 1; min-width: 0; }
  .b { font-weight: 700; }
  .sm { font-size: 12px; }
  .icons { display: flex; gap: 2px; }
  .cnt { width: 120px; text-align: right; }
  .drops { padding: 10px 0 2px 30px; display: flex; flex-direction: column; gap: 6px; }
  .drop { display: flex; align-items: center; gap: 10px; }
  .iname { display: inline-block; width: 230px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .track { flex: 1; height: 10px; background: rgba(0, 0, 0, 0.35); border-radius: 3px; overflow: hidden; }
  .track i { display: block; height: 100%; opacity: 0.8; }
  .pct { width: 50px; text-align: right; font-variant-numeric: tabular-nums; }
  .of { width: 140px; text-align: right; }
  .finds { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 8px; }
  .find { display: flex; gap: 8px; align-items: center; }
</style>
