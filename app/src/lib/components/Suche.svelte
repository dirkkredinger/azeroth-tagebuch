<script lang="ts">
  // Suche über alle Charaktere: Lager („Wo liegt …?“), Quests, Beute, Gegner und Notizen
  import Box from './Box.svelte';
  import ItemIcon from './ItemIcon.svelte';
  import OrnamentHeader from './OrnamentHeader.svelte';
  import EventRow from './EventRow.svelte';
  import Icon from './Icon.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import { date } from '$lib/format';
  import { classColor, qualityColor, questKind } from '$lib/wow';
  import type { Storage, StoredItem } from '$lib/types';

  const q = $derived(store.search.trim().toLowerCase());
  const has = (t?: string) => !!t && t.toLowerCase().includes(q);
  const chars = $derived(store.characters);
  const loot = $derived(A.lootStats(chars, store.fights));

  const stored = $derived.by(() => {
    const out: { place: string; who: string; color: string; item: StoredItem }[] = [];
    const scan = (s: Storage | undefined, place: string, who: string, color: string) => {
      for (const tab of s?.tabs ?? []) for (const item of tab.items) if (has(item.name))
        out.push({ place: (s!.tabs.length > 1 ? `${place} · ${tab.name}` : place), who, color, item });
    };
    for (const c of chars) { scan(c.bags, 'Taschen', c.name, classColor(c.classToken)); scan(c.bank, 'Bank', c.name, classColor(c.classToken)); }
    for (const [acc, w] of Object.entries(store.snapshot?.archive.warbands ?? {})) scan(w, 'Kriegsmeutenbank', acc, 'var(--gold)');
    for (const [g, s] of Object.entries(store.snapshot?.archive.guilds ?? {})) scan(s, 'Gildenbank', g.split('-')[0], 'var(--healing)');
    return out;
  });
  const quests = $derived(chars.flatMap((c) => [
    ...A.turnIns(c).map((e) => ({ c, e, open: false })), ...A.openQuests(c).map((e) => ({ c, e, open: true })),
  ]).filter(({ e }) => has(e.n) || has(e.z)).sort((a, b) => b.e.t - a.e.t));
  const items = $derived(loot.flatMap((s) => [...s.items.values()].filter((i) => has(i.name)).map((i) => ({ s, i })))
    .sort((a, b) => (b.i.quality ?? 0) - (a.i.quality ?? 0) || b.i.times - a.i.times));
  const mobs = $derived(loot.filter((s) => has(s.name)).sort((a, b) => A.effectiveKills(b) - A.effectiveKills(a)));
  const notes = $derived(chars.flatMap((c) => A.notes(c).filter((e) => has(e.txt)).map((e) => ({ c, e }))));
  const nothing = $derived(!stored.length && !quests.length && !items.length && !mobs.length && !notes.length);
</script>

<div class="page">
  <OrnamentHeader text="Suche: „{store.search.trim()}“" />
  <div class="dim">{stored.length} im Lager · {quests.length} Quests · {items.length} Gegenstände · {mobs.length} Gegner · {notes.length} Notizen</div>

  {#if nothing}
    <div class="panel box dim">Nichts gefunden. Gesucht wird in Questnamen, Zonen, Beute, Gegnern, Notizen sowie Taschen und Banken aller Charaktere.</div>
  {/if}

  {#if stored.length}
    <Box title="Wo liegt …?">
      {#each stored.slice(0, 80) as h, k (k)}
        <div class="row">
          <ItemIcon icon={h.item.icon} quality={h.item.quality} size={28} tip={{ name: h.item.name, quality: h.item.quality, icon: h.item.icon, itemLevel: h.item.itemLevel, count: h.item.count, lines: [{ text: `${h.who} · ${h.place}`, color: '#bfb091' }] }} />
          <b style="color:{qualityColor(h.item.quality)}">{h.item.name}</b>
          {#if h.item.itemLevel}<span class="gold sm">GS {Math.round(h.item.itemLevel)}</span>{/if}
          <span class="sp"></span><span>{h.item.count}×</span>
          <span class="who" style="color:{h.color}">{h.who}</span><span class="dim sm place">{h.place}</span>
        </div>
      {/each}
    </Box>
  {/if}

  {#if quests.length}
    <Box title="Quests">
      {#each quests.slice(0, 60) as { c, e, open } (c.key + e.t + e.q)}
        <button class="row btnrow" onclick={() => store.show(c.key)}>
          <Icon name={open ? 'circle-alert' : 'badge-check'} size={15} color={open ? '#f0a030' : '#f5d742'} />
          <div class="grow"><b>{e.n}</b><div class="dim sm">{[e.z, open ? 'offen' : questKind(e.c)].filter(Boolean).join(' · ')}</div></div>
          <span class="who" style="color:{classColor(c.classToken)}">{c.name}</span><span class="dim sm place">{date(e.t)}</span>
        </button>
      {/each}
    </Box>
  {/if}

  {#if items.length}
    <Box title="Beute">
      {#each items.slice(0, 60) as { s, i } (s.key + i.key)}
        <div class="row">
          <ItemIcon icon={i.icon} quality={i.quality} size={28} tip={{ name: i.name, quality: i.quality, icon: i.icon, lines: [{ text: `Droprate: ${Math.round(A.dropRate(s, i) * 100)} % (${i.times} von ${s.looted})` }, { text: `von ${s.name}`, color: '#bfb091' }] }} />
          <div class="grow"><b style="color:{qualityColor(i.quality)}">{i.name}</b><div class="dim sm">von {s.name}{s.zones.size ? ' · ' + [...s.zones].sort().join(', ') : ''}</div></div>
          <b class="gold">{Math.round(A.dropRate(s, i) * 100)} %</b><span class="dim sm place">{i.times} von {s.looted}</span>
        </div>
      {/each}
    </Box>
  {/if}

  {#if mobs.length}
    <Box title="Gegner & Vorkommen">
      {#each mobs.slice(0, 30) as s (s.key)}
        <div class="row"><Icon name={s.isObject ? 'sparkles' : 'paw-print'} size={15} color="var(--damage)" />
          <div class="grow"><b>{s.name}</b><div class="dim sm">{[...s.zones].sort().join(', ')}</div></div>
          <span>{A.effectiveKills(s)}× besiegt</span><span class="dim sm place">{s.looted}× geplündert</span></div>
      {/each}
    </Box>
  {/if}

  {#if notes.length}
    <Box title="Notizen">
      {#each notes as { c, e } (c.key + e.t)}
        <div class="row"><span class="who" style="color:{classColor(c.classToken)}">{c.name}</span><div class="grow"><EventRow event={e} /></div></div>
      {/each}
    </Box>
  {/if}
</div>

<style>
  .page { padding: 24px; display: flex; flex-direction: column; gap: 16px; }
  .row { display: flex; align-items: center; gap: 10px; padding: 4px 0; width: 100%; }
  .btnrow { background: none; border: 0; cursor: pointer; text-align: left; }
  .btnrow:hover { background: rgba(158, 122, 61, 0.08); }
  .grow { flex: 1; min-width: 0; }
  .sp { flex: 1; }
  .sm { font-size: 12px; }
  .who { width: 110px; text-align: right; font-size: 12px; font-weight: 700; }
  .place { width: 190px; }
</style>
