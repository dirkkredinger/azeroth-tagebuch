<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  // Punkte und Linien in einem Koordinatensystem (Streudiagramm, Verlauf, Stufenlinie, Trend)
  export type Pt = { x: number; y: number; color?: string; r?: number; title?: string };
  export type Line = { points: { x: number; y: number }[]; color: string; dash?: boolean; step?: boolean; width?: number };

  let {
    points = [], lines = [], xFormat = (v: number) => String(Math.round(v)), yFormat = (v: number) => String(Math.round(v)),
    xLabel = '', zeroY = true, height = 220,
  }: {
    points?: Pt[]; lines?: Line[]; xFormat?: (v: number) => string; yFormat?: (v: number) => string;
    xLabel?: string; zeroY?: boolean; height?: number;
  } = $props();

  const W = 560, pad = { l: 8, r: 52, t: 10, b: 26 };
  const H = $derived(height);
  const allX = $derived([...points.map((p) => p.x), ...lines.flatMap((l) => l.points.map((p) => p.x))]);
  const allY = $derived([...points.map((p) => p.y), ...lines.flatMap((l) => l.points.map((p) => p.y))]);
  const xr = $derived.by(() => {
    let a = Math.min(...allX), b = Math.max(...allX);
    if (!isFinite(a)) { a = 0; b = 1; }
    if (a === b) { a -= 1; b += 1; }
    const p = (b - a) * 0.04;
    return [a - p, b + p];
  });
  const yr = $derived.by(() => {
    let a = zeroY ? 0 : Math.min(...allY), b = Math.max(...allY);
    if (!isFinite(a)) a = 0;
    if (!isFinite(b) || b === a) b = a + 1;
    const p = (b - a) * (zeroY ? 0.08 : 0.12);
    return [zeroY ? a : a - p, b + p];
  });
  const sx = (v: number) => pad.l + ((v - xr[0]) / (xr[1] - xr[0])) * (W - pad.l - pad.r);
  const sy = (v: number) => H - pad.b - ((v - yr[0]) / (yr[1] - yr[0])) * (H - pad.t - pad.b);
  const yTicks = $derived([0, 0.25, 0.5, 0.75, 1].map((f) => yr[0] + (yr[1] - yr[0]) * f));
  const xTicks = $derived([0, 0.25, 0.5, 0.75, 1].map((f) => xr[0] + (xr[1] - xr[0]) * f));

  function path(l: Line): string {
    const p = [...l.points].sort((a, b) => a.x - b.x);
    return p.map((q, i) => {
      if (i === 0) return `M${sx(q.x)},${sy(q.y)}`;
      return l.step ? `H${sx(q.x)}V${sy(q.y)}` : `L${sx(q.x)},${sy(q.y)}`;
    }).join('');
  }
</script>

{#if allX.length}
  <svg viewBox="0 0 {W} {H}" class="chart">
    {#each yTicks as tk}
      <line x1={pad.l} x2={W - pad.r} y1={sy(tk)} y2={sy(tk)} class="grid" />
      <text x={W - pad.r + 6} y={sy(tk) + 3} class="axis">{yFormat(tk)}</text>
    {/each}
    {#each xTicks as tk}
      <line x1={sx(tk)} x2={sx(tk)} y1={pad.t} y2={H - pad.b} class="grid v" />
      <text x={sx(tk)} y={H - 8} class="axis" text-anchor="middle">{xFormat(tk)}</text>
    {/each}
    {#each lines as l}
      <path d={path(l)} fill="none" stroke={l.color} stroke-width={l.width ?? 2} stroke-dasharray={l.dash ? '5 3' : undefined} stroke-linejoin="round" />
    {/each}
    {#each points as p}
      <circle cx={sx(p.x)} cy={sy(p.y)} r={p.r ?? 3.5} fill={p.color ?? 'var(--gold)'}>{#if p.title}<title>{p.title}</title>{/if}</circle>
    {/each}
  </svg>
  {#if xLabel}<div class="xl">{xLabel}</div>{/if}
{:else}
  <div class="none">{t('Noch keine Daten')}</div>
{/if}

<style>
  .chart { width: 100%; height: auto; display: block; }
  .grid { stroke: rgba(240, 224, 189, 0.1); }
  .grid.v { stroke-dasharray: 2 3; }
  .axis { fill: var(--parchment-dim); font-size: 10px; }
  .xl { font-size: 11px; color: var(--parchment-dim); margin-top: 2px; }
  .none { height: 160px; display: grid; place-items: center; color: var(--parchment-dim); }
</style>
