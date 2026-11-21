<script lang="ts">
  // Kampf- bzw. Heilstatistik aus dem Kampflog
  import Box from '$lib/components/Box.svelte';
  import StatTile from '$lib/components/StatTile.svelte';
  import XYChart from '$lib/components/XYChart.svelte';
  import Columns from '$lib/components/Columns.svelte';
  import HBars from '$lib/components/HBars.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { store } from '$lib/store.svelte';
  import * as A from '$lib/analyse';
  import { big, dateTime, num } from '$lib/format';
  import type { Character, Fight } from '$lib/types';

  let { c, mode }: { c: Character; mode: 'damage' | 'healing' } = $props();
  const dmg = $derived(mode === 'damage');
  const accent = $derived(dmg ? 'var(--damage)' : 'var(--healing)');
  const accentHex = $derived(dmg ? '#ed5c3d' : '#5cdb73');
  const unit = $derived(dmg ? 'DPS' : 'HPS');
  const value = (f: Fight) => (dmg ? A.dps(f) : A.hps(f));
  const amount = (f: Fight) => (dmg ? f.damage : f.healing);

  const fights = $derived((store.fights[c.key] ?? []).filter((f) => amount(f) > 0));
  const live = $derived(store.live && store.live.char === c.key ? store.live : null);

  // Stufe und Gegenstandsstufe zum Zeitpunkt eines Kampfes
  const levelAt = (t: number) => { let lv: number | undefined; for (const e of c.events) { if (e.t > t) break; if (e.lv) lv = e.lv; } return lv ?? c.level; };
  const ilvlAt = (t: number) => { let il: number | undefined; for (const e of c.events) { if (e.t > t) break; if (e.e === 'ausr') il = e.il; } return il; };

  const totals = $derived.by(() => {
    const total = fights.reduce((s, f) => s + amount(f), 0);
    const secs = fights.reduce((s, f) => s + Math.max(f.end - f.start, 1), 0);
    const recent = fights.slice(-10);
    const best = [...fights].sort((a, b) => value(b) - value(a))[0];
    const over = fights.reduce((s, f) => s + f.overheal, 0);
    return {
      total, avg: total / Math.max(secs, 1), recent: recent.reduce((s, f) => s + value(f), 0) / Math.max(recent.length, 1),
      best: best ? value(best) : 0, taken: fights.reduce((s, f) => s + f.taken, 0), bosses: fights.filter((f) => f.encounter).length,
      overPct: total + over > 0 ? Math.round((over / (total + over)) * 100) : 0, absorb: fights.reduce((s, f) => s + f.absorb, 0),
    };
  });

  const perFight = $derived(fights.map((f, i) => ({ x: i + 1, y: value(f), color: f.encounter ? '#fbcc5c' : accentHex, r: f.encounter ? 5 : 3.5, title: `${A.fightTitle(f)}: ${big(value(f))} ${unit}` })));
  const avgLine = $derived(fights.length >= 3 ? fights.map((_, i) => {
    const s = fights.slice(Math.max(0, i - 4), i + 1);
    return { x: i + 1, y: s.reduce((a, f) => a + value(f), 0) / s.length };
  }) : []);
  const byLevel = $derived.by(() => {
    const m = new Map<number, number[]>();
    for (const f of fights) { const lv = levelAt(f.start); if (lv) m.set(lv, [...(m.get(lv) ?? []), value(f)]); }
    return [...m.entries()].sort((a, b) => a[0] - b[0]).map(([lv, v]) => ({ label: String(lv), value: v.reduce((a, b) => a + b, 0) / v.length, color: accentHex }));
  });
  const byIlvl = $derived(fights.map((f) => ({ x: f.itemLevel ?? ilvlAt(f.start) ?? NaN, y: value(f) })).filter((p) => !isNaN(p.x)));
  const trend = $derived.by(() => {
    const p = byIlvl;
    if (p.length < 3) return [];
    const n = p.length, sx = p.reduce((s, q) => s + q.x, 0), sy = p.reduce((s, q) => s + q.y, 0);
    const sxx = p.reduce((s, q) => s + q.x * q.x, 0), sxy = p.reduce((s, q) => s + q.x * q.y, 0);
    const d = n * sxx - sx * sx;
    if (!d) return [];
    const b = (n * sxy - sx * sy) / d, a = (sy - b * sx) / n;
    const x0 = Math.min(...p.map((q) => q.x)), x1 = Math.max(...p.map((q) => q.x));
    return x1 > x0 ? [{ x: x0, y: a + b * x0 }, { x: x1, y: a + b * x1 }] : [];
  });
  const spells = $derived.by(() => {
    const m = new Map<string, number>();
    for (const f of fights) for (const s of f.spells) m.set(s.name, (m.get(s.name) ?? 0) + (dmg ? s.damage : s.healing));
    const sum = [...m.values()].reduce((a, b) => a + b, 0) || 1;
    return [...m.entries()].filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]).slice(0, 8)
      .map(([label, v]) => ({ label, value: v, text: `${Math.round((v / sum) * 100)} %`, color: accentHex }));
  });
  let open = $state<string | null>(null);
  const fid = (f: Fight) => `${f.char}|${Math.round(f.start * 10)}`;
