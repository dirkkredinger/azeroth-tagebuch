<script lang="ts">
  // Gegenstandssymbol aus der WoW-Installation mit Rahmen in Qualitätsfarbe
  import Icon from './Icon.svelte';
  import { symbolBild } from '$lib/bild';
  import { qualityColor } from '$lib/wow';
  import { itemTip, type ItemTip } from '$lib/tooltip.svelte';
  let { icon, quality, size = 36, count = 0, title = '', tip = null }: { icon?: number; quality?: number; size?: number; count?: number; title?: string; tip?: ItemTip | null } = $props();
  let failed = $state(false);
  const src = $derived(failed ? null : symbolBild(icon));
</script>

<div class="ii" style="width:{size}px;height:{size}px;border-color:{qualityColor(quality)}" title={tip ? undefined : title || undefined} use:itemTip={tip}>
  {#if src}<img {src} alt="" onerror={() => (failed = true)} />{:else}<Icon name="backpack" size={size * 0.5} color="var(--gold-dim)" />{/if}
  {#if count > 1}<span class="cnt">{count >= 1000 ? `${Math.floor(count / 1000)}k` : count}</span>{/if}
</div>

<style>
  .ii { position: relative; flex: none; display: grid; place-items: center; border: 1.5px solid; border-radius: 5px; background: rgba(0, 0, 0, 0.6); overflow: hidden; }
  img { width: calc(100% - 4px); height: calc(100% - 4px); border-radius: 3px; }
  .cnt { position: absolute; right: 3px; bottom: 1px; font-size: 11px; font-weight: 800; color: #fff; text-shadow: 0 0 2px #000, 0 0 2px #000, 0 0 2px #000; font-variant-numeric: tabular-nums; }
</style>
