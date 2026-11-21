<script lang="ts">
  import EventRow from '$lib/components/EventRow.svelte';
  import * as A from '$lib/analyse';
  import { i18n, locale, t } from '$lib/i18n.svelte';
  import type { Character, WowEvent } from '$lib/types';

  let { c }: { c: Character } = $props();
  const names = $derived(A.questNames(c));
  const fmt = $derived((i18n.lang, new Intl.DateTimeFormat(locale(), { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })));

  // Zonenwechsel nur zeigen, wenn sich der Ort wirklich geändert hat; neueste Tage zuerst
  const days = $derived.by(() => {
    let last = '';
    const kept: WowEvent[] = [];
    const instStarts = new Set(c.events.filter((e) => e.e === 'inst_an').map((e) => e.t));
    for (const e of c.events) {
      if (e.e === 'zone' && e.inst && instStarts.has(e.t)) continue;   // doppelt mit „Instanz betreten“
      if (e.e === 'zone') {
        const place = [e.z, e.sz, e.inst].join('|');
        if (place === last) continue;
        last = place;
      }
      kept.push(e);
    }
    const map = new Map<string, { label: string; t: number; events: WowEvent[] }>();
    for (const e of kept) {
      const d = new Date(e.t * 1000);
      const key = d.toDateString();
      if (!map.has(key)) map.set(key, { label: fmt.format(d), t: e.t, events: [] });
      map.get(key)!.events.push(e);
    }
    return [...map.values()].sort((a, b) => b.t - a.t).map((d) => ({ ...d, events: d.events.reverse() }));
  });
  let limit = $state(10);
</script>

{#each days.slice(0, limit) as d (d.label)}
  <div class="panel box">
    <h3>{d.label}</h3>
    {#each d.events as e (e.t + e.e + (e.q ?? '') + (e.src ?? '') + (e.slot ?? '') + (e.txt ?? ''))}<EventRow event={e} {names} />{/each}
  </div>
{:else}
  <p class="dim">{t('Noch keine Einträge.')}</p>
{/each}
{#if days.length > limit}<button class="btn more" onclick={() => (limit += 10)}>{t('Ältere Tage anzeigen ({n})', { n: days.length - limit })}</button>{/if}

<style>
  .more { align-self: center; }
</style>
