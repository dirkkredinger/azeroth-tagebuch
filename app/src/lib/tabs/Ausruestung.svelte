<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Box from '$lib/components/Box.svelte';
  import ItemIcon from '$lib/components/ItemIcon.svelte';
  import ExtLink from '$lib/components/ExtLink.svelte';
  import XYChart from '$lib/components/XYChart.svelte';
  import { dateTime, dayShort, num, num1 } from '$lib/format';
  import { classColor, qualityColor, qualityName, slotName, statLabel, STAT_ORDER, wowheadItem } from '$lib/wow';
  import type { Character, GearItem } from '$lib/types';
  import { itemTip } from '$lib/tooltip.svelte';

  let { c }: { c: Character } = $props();
  const left = ['1', '2', '3', '15', '5', '4', '19', '9'];
  const right = ['10', '6', '7', '8', '11', '12', '13', '14'];
  const weapons = ['16', '17'];
  const gear = $derived(c.gear ?? {});
  const empty = $derived(Object.keys(gear).length === 0);
  const totals = $derived.by(() => {
    const sum: Record<string, number> = {};
    for (const it of Object.values(gear)) for (const [k, v] of Object.entries(it.stats ?? {})) sum[k] = (sum[k] ?? 0) + v;
    return sum;
  });
  const qualities = $derived.by(() => {
    const m = new Map<number, number>();
    for (const it of Object.values(gear)) m.set(it.quality ?? 1, (m.get(it.quality ?? 1) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[0] - a[0]);
  });
  const avg = $derived.by(() => {
    const l = Object.entries(gear).filter(([s]) => s !== '4' && s !== '19').map(([, i]) => i.itemLevel).filter((x): x is number => !!x);
    return l.length ? l.reduce((a, b) => a + b, 0) / l.length : undefined;
  });
  const secondary = (it: GearItem) => ['krit', 'tempo', 'meist', 'viel'].filter((k) => it.stats?.[k]).map((k) => `${it.stats[k]} ${statLabel(k)}`).join(' · ');
  const history = $derived(c.events.filter((e) => e.e === 'ausr' && e.il).map((e) => ({ x: e.t, y: e.il! })));
  const changes = $derived(c.events.filter((e) => e.e === 'gegenstand').reverse().slice(0, 40));
</script>

{#snippet slot(s: string, trailing = false)}
  {@const it = gear[s]}
  <ExtLink href={wowheadItem(it?.itemId)} title={t('Auf Wowhead ansehen')}>
    <div class="panel slot" class:trailing use:itemTip={it ? { name: it.name, quality: it.quality, icon: it.icon, itemLevel: it.itemLevel, slot: slotName(s), stats: it.stats, hint: t('Klicken: auf Wowhead ansehen') } : null}>
      <ItemIcon icon={it?.icon} quality={it?.quality} size={40} />
      <div class="st">
        <div class="sl dim">{slotName(s)}</div>
        {#if it}
          <div class="in serif" style="color:{qualityColor(it.quality)}">{it.name ?? t('Unbekannt')}</div>
          <div class="sm">{#if it.itemLevel}<b class="gold">{t('GS {n}', { n: Math.round(it.itemLevel) })}</b>{/if} <span class="dim">{secondary(it)}</span></div>
        {:else}<div class="dim">{t('leer')}</div>{/if}
      </div>
    </div>
  </ExtLink>
{/snippet}

{#if empty}
  <div class="panel box"><h3>{t('Noch keine Ausrüstung erfasst')}</h3><p class="dim">{t('Das Addon (ab Version 1.2) speichert deine angelegten Gegenstände beim Einloggen, bei jedem Wechsel und beim Ausloggen. Einmal /reload genügt.')}</p></div>
{:else}
  <div class="doll">
    <div class="col">{#each left as s}{@render slot(s)}{/each}</div>
    <div class="panel mid">
      <div class="ring" style="--c:{classColor(c.classToken)}">
        <div class="dim sm">{t('Gegenstandsstufe')}</div>
        <div class="serif ilvl">{c.itemLevel ?? avg ? num1(c.itemLevel ?? avg!) : '–'}</div>
        <div class="sm">{c.spec ?? c.className ?? ''}</div>
      </div>
      <h4 class="serif">{t('Werte der Ausrüstung')}</h4>
      {#each STAT_ORDER as k}{#if totals[k]}<div class="stat"><span class="dim">{statLabel(k)}</span><span>{num(totals[k])}</span></div>{/if}{/each}
      <div class="qual">{#each qualities as [q, n]}<span style="color:{qualityColor(q)}">{n}× {qualityName(q)}</span>{/each}</div>
    </div>
    <div class="col">{#each right as s}{@render slot(s, true)}{/each}</div>
  </div>
  <div class="weapons">{#each weapons as s}<div class="w">{@render slot(s)}</div>{/each}</div>
{/if}

<Box title={t('Gegenstandsstufe im Verlauf')}>
  {#if history.length >= 2}<XYChart zeroY={false} xFormat={(v) => dayShort(new Date(v * 1000))} yFormat={(v) => String(Math.round(v))} lines={[{ points: history, color: '#fbcc5c', step: true }]} points={history.map((p) => ({ ...p, color: '#fbcc5c', r: 3 }))} height={190} />
  {:else}<p class="dim">{t('Noch zu wenig Einträge')}</p>{/if}
</Box>

<Box title={t('Ausrüstungswechsel')}>
  {#each changes as e}
    {@const diff = (e.il ?? 0) - (e.altil ?? 0)}
    <div class="chg">
      <ItemIcon icon={e.ic} quality={e.quality} size={30} tip={{ name: e.n, quality: e.quality, icon: e.ic, itemLevel: e.il, slot: slotName(e.slot ?? ''), lines: e.alt ? [{ text: t('ersetzt {name}', { name: e.alt }), color: '#bfb091' }] : [] }} />
      <div class="ct">
        <div><span class="dim sm">{e.slot ? slotName(e.slot) : ''}</span> <b style="color:{qualityColor(e.quality)}">{e.n}</b> {#if e.il}<span class="gold sm">{t('GS {n}', { n: Math.round(e.il) })}</span>{/if}</div>
        {#if e.alt}<div class="sm" style="color:{diff >= 0 ? 'var(--healing)' : '#f55'}">{t('ersetzt {name}', { name: e.alt })}{e.altil ? ` (${t('GS {n}', { n: Math.round(e.altil) })})` : ''}{e.altil && e.il ? (diff >= 0 ? `  ▲ +${Math.round(diff)}` : `  ▼ ${Math.round(diff)}`) : ''}</div>{/if}
      </div>
      <span class="dim sm">{dateTime(e.t)}</span>
    </div>
  {:else}<p class="dim">{t('Noch keine Wechsel erfasst.')}</p>{/each}
</Box>

<style>
  .doll { display: grid; grid-template-columns: 1fr 300px 1fr; gap: 16px; align-items: start; }
  .col { display: flex; flex-direction: column; gap: 8px; }
  .slot { display: flex; gap: 10px; align-items: center; padding: 8px; }
  .slot.trailing { flex-direction: row-reverse; text-align: right; }
  .st { min-width: 0; flex: 1; }
  .sl { font-size: 10.5px; }
  .in { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sm { font-size: 11.5px; }
  .mid { padding: 14px; }
  .ring { height: 160px; display: grid; place-content: center; text-align: center; background: radial-gradient(circle, color-mix(in srgb, var(--c) 45%, transparent), transparent 70%); }
  .ilvl { font-size: 40px; font-weight: 700; color: var(--gold); }
  h4 { margin: 8px 0; color: var(--gold); }
  .stat { display: flex; justify-content: space-between; font-size: 13px; padding: 2px 0; }
  .qual { display: flex; gap: 6px; flex-wrap: wrap; margin-top: 10px; font-size: 11px; font-weight: 700; }
  .qual span { background: rgba(0, 0, 0, 0.35); padding: 2px 6px; border-radius: 999px; }
  .weapons { display: flex; gap: 16px; justify-content: center; }
  .w { width: 340px; }
  .chg { display: flex; gap: 10px; align-items: center; padding: 4px 0; }
  .ct { flex: 1; }
</style>
