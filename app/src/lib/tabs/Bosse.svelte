<script lang="ts">
  // Bosskämpfe: Hinweise aus dem Dungeonkompendium für Rolle und Spezialisierung des Charakters,
  // dazu die eigene Erfahrung mit jedem Boss. Kommt beim Betreten einer Instanz von selbst nach vorn.
  import { t } from '$lib/i18n.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import ExtLink from '$lib/components/ExtLink.svelte';
  import ItemIcon from '$lib/components/ItemIcon.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import * as B from '$lib/boss';
  import { symbolBild } from '$lib/bild';
  import { big, date } from '$lib/format';
  import { roleName, wowheadBase } from '$lib/wow';
  import type { Character, JournalEncounter, JournalInstance, JournalSection } from '$lib/types';

  let { c }: { c: Character } = $props();

  const journal = $derived(store.journal.slice().sort((a, b) => Number(a.raid) - Number(b.raid) || a.name.localeCompare(b.name)));
  const fights = $derived(store.fights[c.key] ?? []);
  const runs = $derived(A.instanceRuns(c));

  // Live: steht dieser Charakter gerade in einer Instanz?
  const loc = $derived(store.location && store.location.difficultyId > 0 && (!store.location.char || store.location.char === c.key) ? store.location : null);
  const liveInst = $derived(loc ? store.journalFor(loc.instanceId, loc.name) : undefined);
  const lastInst = $derived.by(() => {
    for (let i = runs.length - 1; i >= 0; i--) { const j = store.journalFor(runs[i].iid, runs[i].name); if (j) return j; }
    return undefined;
  });

  let chosen = $state<number | null>(null);
  // neue Instanz betreten → dorthin springen
  const liveId = $derived(liveInst?.id);
  $effect(() => { if (liveId) chosen = liveId; });
  const inst = $derived<JournalInstance | undefined>(journal.find((j) => j.id === chosen) ?? liveInst ?? lastInst ?? journal[0]);

  // svelte-ignore state_referenced_locally
  let role = $state(c.role ?? 'DAMAGER'); // die Seite wird je Charakter neu aufgebaut
  const kit = $derived(role === c.role || !c.role ? B.specKit(c.specId) : null);
  const removeNames = $derived((kit?.removes ?? []).map((f) => t(B.FLAG_INFO[f].label)));

  // Welche Bosse liegen in diesem Lauf schon? (live aus dem Kampflog)
  const killedNow = $derived.by(() => {
    const out = new Set<string>();
    if (inst && loc && liveInst?.id === inst.id) {
      for (const f of fights) if (f.start >= loc.t && f.success && f.encounter) out.add(f.encounter.toLowerCase());
    }
    return out;
  });
  const isLiveBoss = (e: JournalEncounter) => !!loc?.encounter && (loc.encounter.id === e.encounterId || loc.encounter.name.toLowerCase() === e.name.toLowerCase());
  const nextBoss = $derived(inst?.encounters.find((e) => isLiveBoss(e)) ?? inst?.encounters.find((e) => !killedNow.has(e.name.toLowerCase())));

  let open = $state(new Set<number>());
  let autoOpened = $state<string | null>(null);
  // den aktuellen bzw. nächsten Boss aufklappen (einmal je Instanz und Boss)
  $effect(() => {
    const k = inst && nextBoss ? `${inst.id}|${nextBoss.id}` : null;
    if (k && k !== autoOpened) { autoOpened = k; open = new Set([nextBoss!.id]); }
  });
  const toggle = (id: number) => { const s = new Set(open); s.has(id) ? s.delete(id) : s.add(id); open = s; };
  let showAll = $state(new Set<number>());
  const toggleAll = (id: number) => { const s = new Set(showAll); s.has(id) ? s.delete(id) : s.add(id); showAll = s; };

  const mmss = (sec: number) => `${Math.floor(sec / 60)}:${String(Math.round(sec % 60)).padStart(2, '0')}`;
  const spellLink = (s: JournalSection) => (s.spellId ? `${wowheadBase()}/spell=${s.spellId}` : null);
  const badges = (s: JournalSection) => s.flags.filter((f) => f >= 3 && B.FLAG_INFO[f]);
  const diffName = (id: number) => ({ 1: 'Normal', 2: 'Heroisch', 8: 'Mythisch+', 14: 'Normal', 15: 'Heroisch', 16: 'Mythisch', 17: 'LFR', 23: 'Mythisch', 24: 'Zeitwanderung', 208: 'Tiefe' } as Record<number, string>)[id];
</script>

