<script lang="ts">
  import { t, tn } from '$lib/i18n.svelte';
  import Icon from './Icon.svelte';
  import Avatar from './Avatar.svelte';
  import StatTile from './StatTile.svelte';
  import OrnamentHeader from './OrnamentHeader.svelte';
  import EventRow from './EventRow.svelte';
  import StackedBars from './StackedBars.svelte';
  import HBars from './HBars.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import { big, date, duration, gold, num, relative } from '$lib/format';
  import { classColor, qualityColor } from '$lib/wow';

  const chars = $derived(store.characters);
  const fights = $derived(store.fights);
  const loot = $derived(A.lootStats(chars, fights));
  const mobs = $derived(loot.filter((s) => !s.isObject));

  const runs = $derived(chars.flatMap((c) => A.instanceRuns(c)));
  const totals = $derived({
    play: chars.reduce((s, c) => s + A.playSeconds(c), 0),
    gold: chars.reduce((s, c) => s + (c.money ?? 0), 0),
    quests: chars.reduce((s, c) => s + A.turnIns(c).length, 0),
    kills: mobs.reduce((s, m) => s + A.effectiveKills(m), 0),
    levels: chars.reduce((s, c) => s + A.levelUps(c), 0),
    achievements: chars.reduce((s, c) => s + A.achievements(c).length, 0),
    deaths: chars.reduce((s, c) => s + A.deaths(c), 0),
    runs: runs.length,
    bosses: runs.reduce((s, r) => s + r.bosses.filter((b) => b.ok).length, 0),
  });

  const byKey = $derived(new Map(chars.map((c) => [c.key, c])));
  const allFights = $derived(Object.values(fights).flat());

  // Ruhmeshalle
  const records = $derived.by(() => {
    const out: { icon: string; tint: string; title: string; value: string; detail: string }[] = [];
    const bestDps = allFights.filter((f) => f.damage > 0).sort((a, b) => A.dps(b) - A.dps(a))[0];
    if (bestDps) out.push({ icon: 'flame', tint: 'var(--damage)', title: t('Höchste DPS'), value: `${big(A.dps(bestDps))} DPS`, detail: t('{name} gegen {gegner}', { name: byKey.get(bestDps.char)?.name ?? bestDps.char, gegner: A.fightTitle(bestDps) }) });
    const bestHps = allFights.filter((f) => f.healing > 0).sort((a, b) => A.hps(b) - A.hps(a))[0];
    if (bestHps) out.push({ icon: 'heart-pulse', tint: 'var(--healing)', title: t('Höchste HPS'), value: `${big(A.hps(bestHps))} HPS`, detail: `${byKey.get(bestHps.char)?.name ?? bestHps.char} · ${A.fightTitle(bestHps)}` });
    const top = [...mobs].sort((a, b) => A.effectiveKills(b) - A.effectiveKills(a))[0];
    if (top) out.push({ icon: 'paw-print', tint: '#f0a030', title: t('Liebster Gegner'), value: `${A.effectiveKills(top)}× ${top.name}`, detail: [...top.zones].sort().join(', ') });
    const finds = loot.flatMap((s) => [...s.items.values()].filter((i) => (i.quality ?? 0) >= 2).map((i) => ({ s, i })));
    finds.sort((a, b) => (b.i.quality ?? 0) - (a.i.quality ?? 0) || A.dropRate(a.s, a.i) - A.dropRate(b.s, b.i));
    if (finds[0]) out.push({ icon: 'sparkles', tint: qualityColor(finds[0].i.quality), title: t('Bester Fund'), value: finds[0].i.name, detail: t('von {name} · {p} % Droprate', { name: finds[0].s.name, p: Math.round(A.dropRate(finds[0].s, finds[0].i) * 100) }) });
    const sessions = chars.flatMap((c) => c.events.filter((e) => e.e === 'logout').map((e) => ({ c, e })));
    const longest = sessions.sort((a, b) => (b.e.dauer ?? 0) - (a.e.dauer ?? 0))[0];
    if (longest?.e.dauer) out.push({ icon: 'hourglass', tint: '#4f9dff', title: t('Längste Sitzung'), value: duration(longest.e.dauer), detail: `${longest.c.name} · ${date(longest.e.t)}` });
    const richest = [...chars].sort((a, b) => (b.money ?? 0) - (a.money ?? 0))[0];
    if (richest?.money) out.push({ icon: 'coins', tint: '#f5d742', title: t('Reichster Charakter'), value: gold(richest.money), detail: richest.name });
    return out;
  });

  const days = $derived(A.playPerDay(chars, 14));
  const series = $derived(chars.map((c) => ({ key: c.key, label: c.name, color: classColor(c.classToken) })));
  const goldRows = $derived(chars.filter((c) => (c.money ?? 0) > 0).sort((a, b) => (b.money ?? 0) - (a.money ?? 0))
    .map((c) => ({ label: c.name, value: c.money ?? 0, text: gold(c.money ?? 0), color: classColor(c.classToken) })));

  const recent = $derived(
    chars.flatMap((c) => c.events.filter((e) => !['zone', 'ausr'].includes(e.e)).slice(-20).map((e) => ({ c, e })))
      .sort((a, b) => b.e.t - a.e.t).slice(0, 15),
  );
</script>

