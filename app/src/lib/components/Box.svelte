<script lang="ts">
  import type { Snippet } from 'svelte';
  let { title = '', children, right }: { title?: string; children: Snippet; right?: Snippet } = $props();
</script>

<div class="panel box">
  {#if title || right}<div class="head"><h3>{title}</h3>{#if right}{@render right()}{/if}</div>{/if}
  {@render children()}
</div>

<style>
  .head { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
  .head h3 { margin: 0; flex: 1; font-family: var(--serif); font-size: 15px; font-weight: 600; color: var(--gold); }
</style>
