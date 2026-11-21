<script lang="ts">
  // Senkrechte Säulen mit Beschriftung darunter und Wert darüber
  let { rows, height = 220, format = (v: number) => String(Math.round(v)), xLabel = '' }:
    { rows: { label: string; value: number; color: string; title?: string }[]; height?: number; format?: (v: number) => string; xLabel?: string } = $props();
  const W = 560, pad = { l: 8, r: 8, t: 18, b: 24 };
  const max = $derived(Math.max(1, ...rows.map((r) => r.value)));
  const bw = $derived((W - pad.l - pad.r) / Math.max(rows.length, 1));
  const y = (v: number) => height - pad.b - (v / max) * (height - pad.t - pad.b);
  const every = $derived(Math.max(1, Math.ceil(rows.length / 10)));
</script>

{#if rows.length}
  <svg viewBox="0 0 {W} {height}" class="chart">
    <line x1={pad.l} x2={W - pad.r} y1={height - pad.b} y2={height - pad.b} class="base" />
    {#each rows as r, i}
      {@const x = pad.l + i * bw + bw * 0.14}
      <rect {x} width={bw * 0.72} y={y(r.value)} height={Math.max(0, height - pad.b - y(r.value))} fill={r.color} rx="3"><title>{r.title ?? `${r.label}: ${format(r.value)}`}</title></rect>
      {#if rows.length <= 14}<text x={x + bw * 0.36} y={y(r.value) - 5} class="val" text-anchor="middle">{format(r.value)}</text>{/if}
      {#if i % every === 0}<text x={x + bw * 0.36} y={height - 7} class="axis" text-anchor="middle">{r.label}</text>{/if}
    {/each}
  </svg>
  {#if xLabel}<div class="xl">{xLabel}</div>{/if}
{:else}
  <div class="none">Noch keine Daten</div>
{/if}

<style>
  .chart { width: 100%; height: auto; display: block; }
  .base { stroke: rgba(240, 224, 189, 0.2); }
  .axis { fill: var(--parchment-dim); font-size: 10px; }
  .val { fill: var(--parchment-dim); font-size: 10px; }
  .xl { font-size: 11px; color: var(--parchment-dim); }
  .none { height: 160px; display: grid; place-items: center; color: var(--parchment-dim); }
</style>