<div class="page">
  <OrnamentHeader text={t('Alle Charaktere')} />

  <div class="grid-tiles">
    <StatTile title={t('Charaktere')} value={String(chars.length)} icon="users" />
    <StatTile title={t('Spielzeit gesamt')} value={duration(totals.play)} icon="clock" tint="#4f9dff" />
    <StatTile title={t('Gold gesamt')} value={gold(totals.gold)} icon="coins" tint="#f5d742" />
    <StatTile title={t('Quests gesamt')} value={num(totals.quests)} icon="badge-check" tint="#f5d742" />
    <StatTile title={t('Gegner besiegt')} value={num(totals.kills)} icon="flame" tint="var(--damage)" />
    <StatTile title={t('Stufenaufstiege')} value={num(totals.levels)} icon="circle-arrow-up" tint="#4cd964" />
    <StatTile title={t('Erfolge')} value={num(totals.achievements)} icon="trophy" tint="#f0a030" />
    <StatTile title={t('Instanzläufe')} value={num(totals.runs)} icon="castle" tint="#4f9dff" />
    <StatTile title={t('Bosse besiegt')} value={num(totals.bosses)} icon="skull" tint="var(--damage)" />
    <StatTile title={t('Tode')} value={num(totals.deaths)} icon="heart-crack" tint="#ff4d4d" />
  </div>

  <h2 class="serif">{t('Deine Helden')}</h2>
  <div class="heroes">
    {#each chars as c (c.key)}
      <button class="panel hero" onclick={() => store.show(c.key)}>
        <div class="top">
          <Avatar name={c.name} token={c.classToken} size={44} round={false} />
          <div class="who">
            <div class="serif hname" style="color:{classColor(c.classToken)}">{c.name}</div>
            <div class="small">{[c.spec, c.className].filter(Boolean).join(' ')}</div>
            <div class="tiny dim">{c.realm}</div>
          </div>
          <div class="lvl"><span class="serif">{c.level ?? '–'}</span><small>{t('Stufe')}</small></div>
        </div>
        <div class="stats">
          <span><Icon name="clock" size={12} /> {duration(A.playSeconds(c))}</span>
          <span><Icon name="badge-check" size={12} /> {t('{n} Quests', { n: A.turnIns(c).length })}</span>
          {#if c.itemLevel}<span><Icon name="shield-check" size={12} /> {t('GS {n}', { n: Math.round(c.itemLevel) })}</span>
          {:else}<span><Icon name="flame" size={12} /> {t('{n} Kämpfe', { n: (fights[c.key] ?? []).length })}</span>{/if}
        </div>
        {#if A.lastSeen(c)}<div class="tiny dim seen">{t('zuletzt gespielt {when}', { when: relative(A.lastSeen(c)!) })}</div>{/if}
      </button>
    {/each}
  </div>

  {#if records.length}
    <div class="panel box">
      <h3>{t('Ruhmeshalle')}</h3>
      <div class="records">
        {#each records as r}
          <div class="rec">
            <Icon name={r.icon} size={24} color={r.tint} />
            <div class="rtxt">
              <div class="tiny dim">{r.title}</div>
              <div class="serif rval">{r.value}</div>
              <div class="tiny dim">{r.detail}</div>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}

  <div class="grid-2">
    <div class="panel box"><h3>{t('Spielzeit der letzten 14 Tage')}</h3><StackedBars {days} {series} /></div>
    <div class="panel box"><h3>{t('Gold je Charakter')}</h3>
      {#if goldRows.length}<HBars rows={goldRows} />{:else}<p class="dim">{t('Noch keine Daten')}</p>{/if}
    </div>
  </div>

  <div class="panel box">
    <h3>{t('Zuletzt bei allen Charakteren')}</h3>
    {#each recent as { c, e } (c.key + e.t + e.e + (e.q ?? '') + (e.src ?? ''))}
      <div class="rrow"><span class="rname" style="color:{classColor(c.classToken)}">{c.name}</span><EventRow event={e} names={A.questNames(c)} /></div>
    {/each}
  </div>
</div>

<style>
  .page { padding: 24px; display: flex; flex-direction: column; gap: 18px; }
  h2 { margin: 0; font-size: 17px; color: var(--gold); }
  .heroes { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
  .hero { text-align: left; padding: 14px; cursor: pointer; transition: transform 0.12s; }
  .hero:hover { transform: scale(1.015); background: linear-gradient(180deg, var(--panel-hi), var(--panel)); }
  .top { display: flex; gap: 12px; align-items: center; padding-bottom: 10px; border-bottom: 1px solid rgba(158, 122, 61, 0.4); }
  .who { flex: 1; min-width: 0; }
  .hname { font-size: 17px; font-weight: 700; }
  .lvl { text-align: right; }
  .lvl span { display: block; font-size: 24px; font-weight: 700; color: var(--gold); line-height: 1; }
  .lvl small { font-size: 10.5px; color: var(--parchment-dim); }
  .stats { display: flex; justify-content: space-between; margin-top: 10px; font-size: 12px; }
  .stats span { display: inline-flex; align-items: center; gap: 4px; }
  .seen { margin-top: 8px; }
  .small { font-size: 12px; }
  .tiny { font-size: 11px; }
  .records { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 10px; }
  .rec { display: flex; gap: 12px; align-items: center; padding: 10px; border-radius: 6px; background: rgba(61, 43, 26, 0.6); }
  .rtxt { min-width: 0; }
  .rval { font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .rrow { display: flex; gap: 8px; align-items: baseline; }
  .rname { width: 90px; flex: none; font-size: 12px; font-weight: 700; }
  .rrow :global(.row) { flex: 1; }
</style>
