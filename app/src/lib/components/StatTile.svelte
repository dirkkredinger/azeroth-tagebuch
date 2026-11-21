<script lang="ts">
  import Icon from './Icon.svelte';
  let { title, value, icon, tint = 'var(--gold)' }: { title: string; value: string; icon: string; tint?: string } = $props();
</script>

<div class="panel tile">
  <div class="label"><Icon name={icon} size={13} color={tint} /> {title}</div>
  <div class="value serif">{value}</div>
</div>

<style>
  .tile { padding: 12px 14px; min-width: 0; }
  .label { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--parchment-dim); }
  .value { margin-top: 6px; font-size: 22px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-variant-numeric: tabular-nums; }
</style>
