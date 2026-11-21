<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Box from '$lib/components/Box.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import ExtLink from '$lib/components/ExtLink.svelte';
  import EventRow from '$lib/components/EventRow.svelte';
  import { num1 } from '$lib/format';
  import { CLASSES, SPECS, classColor, guideLinks, roleName, statName } from '$lib/wow';
  import type { Character } from '$lib/types';

  let { c }: { c: Character } = $props();
  const info = $derived(CLASSES[c.classToken ?? '']);
  const role = $derived(c.role ?? (c.specId ? SPECS[c.specId]?.role : undefined));
  const links = $derived(guideLinks(c.specId, role, c.classToken, c.talentCode));
  const history = $derived(c.events.filter((e) => e.e === 'talente' || e.e === 'ausr').sort((a, b) => b.t - a.t).slice(0, 30));
  let copied = $state(false);
  async function copy() { if (c.talentCode) { await navigator.clipboard.writeText(c.talentCode); copied = true; } }
</script>

<div class="two">
  <div class="panel box">
    <h2 class="serif" style="color:{classColor(c.classToken)}">{c.className ?? t('Klasse')}</h2>
    {#if info}<p>{t(info.text)}</p>
      <div class="line"><span class="dim">{t('Rüstung')}</span><b>{t(info.armor)}</b></div>
      <div class="line"><span class="dim">{t('Ressource')}</span><b>{t(info.resource)}</b></div>{/if}
    {#if c.itemLevel}<div class="line"><span class="dim">{t('Gegenstandsstufe')}</span><b>{num1(c.itemLevel)}</b></div>{/if}
  </div>
  <div class="panel box">
    <div class="sh"><h2 class="serif gold">{c.spec ?? t('Spezialisierung')}</h2><span class="role">{roleName(role)}</span></div>
    <p class:dim={!c.specDesc}>{c.specDesc ?? t('Die Beschreibung erscheint, sobald das Addon (ab Version 1.1) die Spezialisierung mitgeschrieben hat.')}</p>
    {#if statName(c.primaryStat)}<div class="line"><span class="dim">{t('Primärwert')}</span><b>{statName(c.primaryStat)}</b></div>{/if}
  </div>
</div>

<Box title={t('Guides & Talent-Builds (Wowhead)')}>
  {#if links.length}
    <div class="links">
      {#each links as l}<ExtLink href={l.url}><div class="lk"><Icon name={l.icon} size={15} /> {l.title} <span class="sp"></span>↗</div></ExtLink>{/each}
    </div>
    <p class="dim sm">{t('Die empfohlenen Builds stammen von Wowhead und öffnen sich im Browser. Den Build übernimmst du im Spiel über „Laden/Teilen → Importieren“.')}</p>
  {:else}<p class="dim">{t('Noch keine Spezialisierung bekannt.')}</p>{/if}
</Box>

<Box title={t('Dein Talent-Build')}>
  {#if c.talentCode}
    <div class="code"><code>{c.talentCode}</code><button class="btn" onclick={copy}>{copied ? t('Kopiert') : t('Code kopieren')}</button></div>
  {:else}<p class="dim">{t('Noch kein Talentcode – er wird vom Addon beim nächsten Einloggen gespeichert.')}</p>{/if}
</Box>

<Box title={t('Verlauf: Talente & Ausrüstung')}>
  {#each history as e (e.t + e.e)}<EventRow event={e} />{:else}<p class="dim">{t('Noch keine Einträge.')}</p>{/each}
</Box>

<style>
  .two { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
  h2 { margin: 0 0 6px; font-size: 22px; }
  .line { display: flex; justify-content: space-between; font-size: 13px; padding: 3px 0; border-top: 1px solid rgba(158, 122, 61, 0.2); }
  .sh { display: flex; align-items: center; justify-content: space-between; }
  .role { font-size: 12px; font-weight: 700; padding: 3px 10px; border-radius: 999px; background: rgba(158, 122, 61, 0.25); }
  .links { display: grid; grid-template-columns: repeat(auto-fill, minmax(230px, 1fr)); gap: 10px; margin-bottom: 8px; }
  .lk { display: flex; gap: 8px; align-items: center; padding: 10px; border-radius: 6px; background: var(--panel-hi); border: 1px solid rgba(158, 122, 61, 0.5); }
  .lk:hover { border-color: var(--gold); }
  .sp { flex: 1; }
  .sm { font-size: 12px; }
  .code { display: flex; gap: 12px; align-items: flex-start; }
  code { flex: 1; font-size: 12px; word-break: break-all; user-select: text; }
</style>
