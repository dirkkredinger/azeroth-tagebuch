<script lang="ts">
  import Icon from './Icon.svelte';
  import type { WowEvent } from '$lib/types';
  import { eventDetail, eventStyle, eventTitle } from '$lib/wow';
  import { dateTime } from '$lib/format';
  let { event, names = new Map() }: { event: WowEvent; names?: Map<number, string> } = $props();
  const st = $derived(eventStyle(event));
  const detail = $derived(eventDetail(event));
</script>

<div class="row">
  <span class="ic"><Icon name={st.icon} size={15} color={st.color} /></span>
  <div class="txt">
    <div class:italic={event.e === 'notiz'}>{eventTitle(event, names)}</div>
    {#if detail}<div class="detail">{detail}</div>{/if}
  </div>
  <span class="time">{dateTime(event.t)}</span>
</div>

<style>
  .row { display: flex; align-items: baseline; gap: 10px; padding: 3px 0; }
  .ic { width: 18px; flex: none; transform: translateY(2px); }
  .txt { flex: 1; min-width: 0; }
  .italic { font-style: italic; }
  .detail { font-size: 12px; color: var(--parchment-dim); }
  .time { font-size: 12px; color: rgba(191, 176, 145, 0.7); font-variant-numeric: tabular-nums; white-space: nowrap; }
</style>
