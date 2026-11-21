<script lang="ts">
  import { classColor } from '$lib/wow';
  let { name, token, size = 30, round = true }: { name: string; token?: string; size?: number; round?: boolean } = $props();
</script>

<div class="av" class:round style="--c:{classColor(token)}; width:{size}px; height:{size}px; font-size:{size * 0.48}px">
  {name.slice(0, 1)}
</div>

<style>
  .av {
    display: grid; place-items: center; flex: none;
    background: linear-gradient(160deg, color-mix(in srgb, var(--c) 100%, white 20%), color-mix(in srgb, var(--c) 80%, black 20%));
    border: 1.5px solid rgba(251, 204, 92, 0.8);
    border-radius: 8px;
    color: rgba(0, 0, 0, 0.72);
    font-family: var(--serif); font-weight: 700;
    box-shadow: 0 0 10px color-mix(in srgb, var(--c) 35%, transparent);
  }
  .round { border-radius: 50%; }
</style>
