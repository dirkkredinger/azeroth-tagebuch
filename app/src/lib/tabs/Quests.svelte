<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import * as A from '$lib/analyse';
  import { dateTime, gold, num } from '$lib/format';
  import { questKind } from '$lib/wow';
  import type { Character, WowEvent } from '$lib/types';

  let { c }: { c: Character } = $props();
  let mode = $state('done');
  let search = $state('');
  let sortKey = $state<'name' | 'zone' | 'kind' | 'level' | 'xp' | 'gold' | 'date'>('date');
  let asc = $state(false);

  const done = $derived(A.turnIns(c));
  const open = $derived(A.openQuests(c));
  type Row = { id: string; name: string; zone: string; kind: string; level: number; xp: number; gold: number; date: number };
  const rows = $derived.by(() => {
    const src: WowEvent[] = mode === 'done' ? done : open;
    const q = search.toLowerCase();
    const r: Row[] = src
      .map((e) => ({ id: `${e.t}-${e.q}`, name: e.n ?? t('Quest {n}', { n: e.q }), zone: e.z ?? '–', kind: questKind(e.c), level: e.lv ?? 0, xp: e.xp ?? 0, gold: e.g ?? 0, date: e.t }))
      .filter((x) => !q || x.name.toLowerCase().includes(q) || x.zone.toLowerCase().includes(q));
    const dir = asc ? 1 : -1;
    return r.sort((a, b) => {
      const va = a[sortKey], vb = b[sortKey];
      return (typeof va === 'string' ? va.localeCompare(vb as string) : (va as number) - (vb as number)) * dir;
    });
  });
  function sortBy(k: typeof sortKey) { if (sortKey === k) asc = !asc; else { sortKey = k; asc = k === 'name' || k === 'zone'; } }
  const cols = $derived<[typeof sortKey, string][]>([['name', t('Quest')], ['zone', t('Zone')], ['kind', t('Art')], ['level', t('Stufe')], ['xp', t('EP')], ['gold', t('Gold')], ['date', t('Datum')]]);
</script>

<div class="bar">
  <Segmented bind:value={mode} options={[{ id: 'done', label: t('Abgeschlossen ({n})', { n: done.length }) }, { id: 'open', label: t('Offen ({n})', { n: open.length }) }]} />
  <div class="sp"></div>
  <input type="search" placeholder={t('Quest oder Zone suchen')} bind:value={search} />
</div>

<div class="panel tbl">
  <table>
    <thead><tr>
      {#each cols as [k, label]}<th class:num={['level', 'xp', 'gold'].includes(k)} onclick={() => sortBy(k)}>{label}{sortKey === k ? (asc ? ' ▲' : ' ▼') : ''}</th>{/each}
    </tr></thead>
    <tbody>
      {#each rows as r (r.id)}
        <tr>
          <td class="name">{r.name}</td><td>{r.zone}</td><td class:dim={r.kind === t('Normal')}>{r.kind}</td>
          <td class="num">{r.level || '–'}</td><td class="num">{r.xp ? num(r.xp) : '–'}</td><td class="num">{r.gold ? gold(r.gold) : '–'}</td>
          <td class="dim">{dateTime(r.date)}</td>
        </tr>
      {:else}
        <tr><td colspan="7" class="dim empty">{t('Keine Quests gefunden')}</td></tr>
      {/each}
    </tbody>
  </table>
</div>

<style>
  .bar { display: flex; align-items: center; gap: 12px; }
  .sp { flex: 1; }
  input { width: 260px; }
  .tbl { overflow: hidden; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th { text-align: left; font-weight: 600; color: var(--gold); font-family: var(--serif); padding: 9px 10px; border-bottom: 1px solid rgba(158, 122, 61, 0.5); cursor: pointer; white-space: nowrap; }
  td { padding: 6px 10px; border-bottom: 1px solid rgba(158, 122, 61, 0.15); }
  tr:nth-child(even) td { background: rgba(255, 255, 255, 0.02); }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
  .name { font-weight: 600; }
  .empty { text-align: center; padding: 24px; }
</style>
