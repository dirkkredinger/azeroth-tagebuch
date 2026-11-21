<script lang="ts">
  // Schwebender Item-Tooltip (eigene Gestaltung im Stil der Spiel-Tooltips)
  import { tipState } from '$lib/tooltip.svelte';
  import { qualityColor, qualityName, STAT_NAMES, STAT_ORDER } from '$lib/wow';
  import { num } from '$lib/format';
  import ItemIcon from './ItemIcon.svelte';

  let box = $state<HTMLDivElement | null>(null);
  let w = $state(0), h = $state(0);
  const t = $derived(tipState.tip);
  // rechts unten neben dem Mauszeiger, am Fensterrand umklappen
  const left = $derived(tipState.x + 18 + w > window.innerWidth ? tipState.x - w - 14 : tipState.x + 18);
  const top = $derived(Math.max(6, tipState.y + 14 + h > window.innerHeight ? tipState.y - h - 10 : tipState.y + 14));
  const primary = ['str', 'bew', 'int', 'aus'];
  const secondary = ['krit', 'tempo', 'meist', 'viel'];
</script>

{#if t}
  <div class="tt" bind:this={box} bind:clientWidth={w} bind:clientHeight={h} style="left:{left}px; top:{top}px">
    <div class="headrow">
      {#if t.icon}<ItemIcon icon={t.icon} quality={t.quality} size={34} />{/if}
      <div>
        <div class="name" style="color:{qualityColor(t.quality)}">{t.name}</div>
        {#if t.quality !== undefined}<div class="q">{qualityName(t.quality)}</div>{/if}
      </div>
    </div>
    {#if t.itemLevel}<div class="ilvl">Gegenstandsstufe {Math.round(t.itemLevel)}</div>{/if}
    {#if t.slot}<div class="slot">{t.slot}</div>{/if}
    {#if t.stats}
      {#each STAT_ORDER.filter((k) => primary.includes(k) && t.stats?.[k]) as k}<div class="white">+{num(t.stats[k])} {STAT_NAMES[k]}</div>{/each}
      {#each STAT_ORDER.filter((k) => secondary.includes(k) && t.stats?.[k]) as k}<div class="green">+{num(t.stats[k])} {STAT_NAMES[k]}</div>{/each}
    {/if}
    {#if t.count && t.count > 1}<div class="white">Anzahl: {num(t.count)}</div>{/if}
    {#each t.lines ?? [] as l}<div style="color:{l.color ?? '#ffd100'}">{l.text}</div>{/each}
    {#if t.hint}<div class="hint">{t.hint}</div>{/if}
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
