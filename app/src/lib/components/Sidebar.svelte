<script lang="ts">
  import Icon from './Icon.svelte';
  import Avatar from './Avatar.svelte';
  import { store } from '$lib/store.svelte';
  import { classColor, subtitle } from '$lib/wow';
  import { relative } from '$lib/format';
  import { KOFI_URL } from '$lib/links';
  import ExtLink from './ExtLink.svelte';
  import About from './About.svelte';
  let about = $state(false);
</script>

{#if about}<About onclose={() => (about = false)} />{/if}

<aside>
  <div class="title serif"><Icon name="book-open" size={16} color="var(--gold)" /> Azeroth-Tagebuch</div>

  <button class="entry" class:active={store.selection === null} onclick={() => store.show(null)}>
    <div class="all"><Icon name="users" size={13} color="var(--gold)" /></div>
    <div>
      <div class="name serif">Alle Charaktere</div>
      <div class="sub">{store.characters.length} {store.characters.length === 1 ? 'Charakter' : 'Charaktere'} im Überblick</div>
    </div>
  </button>
  <div class="sep"></div>
  <div class="section">Charaktere</div>
  <div class="list">
    {#each store.characters as c (c.key)}
      <button class="entry" class:active={store.selection === c.key} onclick={() => store.show(c.key)}>
        <Avatar name={c.name} token={c.classToken} />
        <div class="meta">
          <div class="name serif" style="color:{classColor(c.classToken)}">{c.name}</div>
          <div class="sub">{subtitle(c)}</div>
          <div class="realm">{c.realm}</div>
        </div>
      </button>
    {/each}
  </div>

  <div class="support">
    {#if KOFI_URL}<ExtLink href={KOFI_URL}><span class="kofi"><Icon name="coins" size={13} /> Unterstützen</span></ExtLink>{/if}
    <button class="about" onclick={() => (about = true)}><Icon name="book-open" size={13} /> Über</button>
  </div>
  <footer>
    {#if store.live}
      <div class="live"><span class="dot"></span> Im Kampf</div>
    {/if}
    <div class="status">
      <Icon name={store.snapshot?.demo ? 'sparkles' : 'radio'} size={12} color={store.snapshot?.demo ? '#f0a030' : '#4cd964'} />
      <span>{store.snapshot?.status ?? 'Lade …'}</span>
    </div>
    {#if store.snapshot?.lastCheck && !store.snapshot.demo}
      <div class="checked">Geprüft {relative(store.snapshot.lastCheck)}</div>
    {/if}
  </footer>
</aside>

<style>
  aside { width: 260px; flex: none; display: flex; flex-direction: column; background: var(--sidebar); border-right: 1px solid rgba(158, 122, 61, 0.35); }
  .title { display: flex; align-items: center; gap: 8px; padding: 16px 16px 10px; font-size: 16px; font-weight: 600; color: var(--gold); }
  .entry { display: flex; align-items: center; gap: 10px; width: calc(100% - 16px); margin: 1px 8px; padding: 7px 10px; background: none; border: 0; border-radius: 8px; cursor: pointer; text-align: left; }
  .entry:hover { background: rgba(158, 122, 61, 0.15); }
  .entry.active { background: rgba(158, 122, 61, 0.35); }
  .all { width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; background: var(--panel-hi); border: 1.5px solid rgba(251, 204, 92, 0.8); flex: none; }
  .name { font-weight: 600; font-size: 14px; }
  .sub { font-size: 11.5px; color: var(--parchment-dim); }
  .realm { font-size: 10.5px; color: rgba(191, 176, 145, 0.6); }
  .meta { min-width: 0; }
  .sep { height: 1px; margin: 6px 12px; background: rgba(158, 122, 61, 0.35); }
  .section { font-size: 11px; font-weight: 600; color: rgba(191, 176, 145, 0.6); padding: 6px 16px 4px; }
  .list { flex: 1; overflow-y: auto; }
  .support { display: flex; gap: 8px; padding: 8px 14px; border-top: 1px solid rgba(158, 122, 61, 0.25); }
  .kofi { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 6px; font-size: 12px; font-weight: 700; color: var(--ink); background: linear-gradient(180deg, var(--gold), var(--gold-deep)); }
  .about { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 6px; font-size: 12px; background: none; border: 1px solid rgba(158, 122, 61, 0.5); color: var(--parchment-dim); cursor: pointer; }
  .about:hover { color: var(--gold); border-color: var(--gold); }
  footer { border-top: 1px solid rgba(158, 122, 61, 0.4); padding: 10px 14px; font-size: 11.5px; color: var(--parchment-dim); }
  .status { display: flex; gap: 6px; align-items: flex-start; }
  .checked { color: rgba(191, 176, 145, 0.55); margin-left: 18px; }
  .live { display: flex; align-items: center; gap: 6px; color: #ff5a5a; font-weight: 700; margin-bottom: 6px; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: #ff4040; animation: pulse 1.2s ease-in-out infinite; }
  @keyframes pulse { 50% { opacity: 0.3; } }
</style>
