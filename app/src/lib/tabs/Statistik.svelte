<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Box from '$lib/components/Box.svelte';
  import Columns from '$lib/components/Columns.svelte';
  import HBars from '$lib/components/HBars.svelte';
  import Donut from '$lib/components/Donut.svelte';
  import XYChart from '$lib/components/XYChart.svelte';
  import * as A from '$lib/analyse';
  import { dayShort, duration } from '$lib/format';
  import { classColor, questKind } from '$lib/wow';
  import type { Character } from '$lib/types';

  let { c }: { c: Character } = $props();
  const dayKey = (t: number) => { const d = new Date(t * 1000); d.setHours(0, 0, 0, 0); return d.getTime() / 1000; };
  const perDay = (filter: (e: any) => boolean, val: (e: any) => number) => {
    const m = new Map<number, number>();
    for (const e of c.events) if (filter(e)) m.set(dayKey(e.t), (m.get(dayKey(e.t)) ?? 0) + val(e));
    return [...m.entries()].sort((a, b) => a[0] - b[0]);
  };
  const quests = $derived(perDay((e) => e.e === 'quest_ab', () => 1).map(([d, v]) => ({ label: dayShort(new Date(d * 1000)), value: v, color: '#f5d742' })));
  const play = $derived(perDay((e) => e.e === 'logout', (e) => (e.dauer ?? 0) / 60).map(([d, v]) => ({ label: dayShort(new Date(d * 1000)), value: v, color: '#4f9dff' })));
  const zones = $derived.by(() => {
    const m = new Map<string, number>();
    for (const e of A.turnIns(c)) m.set(e.z ?? t('Unbekannt'), (m.get(e.z ?? t('Unbekannt')) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10).map(([label, value]) => ({ label, value, text: String(value), color: '#3cc8d8' }));
  });
  const kinds = $derived.by(() => {
    const m = new Map<string, number>();
    for (const e of A.turnIns(c)) m.set(questKind(e.c), (m.get(questKind(e.c)) ?? 0) + 1);
    const colors = ['#4f9dff', '#4cd964', '#f0a030', '#c27aff', '#ff6b6b', '#3cc8d8'];
    return [...m.entries()].sort((a, b) => b[1] - a[1]).map(([label, value], i) => ({ label, value, color: colors[i % colors.length] }));
  });
  const levels = $derived(c.events.filter((e) => e.e === 'level' || (e.e === 'login' && e.lv)).map((e) => ({ x: e.t, y: e.lv ?? 0 })));
  const fmtDate = (v: number) => dayShort(new Date(v * 1000));
</script>

<div class="grid-2">
  <Box title={t('Quests pro Tag')}><Columns rows={quests} /></Box>
  <Box title={t('Spielzeit pro Tag')}><Columns rows={play} format={(v) => duration(v * 60)} /></Box>
  <Box title={t('Top-Zonen nach Quests')}>{#if zones.length}<HBars rows={zones} />{:else}<p class="dim">{t('Noch keine Daten')}</p>{/if}</Box>
  <Box title={t('Arten der Quests')}><Donut rows={kinds} /></Box>
  <Box title={t('Stufenverlauf')}>
    {#if levels.length >= 2}
      <XYChart zeroY={false} xFormat={fmtDate} lines={[{ points: levels, color: classColor(c.classToken), step: true }]} points={levels.map((p) => ({ ...p, color: classColor(c.classToken), r: 3 }))} />
    {:else}<p class="dim">{t('Noch zu wenig Stufendaten')}</p>{/if}
  </Box>
</div>
