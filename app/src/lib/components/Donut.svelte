<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  // Ringdiagramm mit Legende
  let { rows }: { rows: { label: string; value: number; color: string }[] } = $props();
  const total = $derived(rows.reduce((s, r) => s + r.value, 0));
  const R = 70, r = 40, C = 90;
  const arcs = $derived.by(() => {
    let a = -Math.PI / 2;
    return rows.map((row) => {
      const span = total ? (row.value / total) * Math.PI * 2 : 0;
      const a0 = a + 0.02, a1 = a + span - 0.02;
      a += span;
      const p = (ang: number, rad: number) => `${C + rad * Math.cos(ang)},${C + rad * Math.sin(ang)}`;
      const large = a1 - a0 > Math.PI ? 1 : 0;
      return { ...row, d: span >= Math.PI * 2 - 0.01
        ? `M${C - R},${C}a${R},${R} 0 1,0 ${2 * R},0a${R},${R} 0 1,0 -${2 * R},0M${C - r},${C}a${r},${r} 0 1,1 ${2 * r},0a${r},${r} 0 1,1 -${2 * r},0`
        : `M${p(a0, R)}A${R},${R} 0 ${large} 1 ${p(a1, R)}L${p(a1, r)}A${r},${r} 0 ${large} 0 ${p(a0, r)}Z` };
    });
  });
</script>

{#if total > 0}
  <div class="wrap">
    <svg viewBox="0 0 180 180" class="ring">
      {#each arcs as a}<path d={a.d} fill={a.color} fill-rule="evenodd"><title>{a.label}: {a.value}</title></path>{/each}
    </svg>
    <div class="legend">
      {#each rows as row}<div><i style="background:{row.color}"></i>{row.label} <span class="dim">{row.value}</span></div>{/each}
    </div>
  </div>
{:else}
  <div class="none">{t('Noch keine Daten')}</div>
{/if}

<style>
  .wrap { display: flex; align-items: center; gap: 20px; justify-content: center; min-height: 200px; }
  .ring { width: 180px; height: 180px; }
  .legend { font-size: 12.5px; display: flex; flex-direction: column; gap: 6px; }
  .legend i { display: inline-block; width: 9px; height: 9px; border-radius: 50%; margin-right: 6px; }
  .none { height: 160px; display: grid; place-items: center; color: var(--parchment-dim); }
</style>
