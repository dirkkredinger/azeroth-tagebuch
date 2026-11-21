<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  // Schwebender Item-Tooltip (eigene Gestaltung im Stil der Spiel-Tooltips)
  import { tipState } from '$lib/tooltip.svelte';
  import { qualityColor, qualityName, statLabel, STAT_ORDER } from '$lib/wow';
  import { num } from '$lib/format';
  import ItemIcon from './ItemIcon.svelte';

  let box = $state<HTMLDivElement | null>(null);
  let w = $state(0), h = $state(0);
  const tip = $derived(tipState.tip);
  // rechts unten neben dem Mauszeiger, am Fensterrand umklappen
  const left = $derived(tipState.x + 18 + w > window.innerWidth ? tipState.x - w - 14 : tipState.x + 18);
  const top = $derived(Math.max(6, tipState.y + 14 + h > window.innerHeight ? tipState.y - h - 10 : tipState.y + 14));
  const primary = ['str', 'bew', 'int', 'aus'];
  const secondary = ['krit', 'tempo', 'meist', 'viel'];
</script>

{#if tip}
  <div class="tt" bind:this={box} bind:clientWidth={w} bind:clientHeight={h} style="left:{left}px; top:{top}px">
    <div class="headrow">
      {#if tip.icon}<ItemIcon icon={tip.icon} quality={tip.quality} size={34} />{/if}
      <div>
        <div class="name" style="color:{qualityColor(tip.quality)}">{tip.name}</div>
        {#if tip.quality !== undefined}<div class="q">{qualityName(tip.quality)}</div>{/if}
      </div>
    </div>
    {#if tip.itemLevel}<div class="ilvl">{t('Gegenstandsstufe {n}', { n: Math.round(tip.itemLevel) })}</div>{/if}
    {#if tip.slot}<div class="slot">{tip.slot}</div>{/if}
    {#if tip.stats}
      {#each STAT_ORDER.filter((k) => primary.includes(k) && tip.stats?.[k]) as k}<div class="white">+{num(tip.stats[k])} {statLabel(k)}</div>{/each}
      {#each STAT_ORDER.filter((k) => secondary.includes(k) && tip.stats?.[k]) as k}<div class="green">+{num(tip.stats[k])} {statLabel(k)}</div>{/each}
    {/if}
    {#if tip.count && tip.count > 1}<div class="white">{t('Anzahl: {n}', { n: num(tip.count) })}</div>{/if}
    {#each tip.lines ?? [] as l}<div style="color:{l.color ?? '#ffd100'}">{l.text}</div>{/each}
    {#if tip.hint}<div class="hint">{tip.hint}</div>{/if}
  </div>
{/if}

<style>
  .tt {
    position: fixed; z-index: 1000; pointer-events: none;
    max-width: 320px; min-width: 180px; padding: 8px 10px;
    background: linear-gradient(180deg, rgba(10, 12, 28, 0.96), rgba(4, 5, 14, 0.96));
    border: 1px solid rgba(200, 200, 215, 0.55);
    border-radius: 5px;
    box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.9), 0 6px 18px rgba(0, 0, 0, 0.7);
    font-size: 12.5px; line-height: 1.45; color: #fff;
  }
  .headrow { display: flex; gap: 8px; align-items: center; margin-bottom: 2px; }
  .name { font-size: 14px; font-weight: 600; }
  .q { font-size: 11px; color: #9d9d9d; }
  .ilvl { color: #ffd100; }
  .slot, .white { color: #fff; }
  .green { color: #1eff00; }
  .hint { margin-top: 4px; color: #8f8f8f; font-size: 11.5px; }
</style>
