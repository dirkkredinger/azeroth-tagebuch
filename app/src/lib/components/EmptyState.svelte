<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Icon from './Icon.svelte';
  import { store } from '$lib/store.svelte';
</script>

<div class="wrap">
  <div class="panel box card">
    <Icon name="book-open" size={42} color="var(--gold)" />
    <h2 class="serif">{t('Noch keine Tagebuch-Daten')}</h2>
    <p>{t('Spiel mit aktiviertem Addon „Azeroth-Tagebuch“ und logg dich aus oder tippe /reload. Die App liest die Daten dann automatisch ein.')}</p>
    <p class="dim small">{t('Gesucht wird in: {pfad}', { pfad: `${store.snapshot?.wowFolder}/WTF/Account/…/SavedVariables` })}
      {#if store.snapshot && !store.snapshot.wowFolderExists}<br /><span class="warn">{t('Dieser Ordner existiert nicht – bitte den WoW-Ordner wählen.')}</span>{/if}
    </p>
    <div class="actions">
      <button class="btn primary" onclick={() => store.demo()}><Icon name="sparkles" size={14} /> {t('Beispieldaten anzeigen')}</button>
      <button class="btn" onclick={() => store.chooseFolder()}><Icon name="folder-open" size={14} /> {t('WoW-Ordner wählen …')}</button>
    </div>
  </div>
</div>

<style>
  .wrap { height: 100%; display: grid; place-items: center; padding: 40px; }
  .card { max-width: 560px; text-align: center; padding: 32px; }
  h2 { color: var(--gold); margin: 12px 0 8px; }
  p { line-height: 1.5; }
  .small { font-size: 12px; }
  .warn { color: #ff9a6b; }
  .actions { display: flex; gap: 10px; justify-content: center; margin-top: 16px; }
</style>
