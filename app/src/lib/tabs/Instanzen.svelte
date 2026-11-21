<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import ItemIcon from '$lib/components/ItemIcon.svelte';
  import ExtLink from '$lib/components/ExtLink.svelte';
  import Box from '$lib/components/Box.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import { date, dateTime, duration, gold, num } from '$lib/format';
  import { qualityColor, wowheadItem } from '$lib/wow';
  import type { Character } from '$lib/types';

  let { c }: { c: Character } = $props();
  let all = $state(false);
  let kind = $state('all');
  let open = $state<string | null>(null);

  const KIND: Record<A.RunKind, { label: string; icon: string; tint: string }> = {
    dungeon: { label: 'Dungeon', icon: 'castle', tint: '#4f9dff' },
    delve: { label: 'Tiefe', icon: 'pickaxe', tint: '#f0a030' },
    raid: { label: 'Schlachtzug', icon: 'crown', tint: '#c27aff' },
    scenario: { label: 'Szenario', icon: 'scroll-text', tint: '#4fd6e8' },
    pvp: { label: 'PvP', icon: 'swords', tint: 'var(--damage)' },
    other: { label: 'Instanz', icon: 'castle', tint: 'var(--parchment-dim)' },
  };

  const runs = $derived((all ? store.characters : [c]).flatMap((x) => A.instanceRuns(x)).sort((a, b) => b.start - a.start));
  const shown = $derived(runs.filter((r) => kind === 'all' || r.kind === kind));
  const sums = $derived(A.instanceSummaries(shown));
  const tiles = $derived({
    dungeons: runs.filter((r) => r.kind === 'dungeon').length,
    delves: runs.filter((r) => r.kind === 'delve').length,
    raids: runs.filter((r) => r.kind === 'raid').length,
    done: shown.filter((r) => r.completed).length,
    bosses: shown.reduce((s, r) => s + r.bosses.filter((b) => b.ok).length, 0),
    items: shown.reduce((s, r) => s + r.loot.length, 0),
    gold: shown.reduce((s, r) => s + r.gold, 0),
  });
  const charName = (key: string) => store.characters.find((x) => x.key === key)?.name ?? key;
  const label = (r: A.InstanceRun) => (r.kind === 'delve' && r.tier ? t('tier|Stufe {n}', { n: r.tier }) : r.keyLevel ? t('Mythisch +{n}', { n: r.keyLevel }) : r.difficulty ?? '');
  const diffLabel = (d: string) => (/^T\d+$/.test(d) ? t('tier|Stufe {n}', { n: d.slice(1) }) : /^\+\d+$/.test(d) ? t('Mythisch +{n}', { n: d.slice(1) }) : d);
  const lootSorted = (s: A.InstanceSummary) => [...s.loot.values()].sort((a, b) => (b.quality ?? 0) - (a.quality ?? 0) || b.times - a.times);
  const tip = (l: A.RunLoot & { times?: number }, s?: A.InstanceSummary) => ({
    name: l.name, quality: l.quality, icon: l.icon,
    lines: [
      ...(l.from ? [{ text: t('von {name}', { name: l.from }), color: '#bfb091' }] : []),
      ...(s && l.times ? [{ text: t('in {a} von {b} Läufen erbeutet', { a: l.times, b: s.runs.length }) }] : []),
    ],
    hint: l.itemId ? t('Klicken auf den Namen: auf Wowhead ansehen') : undefined,
  });
  const recent = $derived(shown.slice(0, 12));
</script>

