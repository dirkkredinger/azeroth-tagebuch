<script lang="ts">
  let { text }: { text: string } = $props();
</script>

<div class="oh">
  <h1 class="serif">{text}</h1>
  <div class="line"><span>◆</span></div>
</div>

<style>
  .oh { display: flex; align-items: center; gap: 12px; }
  h1 { margin: 0; font-size: 28px; color: var(--gold); text-shadow: 0 1px 2px rgba(0, 0, 0, 0.8); white-space: nowrap; }
  .line { flex: 1; height: 1px; background: linear-gradient(90deg, rgba(251, 204, 92, 0.7), transparent); position: relative; }
  .line span { position: absolute; left: -4px; top: -8px; font-size: 9px; color: var(--gold); }
</style>
