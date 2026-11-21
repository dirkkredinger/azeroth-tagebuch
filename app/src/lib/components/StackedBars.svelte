<script lang="ts">
  // Gestapelte Säulen (selbst gezeichnet in SVG)
  import { dayShort } from '$lib/format';
  type Series = { key: string; label: string; color: string };
  let { days, series, unit = 'Min.' }: { days: { day: number; minutes: Record<string, number> }[]; series: Series[]; unit?: string } = $props();
  const W = 520, H = 200, pad = { l: 34, r: 8, t: 10, b: 24 };
  const max = $derived(Math.max(10, ...days.map((d) => Object.values(d.minutes).reduce((a, b) => a + b, 0))));
  const nice = $derived(Math.ceil(max / 10) * 10);
  const bw = $derived((W - pad.l - pad.r) / days.length);
  const y = (v: number) => H - pad.b - (v / nice) * (H - pad.t - pad.b);
</script>

<svg viewBox="0 0 {W} {H}" class="chart">
  {#each [0, 0.25, 0.5, 0.75, 1] as f}
    <line x1={pad.l} x2={W - pad.r} y1={y(nice * f)} y2={y(nice * f)} class="grid" />
    <text x={pad.l - 6} y={y(nice * f) + 3} class="axis" text-anchor="end">{Math.round(nice * f)}</text>
  {/each}
  {#each days as d, i}
    {@const x = pad.l + i * bw + bw * 0.15}
    {#each series as s, si}
      {@const below = series.slice(0, si).reduce((a, x2) => a + (d.minutes[x2.key] ?? 0), 0)}
      {@const v = d.minutes[s.key] ?? 0}
      {#if v > 0}
        <rect x={x} width={bw * 0.7} y={y(below + v)} height={y(below) - y(below + v)} fill={s.color} rx="2">
          <title>{s.label}: {Math.round(v)} {unit}</title>
        </rect>
      {/if}
    {/each}
    {#if i % 2 === 0}<text x={x + bw * 0.35} y={H - 6} class="axis" text-anchor="middle">{dayShort(new Date(d.day * 1000))}</text>{/if}
  {/each}
</svg>
<div class="legend">
  {#each series as s}<span><i style="background:{s.color}"></i>{s.label}</span>{/each}
</div>

<style>
  .chart { width: 100%; height: auto; display: block; }
  .grid { stroke: rgba(240, 224, 189, 0.1); }
  .axis { fill: var(--parchment-dim); font-size: 10px; }
  .legend { display: flex; flex-wrap: wrap; gap: 12px; font-size: 11.5px; color: var(--parchment-dim); margin-top: 4px; }
  .legend i { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 5px; }
</style>