{#snippet ability(s: JournalSection, withText = true)}
  <div class="ab">
    {#if symbolBild(s.icon)}<img class="sic" src={symbolBild(s.icon)} alt="" />{:else}<span class="sic none"><Icon name="zap" size={11} /></span>{/if}
    <div class="abt">
      <div class="abh">
        {#if spellLink(s)}<ExtLink href={spellLink(s)}><span class="abn">{s.title}</span></ExtLink>{:else}<span class="abn">{s.title}</span>{/if}
        {#each badges(s) as f}<span class="flag" style="color:{B.FLAG_INFO[f].color};border-color:{B.FLAG_INFO[f].color}">{t(B.FLAG_INFO[f].label)}</span>{/each}
      </div>
      {#if withText && s.description}<div class="txt">{B.cleanText(s.description)}</div>{/if}
    </div>
  </div>
{/snippet}

{#snippet nodes(list: B.SectionNode[])}
  {#each list as n (n.s.id)}
    <div class="node" style="margin-left:{Math.min(n.s.depth, 4) * 14}px">{@render ability(n.s)}</div>
    {@render nodes(n.children)}
  {/each}
{/snippet}

{#snippet tips(list: B.SectionNode[])}
  {#each list as n (n.s.id)}
    {#if n.s.description}<div class="tip">{B.cleanText(n.s.description)}</div>{/if}
    {#each n.children as ch (ch.s.id)}
      <div class="tip bullet">{#if ch.s.title}<b>{ch.s.title}</b>{/if}{#if ch.s.title && ch.s.description}: {/if}{B.cleanText(ch.s.description)}</div>
      {#each ch.children as g (g.s.id)}<div class="tip bullet deep"><b>{g.s.title}</b>{#if g.s.description}: {B.cleanText(g.s.description)}{/if}</div>{/each}
    {/each}
  {/each}
{/snippet}

{#if !journal.length}
  <div class="panel box">
    <h3>{t('Noch keine Bossdaten')}</h3>
    <p class="dim">{t('Ab Addon-Version 1.5 liest das Tagebuch beim Einloggen die Bosse und Fähigkeiten der aktuellen Saison aus dem Dungeonkompendium (und beim Betreten jeder anderen Instanz deren Bosse). WoW speichert sie beim Ausloggen oder nach /reload – danach erscheinen sie hier.')}</p>
    {#if loc}<p class="live-line"><Icon name="map-pin" size={13} /> {t('Du bist gerade in {name}.', { name: loc.name })}</p>{/if}
  </div>
{:else if inst}
  <div class="panel top">
    <div class="ttl">
      <Icon name={inst.raid ? 'crown' : 'castle'} size={22} color={inst.raid ? '#c27aff' : '#4f9dff'} />
      <div class="grow">
        <div class="serif name">{inst.name}</div>
        <div class="dim sm">{inst.raid ? t('Schlachtzug') : t('Dungeon')} · {inst.encounters.length} {t('Bosse')}
          {#if loc && liveInst?.id === inst.id}
            · <span class="live-line"><Icon name="map-pin" size={12} /> {t('Du bist hier')}{diffName(loc.difficultyId) ? ` (${t(diffName(loc.difficultyId)!)})` : ''}</span>
          {/if}
        </div>
      </div>
      {#if loc?.encounter && liveInst?.id === inst.id}<span class="pill fight"><Icon name="flame" size={12} /> {t('Kampf läuft: {name}', { name: loc.encounter.name })}</span>{/if}
      <select value={inst.id} onchange={(ev) => { chosen = Number(ev.currentTarget.value); autoOpened = null; }}>
        {#each journal as j (j.id)}<option value={j.id}>{j.raid ? '👑 ' : ''}{j.name}</option>{/each}
      </select>
    </div>
    <div class="who">
      <Segmented bind:value={role} options={[{ id: 'TANK', label: t('Tank') }, { id: 'HEALER', label: t('Heiler') }, { id: 'DAMAGER', label: t('Schaden') }]} />
      {#if kit}
        <span class="chip" class:off={!kit.interrupt}><Icon name="zap" size={12} /> {kit.interrupt ? t('Du kannst unterbrechen') : t('Kein Unterbrechen')}</span>
        {#if removeNames.length}<span class="chip"><Icon name="droplet" size={12} /> {t('Du entfernst: {list}', { list: removeNames.join(', ') })}</span>{/if}
        <span class="dim sm">{c.spec ?? ''} · {t('Grundfähigkeiten der Spezialisierung, Talente nicht berücksichtigt')}</span>
      {:else if role !== c.role}
        <span class="dim sm">{t('Ansicht als {role}', { role: roleName(role) })}</span>
      {/if}
    </div>
  </div>

  {#each inst.encounters as e, i (e.id)}
    {@const g = B.guide(e, role, kit)}
    {@const h = B.history(c, fights, e)}
    {@const dead = killedNow.has(e.name.toLowerCase())}
    {@const live = isLiveBoss(e)}
    <div class="panel boss" class:live class:next={!live && nextBoss?.id === e.id} class:dead>
      <button class="head" onclick={() => toggle(e.id)}>
        <span class="no">{i + 1}</span>
        <Icon name={open.has(e.id) ? 'chevron-down' : 'chevron-right'} size={14} color="var(--gold-dim)" />
        <div class="grow">
          <div class="serif bn">{e.name}
            {#if live}<span class="tag fight">{t('Kampf läuft')}</span>{:else if dead}<span class="tag ok">{t('besiegt')}</span>{:else if nextBoss?.id === e.id && loc}<span class="tag nx">{t('als Nächstes')}</span>{/if}
          </div>
          <div class="dim sm">
            {#if h.pulls}
              {t('{n}× besiegt', { n: h.kills })}{h.wipes ? ' · ' + t('{n}× gescheitert', { n: h.wipes }) : ''}{h.fastest ? ' · ' + t('schnellster {d}', { d: mmss(h.fastest) }) : ''}{h.bestDps ? ' · ' + t('beste {n} DPS', { n: big(h.bestDps) }) : ''}{role === 'HEALER' && h.bestHps ? ' · ' + t('beste {n} HPS', { n: big(h.bestHps) }) : ''}{h.deaths ? ' · ' + t('{n}× gestorben', { n: h.deaths }) : ''}{h.last ? ' · ' + t('zuletzt {d}', { d: date(h.last) }) : ''}
            {:else}{t('Noch nie gekämpft')}{/if}
          </div>
        </div>
        <div class="cnts">
          {#if g.deadly.length}<span class="cnt" style="color:#ff4d4d" title={t('Tödlich / Wichtig')}><Icon name="triangle-alert" size={12} /> {g.deadly.length}</span>{/if}
          {#if g.interrupts.length}<span class="cnt" style="color:#4fd6e8" title={t('Unterbrechen')}><Icon name="zap" size={12} /> {g.interrupts.length}</span>{/if}
          {#if g.removable.length}<span class="cnt" style="color:#5aa8ff" title={t('Entfernen')}><Icon name="droplet" size={12} /> {g.removable.length}</span>{/if}
        </div>
      </button>

      {#if open.has(e.id)}
        <div class="body">
          {#if e.description}<p class="lore dim">{B.cleanText(e.description)}</p>{/if}
          {#if h.loot.length}
            <div class="loot">
              <span class="dim sm">{t('Deine Beute')}</span>
              {#each h.loot as l (l.itemId ?? l.name)}
                <ItemIcon icon={l.icon} quality={l.quality} size={26} title={l.times > 1 ? `${l.name} (${l.times}×)` : l.name} />
              {/each}
            </div>
          {/if}
          <div class="cols">
            <div class="col">
              <h4><Icon name="user" size={13} /> {t('Für dich als {role}', { role: roleName(role) })}</h4>
              {#if g.roleTips.length}{@render tips(g.roleTips)}{/if}
              {#each g.roleAbilities as s (s.id)}{@render ability(s)}{/each}
              {#if !g.roleTips.length && !g.roleAbilities.length}<div class="dim sm">{t('Das Kompendium hat für diese Rolle keine eigenen Hinweise.')}</div>{/if}
              {#if g.overview.some((n) => n.s.description || n.children.length)}
                <h4>{t('Überblick')}</h4>
                {@render tips(g.overview)}
              {/if}
            </div>
            <div class="col">
              {#if g.deadly.length}
                <h4 style="color:#ff6b5a"><Icon name="triangle-alert" size={13} /> {t('Tödlich / Wichtig')}</h4>
                {#each g.deadly as s (s.id)}{@render ability(s)}{/each}
              {/if}
              {#if g.interrupts.length}
                <h4 style="color:#4fd6e8"><Icon name="zap" size={13} /> {t('Unterbrechen')}</h4>
                {#each g.interrupts as s (s.id)}{@render ability(s, false)}{/each}
              {/if}
              {#if g.removable.length}
                <h4 style="color:#5aa8ff"><Icon name="droplet" size={13} /> {t('Kannst du entfernen')}</h4>
                {#each g.removable as s (s.id)}{@render ability(s, false)}{/each}
              {/if}
              {#if !g.deadly.length && !g.interrupts.length && !g.removable.length}<div class="dim sm">{t('Keine besonders markierten Fähigkeiten.')}</div>{/if}
            </div>
          </div>
          <button class="more" onclick={() => toggleAll(e.id)}>
            <Icon name={showAll.has(e.id) ? 'chevron-down' : 'chevron-right'} size={13} /> {t('Alle Fähigkeiten')}
          </button>
          {#if showAll.has(e.id)}<div class="all">{@render nodes(g.abilities)}</div>{/if}
        </div>
      {/if}
    </div>
  {/each}
  <p class="dim sm src">{t('Texte aus dem Dungeonkompendium deines WoW-Clients, ausgelesen vom Addon.')}</p>
{/if}

<style>
  .top { padding: 12px 14px; display: flex; flex-direction: column; gap: 10px; }
  .ttl { display: flex; align-items: center; gap: 12px; }
  .grow { flex: 1; min-width: 0; }
  .name { font-size: 19px; color: var(--gold); font-weight: 700; }
  .sm { font-size: 12px; }
  select { max-width: 260px; }
  .who { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  .chip { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; font-weight: 700; padding: 3px 9px; border-radius: 999px; background: rgba(79, 214, 232, 0.12); color: #9fe6f0; }
  .chip.off { background: rgba(158, 122, 61, 0.2); color: var(--parchment-dim); }
  .live-line { display: inline-flex; align-items: center; gap: 4px; color: #4cd964; font-weight: 700; }
  .pill { display: inline-flex; align-items: center; gap: 5px; font-size: 12px; font-weight: 700; padding: 4px 10px; border-radius: 999px; }
  .pill.fight { color: #ff5a5a; background: rgba(255, 60, 60, 0.15); }

  .boss { padding: 8px 10px; }
  .boss.live { box-shadow: 0 0 0 1.5px #ff5a5a inset; }
  .boss.next { box-shadow: 0 0 0 1.5px var(--gold) inset; }
  .boss.dead .bn { opacity: 0.65; }
  .head { display: flex; align-items: center; gap: 10px; width: 100%; background: none; border: 0; cursor: pointer; text-align: left; color: inherit; padding: 2px 0; }
  .no { width: 22px; height: 22px; border-radius: 50%; display: grid; place-items: center; font-size: 11px; font-weight: 800; background: rgba(158, 122, 61, 0.3); color: var(--gold); flex: none; }
  .bn { font-size: 15px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
  .tag { font-family: var(--sans, inherit); font-size: 10.5px; font-weight: 800; padding: 1px 7px; border-radius: 999px; text-transform: uppercase; letter-spacing: 0.4px; }
  .tag.fight { background: rgba(255, 60, 60, 0.2); color: #ff6b6b; }
  .tag.ok { background: rgba(76, 217, 100, 0.18); color: #4cd964; }
  .tag.nx { background: rgba(199, 148, 56, 0.25); color: var(--gold); }
  .cnts { display: flex; gap: 10px; }
  .cnt { display: inline-flex; align-items: center; gap: 3px; font-size: 12px; font-weight: 800; }

  .body { padding: 6px 4px 4px 34px; }
  .lore { font-size: 12.5px; font-style: italic; margin: 2px 0 8px; white-space: pre-line; }
  .cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 18px; }
  .col { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  h4 { display: flex; align-items: center; gap: 6px; margin: 6px 0 2px; font-family: var(--serif); color: var(--gold); font-size: 13px; }
  .tip { font-size: 13px; line-height: 1.45; white-space: pre-line; }
  .tip.bullet { padding-left: 14px; position: relative; }
  .tip.bullet::before { content: '•'; position: absolute; left: 2px; color: var(--gold); }
  .tip.deep { margin-left: 14px; }
  .ab { display: flex; gap: 8px; align-items: flex-start; }
  .sic { width: 20px; height: 20px; border-radius: 4px; flex: none; margin-top: 1px; border: 1px solid rgba(158, 122, 61, 0.6); }
  .sic.none { display: grid; place-items: center; background: rgba(0, 0, 0, 0.4); color: var(--gold-dim); }
  .abt { min-width: 0; flex: 1; }
  .abh { display: flex; flex-wrap: wrap; align-items: center; gap: 5px; }
  .abn { font-weight: 700; font-size: 13px; }
  .flag { font-size: 10px; font-weight: 800; padding: 0 5px; border: 1px solid; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.3px; }
  .txt { font-size: 12.5px; line-height: 1.45; color: var(--parchment-dim); white-space: pre-line; }
  .more { margin-top: 10px; display: inline-flex; align-items: center; gap: 4px; background: none; border: 0; color: var(--gold); cursor: pointer; font-family: var(--serif); font-size: 13px; font-weight: 600; padding: 0; }
  .all { display: flex; flex-direction: column; gap: 6px; margin-top: 6px; }
  .src { margin: 4px 2px 0; }
  @media (max-width: 800px) { .body { padding-left: 0; } }
  .loot { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin: 0 0 10px; }
  .loot span { margin-right: 4px; }
</style>