</script>

{#if live}
  <div class="panel hi box livebar">
    <span class="dot"></span><b class="serif lv">LIVE</b><span class="serif lt">{A.fightTitle(live)}</span><span class="sp"></span>
    <span style="color:var(--damage)">{big(A.dps(live))} DPS</span><span style="color:var(--healing)">{big(A.hps(live))} HPS</span>
    <span class="dim">{Math.round(live.end - live.start)} s</span>
  </div>
{/if}

{#if !fights.length}
  <div class="panel box">
    <h3><Icon name="scroll-text" size={16} /> {dmg ? 'Noch keine Kämpfe' : 'Noch keine Heilung'}</h3>
    <p class="dim">Die Statistik entsteht aus dem offiziellen Kampflog von WoW. Das Addon schaltet es beim Einloggen automatisch ein (abschaltbar mit /tb kampflog aus). Die App liest „Logs/WoWCombatLog….txt“ live mit – laufende Kämpfe siehst du hier, während du spielst.</p>
  </div>
{:else}
  <div class="grid-tiles">
    <StatTile title="Kämpfe" value={num(fights.length)} icon="flame" tint={accent} />
    <StatTile title={dmg ? 'Schaden gesamt' : 'Heilung gesamt'} value={big(totals.total)} icon={dmg ? 'swords' : 'heart-pulse'} tint={accent} />
    <StatTile title="Ø {unit} gesamt" value={big(totals.avg)} icon="chart" tint={accent} />
    <StatTile title="Ø {unit} letzte 10" value={big(totals.recent)} icon="chart" tint={accent} />
    <StatTile title="Bester Kampf" value={big(totals.best)} icon="crown" />
    {#if dmg}
      <StatTile title="Erlittener Schaden" value={big(totals.taken)} icon="shield" tint="var(--taken)" />
      <StatTile title="Bosskämpfe" value={num(totals.bosses)} icon="crown" />
    {:else}
      <StatTile title="Überheilung" value="{totals.overPct} %" icon="circle-alert" tint="#f0a030" />
      <StatTile title="Davon Schilde" value={big(totals.absorb)} icon="shield" tint="#8ccbfa" />
    {/if}
  </div>
  <div class="grid-2">
    <Box title="{unit} je Kampf">
      <XYChart points={perFight} lines={avgLine.length ? [{ points: avgLine, color: 'rgba(240,224,189,0.8)' }] : []} yFormat={big} xLabel="Kampf Nr. (Linie: Schnitt der letzten 5, gold: Bosse)" />
    </Box>
    <Box title="{unit} nach Stufe"><Columns rows={byLevel} format={big} xLabel="Stufe" /></Box>
    <Box title="{unit} nach Gegenstandsstufe">
      <XYChart zeroY={true} points={byIlvl.map((p) => ({ ...p, color: accentHex }))} lines={trend.length ? [{ points: trend, color: '#fbcc5c', dash: true }] : []} yFormat={big} xLabel="Gegenstandsstufe (gestrichelt: Trend)" />
    </Box>
    <Box title={dmg ? 'Stärkste Fähigkeiten' : 'Stärkste Heilzauber'}>{#if spells.length}<HBars rows={spells} />{:else}<p class="dim">Noch keine Daten</p>{/if}</Box>
  </div>

  <Box title="Letzte Kämpfe">
    {#each fights.slice(-25).reverse() as f (fid(f))}
      {@const lv = levelAt(f.start)}
      <button class="fight" onclick={() => (open = open === fid(f) ? null : fid(f))}>
        <Icon name={f.encounter ? 'crown' : f.deaths ? 'heart-crack' : 'flame'} size={15} color={f.encounter ? 'var(--gold)' : f.deaths ? '#f44' : 'var(--parchment-dim)'} />
        <div class="ft">
          <div><b>{A.fightTitle(f)}</b>
            {#if f.success === true}<span class="ok">besiegt</span>{/if}{#if f.success === false}<span class="bad">gescheitert</span>{/if}</div>
          <div class="dim small">{[f.zone, lv ? `Stufe ${lv}` : null, f.itemLevel ? `GS ${Math.round(f.itemLevel)}` : null, `${Math.round(f.end - f.start)} s`].filter(Boolean).join(' · ')}</div>
        </div>
        <div class="fv">
          <div class="serif big" style="color:{accent}">{big(value(f))} {unit}</div>
          <div class="dim small">{dateTime(f.start)}</div>
        </div>
      </button>
      {#if open === fid(f)}
        {@const list = f.spells.filter((s) => (dmg ? s.damage : s.healing) > 0)}
        {@const tot = list.reduce((a, s) => a + (dmg ? s.damage : s.healing), 0) || 1}
        <div class="detail">
          <div class="small facts">
            <span style="color:var(--damage)">Schaden {big(f.damage)}</span><span style="color:var(--healing)">Heilung {big(f.healing)}</span>
            <span style="color:var(--taken)">Erlitten {big(f.taken)}</span>{#if f.deaths}<span style="color:#f44">{f.deaths}× gestorben</span>{/if}
            {#if f.kills?.length}<span class="dim">{f.kills.length} Gegner besiegt</span>{/if}
          </div>
          {#each list as s}
            {@const v = dmg ? s.damage : s.healing}
            <div class="sp-row">
              <span class="sn">{s.name}</span>
              <span class="track"><i style="width:{(v / tot) * 100}%; background:{accentHex}"></i></span>
              <span class="dim small sv">{big(v)} · {s.hits}× · {s.hits ? Math.round((s.crits / s.hits) * 100) : 0} % krit.</span>
            </div>
          {/each}
        </div>
      {/if}
    {/each}
  </Box>
{/if}

<style>
  .livebar { display: flex; align-items: center; gap: 14px; font-weight: 600; }
  .dot { width: 10px; height: 10px; border-radius: 50%; background: #f33; animation: pulse 1.2s infinite; }
  @keyframes pulse { 50% { opacity: 0.3; } }
  .lv { color: #f33; }
  .sp { flex: 1; }
  .fight { display: flex; align-items: center; gap: 10px; width: 100%; padding: 7px 2px; background: none; border: 0; border-bottom: 1px solid rgba(158, 122, 61, 0.25); cursor: pointer; text-align: left; }
  .fight:hover { background: rgba(158, 122, 61, 0.08); }
  .ft { flex: 1; min-width: 0; }
  .fv { text-align: right; }
  .big { font-weight: 700; font-variant-numeric: tabular-nums; }
  .small { font-size: 12px; }
  .ok { color: var(--healing); font-size: 11px; font-weight: 700; margin-left: 6px; }
  .bad { color: #f44; font-size: 11px; font-weight: 700; margin-left: 6px; }
  .detail { padding: 8px 0 12px 26px; display: flex; flex-direction: column; gap: 5px; }
  .facts { display: flex; gap: 16px; margin-bottom: 4px; }
  .sp-row { display: flex; align-items: center; gap: 10px; }
  .sn { width: 160px; font-size: 12.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .track { flex: 1; height: 8px; background: rgba(0, 0, 0, 0.35); border-radius: 3px; overflow: hidden; }
  .track i { display: block; height: 100%; }
  .sv { width: 190px; text-align: right; }
</style>
