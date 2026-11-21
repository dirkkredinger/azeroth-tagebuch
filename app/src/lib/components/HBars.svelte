<script lang="ts">
  // Waagerechte Balken mit Beschriftung
  let { rows }: { rows: { label: string; value: number; text: string; color: string }[] } = $props();
  const max = $derived(Math.max(1, ...rows.map((r) => r.value)));
</script>

<div class="bars">
  {#each rows as r}
    <div class="lbl">{r.label}</div>
    <div class="track">
      <div class="bar" style="width:{(r.value / max) * 100}%; background:linear-gradient(180deg, color-mix(in srgb, {r.color} 100%, white 15%), {r.color})"></div>
      <span class="txt">{r.text}</span>
    </div>
  {/each}
</div>

<style>
  .bars { display: grid; grid-template-columns: auto 1fr; gap: 8px 12px; align-items: center; }
  .lbl { font-size: 12.5px; color: var(--parchment); white-space: nowrap; }
  .track { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .bar { height: 16px; border-radius: 3px; min-width: 2px; }
  .txt { font-size: 11.5px; color: var(--parchment-dim); white-space: nowrap; }
</style>
