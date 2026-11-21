<script lang="ts">
  // Öffnet Links im Standardbrowser (in der App über das Opener-Plugin)
  import { openUrl } from '@tauri-apps/plugin-opener';
  import type { Snippet } from 'svelte';
  let { href, children, title = '' }: { href: string | null; children: Snippet; title?: string } = $props();
  function go(e: MouseEvent) {
    if (!href) return;
    e.preventDefault();
    if ('__TAURI_INTERNALS__' in window) openUrl(href); else window.open(href, '_blank');
  }
</script>

<a href={href ?? undefined} onclick={go} {title}>{@render children()}</a>

<style>
  a { color: inherit; text-decoration: none; cursor: pointer; }
</style>
