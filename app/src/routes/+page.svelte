<script lang="ts">
  import '$lib/theme.css';
  import { onMount } from 'svelte';
  import { store } from '$lib/store.svelte';
  import { i18n, setLang, t } from '$lib/i18n.svelte';
  import Sidebar from '$lib/components/Sidebar.svelte';
  import AccountOverview from '$lib/components/AccountOverview.svelte';
  import CharacterPage from '$lib/components/CharacterPage.svelte';
  import EmptyState from '$lib/components/EmptyState.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import Suche from '$lib/components/Suche.svelte';
  import Tooltip from '$lib/components/Tooltip.svelte';

  onMount(() => store.start());

  // Sprache gewechselt: Beispieldaten in der neuen Sprache laden
  let lastLang = i18n.lang;
  $effect(() => {
    const l = i18n.lang;
    if (l === lastLang) return;
    lastLang = l;
    if (store.snapshot?.demo) store.demo();
  });

  // Beim Wechsel der Ansicht wieder oben anfangen
  let content: HTMLDivElement | undefined = $state();
  $effect(() => {
    store.selection;
    store.search;
    if (content) content.scrollTop = 0;
  });
</script>

<Tooltip />
<div class="app">
  <Sidebar />
  <main>
    <div class="toolbar">
      <div class="spacer"></div>
      <div class="search"><Icon name="search" size={14} color="var(--parchment-dim)" /><input type="search" placeholder={t('Quests, Beute, Gegner, Lager suchen')} bind:value={store.search} /></div>
      <button class="tb" title={t('Zur Übersicht aller Charaktere')} onclick={() => store.show(null)}><Icon name="users" size={15} /></button>
      <button class="tb" title={t('SavedVariables und Kampflog neu einlesen')} onclick={() => store.rescan()}><Icon name="refresh-cw" size={15} /></button>
      <button class="tb" title={t('WoW-Ordner wählen')} onclick={() => store.chooseFolder()}><Icon name="folder-open" size={15} /></button>
      <button class="tb" title={t('Beispieldaten anzeigen')} onclick={() => store.demo()}><Icon name="sparkles" size={15} /></button>
      <button class="tb lang" title={i18n.lang === 'de' ? 'Switch to English' : 'Auf Deutsch umschalten'} onclick={() => setLang(i18n.lang === 'de' ? 'en' : 'de')}>{i18n.lang === 'de' ? 'EN' : 'DE'}</button>
    </div>
    <div class="content" bind:this={content}>
      {#if store.error}
        <div class="err panel box">{store.error}</div>
      {:else if !store.snapshot}
        <div class="loading dim">{t('Lade Tagebuch …')}</div>
      {:else if store.characters.length === 0}
        <EmptyState />
      {:else if store.search.trim()}
        <Suche />
      {:else if store.selected}
        {#key store.selected.key}<CharacterPage c={store.selected} />{/key}
      {:else}
        <AccountOverview />
      {/if}
    </div>
  </main>
</div>

<style>
  .tb.lang { font-size: 11px; font-weight: 800; letter-spacing: 0.5px; }
  .app { display: flex; height: 100vh; }
  main {
    flex: 1; min-width: 0; display: flex; flex-direction: column;
    background:
      radial-gradient(ellipse at top left, rgba(199, 148, 56, 0.1), transparent 55%),
      linear-gradient(180deg, var(--leather-top), var(--leather-bottom));
  }
  .toolbar { display: flex; gap: 6px; padding: 8px 16px; border-bottom: 1px solid rgba(158, 122, 61, 0.25); }
  .spacer { flex: 1; }
  .search { display: flex; align-items: center; gap: 6px; margin-right: 6px; }
  .search input { width: 280px; padding: 5px 10px; }
  .tb { display: grid; place-items: center; width: 30px; height: 28px; border-radius: 6px; cursor: pointer; background: rgba(43, 31, 20, 0.8); border: 1px solid rgba(158, 122, 61, 0.4); color: var(--parchment); }
  .tb:hover { border-color: var(--gold); color: var(--gold); }
  .content { flex: 1; overflow-y: auto; }
  .loading { padding: 40px; }
  .err { margin: 24px; color: #ff9a6b; }
</style>
