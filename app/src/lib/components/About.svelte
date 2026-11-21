<script lang="ts">
  // „Über“-Fenster: Version, Lizenz, Links, Unterstützen
  import Icon from './Icon.svelte';
  import ExtLink from './ExtLink.svelte';
  import { GITHUB_URL, ISSUES_URL, KOFI_URL, RELEASES_URL } from '$lib/links';
  import { i18n, setLang, t } from '$lib/i18n.svelte';
  import pkg from '../../../package.json';
  let { onclose }: { onclose: () => void } = $props();
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div class="backdrop" onclick={onclose}>
  <div class="panel card" onclick={(e) => e.stopPropagation()}>
    <img src="/favicon.png" alt="" class="logo" />
    <h2 class="serif">Azeroth-Tagebuch</h2>
    <div class="dim">{t('Version {v}', { v: pkg.version })}</div>
    <p>{t('Ein Tagebuch für deine World-of-Warcraft-Charaktere: Quests, Reisen, Kämpfe, Instanzen, Beute und Lager – automatisch aus dem Addon und dem Kampflog.')}</p>

    {#if KOFI_URL}
      <ExtLink href={KOFI_URL}><div class="kofi"><Icon name="coins" size={16} /> {t('Unterstütze das Projekt auf Ko-fi')}</div></ExtLink>
      <p class="dim small">{t('Das Tagebuch ist kostenlos und quelloffen. Wenn es dir gefällt, freue ich mich über einen Kaffee.')}</p>
    {/if}

    <div class="links">
      <ExtLink href={GITHUB_URL}><span class="lk"><Icon name="book-open" size={14} /> {t('Quellcode auf GitHub')}</span></ExtLink>
      <ExtLink href={RELEASES_URL}><span class="lk"><Icon name="refresh-cw" size={14} /> {t('Neue Versionen')}</span></ExtLink>
      <ExtLink href={ISSUES_URL}><span class="lk"><Icon name="circle-alert" size={14} /> {t('Fehler melden')}</span></ExtLink>
    </div>

    <div class="lang"><span class="dim small">{t('Sprache')}</span>
      <button class="btn" class:primary={i18n.lang === 'de'} onclick={() => setLang('de')}>Deutsch</button>
      <button class="btn" class:primary={i18n.lang === 'en'} onclick={() => setLang('en')}>English</button>
    </div>

    <p class="dim small">{t('Von dirkkredinger, entwickelt mit Unterstützung von Claude (Anthropic).')}</p>
    <p class="dim small">{t('Lizenz: GNU GPL v3.0. Inoffizielles Fan-Projekt, nicht mit Blizzard Entertainment verbunden. World of Warcraft ist eine Marke von Blizzard Entertainment, Inc. Karten und Symbole stammen aus deiner eigenen Spielinstallation und werden nicht mitgeliefert.')}</p>
    <button class="btn" onclick={onclose}>{t('Schließen')}</button>
  </div>
</div>

<style>
  .lang { display: flex; gap: 8px; align-items: center; justify-content: center; margin: 4px 0 2px; }
  .backdrop { position: fixed; inset: 0; z-index: 900; background: rgba(0, 0, 0, 0.6); display: grid; place-items: center; }
  .card { width: 460px; padding: 24px; text-align: center; }
  .logo { width: 72px; height: 72px; }
  h2 { margin: 6px 0 2px; color: var(--gold); }
  p { line-height: 1.5; }
  .small { font-size: 12px; }
  .kofi { display: inline-flex; gap: 8px; align-items: center; padding: 9px 16px; border-radius: 8px; font-weight: 700; color: var(--ink); background: linear-gradient(180deg, var(--gold), var(--gold-deep)); margin-top: 6px; }
  .links { display: flex; flex-direction: column; gap: 6px; margin: 12px 0; }
  .lk { display: inline-flex; gap: 6px; align-items: center; color: var(--gold); }
  .lk:hover { text-decoration: underline; }
</style>