<div class="grid-tiles">
  <StatTile title={t('Dungeon-Läufe')} value={num(tiles.dungeons)} icon="castle" tint="#4f9dff" />
  <StatTile title={t('Tiefen')} value={num(tiles.delves)} icon="pickaxe" tint="#f0a030" />
  {#if tiles.raids}<StatTile title={t('Schlachtzüge')} value={num(tiles.raids)} icon="crown" tint="#c27aff" />{/if}
  <StatTile title={t('Abgeschlossen')} value={num(tiles.done)} icon="badge-check" tint="#4cd964" />
  <StatTile title={t('Bosse besiegt')} value={num(tiles.bosses)} icon="skull" tint="var(--damage)" />
  <StatTile title={t('Gegenstände')} value={num(tiles.items)} icon="backpack" tint="var(--parchment)" />
  <StatTile title={t('Gold')} value={gold(tiles.gold)} icon="coins" tint="#f5d742" />
</div>

<div class="bar">
  <Segmented bind:value={kind} options={[{ id: 'all', label: t('Alle') }, { id: 'dungeon', label: t('Dungeons') }, { id: 'delve', label: t('Tiefen') }, { id: 'raid', label: t('Schlachtzüge') }]} />
  <label class="tog"><input type="checkbox" bind:checked={all} /> {t('Alle Charaktere')}</label>
</div>

{#each sums as s (s.key)}
  {@const k = KIND[s.kind]}
  <div class="panel src">
    <button class="head" onclick={() => (open = open === s.key ? null : s.key)}>
      <Icon name={k.icon} size={18} color={k.tint} />
      <div class="nm">
        <div class="serif b">{s.name}</div>
        <div class="dim sm">{t(k.label)} · {[...s.difficulties].map(([d, n]) => `${diffLabel(d)} ${n}×`).join(' · ')}</div>
      </div>
      <div class="icons">{#each lootSorted(s).slice(0, 5) as l}<ItemIcon icon={l.icon} quality={l.quality} size={24} tip={tip(l, s)} />{/each}</div>
      <div class="cnt">
        <div class="b">{t('{n}× betreten', { n: s.runs.length })}</div>
        <div class="dim sm">{t('{n}× abgeschlossen', { n: s.completed })}{s.bestTier ? ' · ' + t('beste Stufe {n}', { n: s.bestTier }) : ''}{s.bestKey ? ' · ' + t('bester +{n}', { n: s.bestKey }) : ''}</div>
      </div>
    </button>
    {#if open === s.key}
      <div class="detail">
        <div class="col">
          <h4>{t('Bosse')}</h4>
          {#each [...s.bosses.values()] as b (b.name)}
            <div class="row"><Icon name="skull" size={13} color="var(--damage)" /><span class="grow">{b.name}</span>
              <b>{t('{n}× besiegt', { n: b.kills })}</b>{#if b.wipes}<span class="dim sm">{t('{n}× gescheitert', { n: b.wipes })}</span>{/if}
              {#if b.fastest}<span class="dim sm">{t('schnellster {d}', { d: duration(b.fastest) })}</span>{/if}</div>
          {:else}<div class="dim sm">{t('Noch keine Bossbegegnung erfasst.')}</div>{/each}
          <h4>{t('Beute')}</h4>
          {#each lootSorted(s) as l (l.itemId ?? l.name)}
            <div class="row"><ItemIcon icon={l.icon} quality={l.quality} size={24} tip={tip(l, s)} />
              <ExtLink href={wowheadItem(l.itemId)}><span class="iname" style="color:{qualityColor(l.quality)}">{l.name}</span></ExtLink>
              <span class="dim sm">{l.times}×{l.count > l.times ? ' · ' + t('{n} Stück', { n: l.count }) : ''}</span></div>
          {:else}<div class="dim sm">{t('Keine Beute erfasst.')}</div>{/each}
        </div>
        <div class="col">
          <h4>{t('Läufe')}</h4>
          {#each s.runs as r (r.key)}
            <div class="run">
              <span class="state" class:ok={r.completed} title={r.completed ? t('abgeschlossen') : t('nicht abgeschlossen')}><Icon name={r.completed ? 'badge-check' : 'circle-x'} size={14} /></span>
              <span class="when">{dateTime(r.start)}</span>
              <span class="lbl">{label(r)}</span>
              <span class="dim sm">{duration(r.timer ?? r.end - r.start)}{r.timed !== undefined ? ' · ' + (r.timed ? t('in der Zeit') : t('über der Zeit')) : ''}</span>
              <span class="dim sm">{tn(r.bosses.filter((b) => b.ok).length, '{n} Boss', '{n} Bosse')}{r.deaths ? ' · ' + tn(r.deaths, '{n} Tod', '{n} Tode') : ''}</span>
              {#if all}<span class="dim sm">{charName(r.char)}</span>{/if}
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>
{:else}
  <div class="panel box"><h3>{t('Noch keine Instanzen erfasst')}</h3>
    <p class="dim">{t('Ab Addon-Version 1.4 schreibt das Tagebuch mit, wann du einen Dungeon, eine Tiefe oder einen Schlachtzug betrittst, welche Bosse fallen, ob der Lauf abgeschlossen wurde (bei Tiefen mit Stufe, bei Mythisch+ mit Schlüsselstein) und was du dabei erbeutest.')}</p></div>
{/each}

{#if recent.length}
  <Box title={t('Letzte Läufe')}>
    {#each recent as r (r.key)}
      {@const k = KIND[r.kind]}
      <div class="run">
        <Icon name={k.icon} size={14} color={k.tint} />
        <span class="when">{date(r.start)}</span>
        <span class="serif b grow">{r.name}</span>
        <span class="lbl">{label(r)}</span>
        <span class="dim sm">{tn(r.bosses.filter((b) => b.ok).length, '{n} Boss', '{n} Bosse')} · {tn(r.loot.length, '{n} Gegenstand', '{n} Gegenstände')}</span>
        <span class="state" class:ok={r.completed}><Icon name={r.completed ? 'badge-check' : 'circle-x'} size={14} /></span>
      </div>
    {/each}
  </Box>
{/if}

<style>
  .bar { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .tog { display: flex; gap: 6px; align-items: center; font-size: 13px; }
  .src { padding: 10px; }
  .head { display: flex; gap: 12px; align-items: center; width: 100%; background: none; border: 0; cursor: pointer; text-align: left; }
  .nm { flex: 1; min-width: 0; }
  .b { font-weight: 700; }
  .sm { font-size: 12px; }
  .grow { flex: 1; min-width: 0; white-space: normal !important; }
  .icons { display: flex; gap: 2px; }
  .cnt { width: 230px; text-align: right; }
  .detail { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 18px; padding: 10px 4px 2px 30px; }
  h4 { margin: 6px 0 6px; font-family: var(--serif); color: var(--gold); font-size: 13px; }
  .col { display: flex; flex-direction: column; gap: 5px; min-width: 0; }
  .row { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
  .row > *, .run > * { white-space: nowrap; }
  .iname { display: inline-block; max-width: 230px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .run { display: flex; gap: 4px 10px; align-items: center; padding: 3px 0; flex-wrap: wrap; }
  .when { min-width: 110px; font-variant-numeric: tabular-nums; font-size: 12.5px; }
  .lbl { min-width: 90px; font-size: 12.5px; font-weight: 700; color: var(--gold); }
  .state { color: var(--parchment-dim); display: inline-flex; }
  .state.ok { color: #4cd964; }
  @media (max-width: 800px) { .detail { padding-left: 0; } .cnt { width: auto; } }
</style>
