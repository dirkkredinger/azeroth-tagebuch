<script lang="ts">
  // Umschalter mit mehreren Optionen
  let { options, value = $bindable() }: { options: { id: string; label: string }[]; value: string } = $props();
</script>

<div class="seg">
  {#each options as o}<button class:on={value === o.id} onclick={() => (value = o.id)}>{o.label}</button>{/each}
</div>

<style>
  .seg { display: inline-flex; border: 1px solid rgba(158, 122, 61, 0.55); border-radius: 6px; overflow: hidden; }
  button { padding: 5px 12px; border: 0; background: rgba(43, 31, 20, 0.85); color: var(--parchment-dim); cursor: pointer; font-size: 12.5px; }
  button + button { border-left: 1px solid rgba(158, 122, 61, 0.4); }
  button.on { background: linear-gradient(180deg, var(--gold), var(--gold-deep)); color: var(--ink); font-weight: 700; }
</style>
