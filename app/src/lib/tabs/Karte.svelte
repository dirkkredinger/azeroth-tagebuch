<script lang="ts">
  // Routenkarte: Reiseweg auf dem Kartenbild der Zone (aus der WoW-Installation), eingefärbt nach
  // Fortbewegung, mit Markierungen für Quests, Tode, Notizen, Stufen und Erfolge.
  import Box from '$lib/components/Box.svelte';
  import Segmented from '$lib/components/Segmented.svelte';
  import HBars from '$lib/components/HBars.svelte';
  import { store } from '$lib/store.svelte';
  import { kartenBild } from '$lib/bild';
  import { dateTime, duration } from '$lib/format';
  import { eventTitle } from '$lib/wow';
  import type { Character, WowEvent } from '$lib/types';

  let { c }: { c: Character } = $props();

  const MODES: Record<string, { label: string; color: string }> = {
    zu_fuss: { label: 'Zu Fuß', color: '#8c5c33' },
    reittier: { label: 'Reittier', color: '#d9731a' },
    flug: { label: 'Fliegen', color: '#3380e6' },
    schwimmen: { label: 'Schwimmen', color: '#1ab3bf' },
    taxi: { label: 'Flugmeister', color: '#994dcc' },
  };
  const MARKER = ['quest_ab', 'tod', 'notiz', 'level', 'erfolg'];

  let positions = $state<WowEvent[]>([]);
  $effect(() => { store.positions(c.key).then((p) => (positions = p)); });

  // Alles mit Position (Proben + Ereignisse), nach Zeit
  const located = $derived([...positions, ...c.events.filter((e) => e.m != null && e.x != null && e.y != null)].sort((a, b) => a.t - b.t));
  const mapIds = $derived.by(() => {
    const m = new Map<number, number>();
    for (const e of located) m.set(e.m!, (m.get(e.m!) ?? 0) + 1);
    return [...m.entries()].sort((a, b) => b[1] - a[1]).map(([id]) => id);
  });
  let mapId = $state<number | null>(null);
  $effect(() => { if (mapId === null || !mapIds.includes(mapId)) mapId = mapIds[0] ?? null; });
  const mapName = (id: number) => store.snapshot?.archive.maps[String(id)]?.name ?? `Karte ${id}`;

  const dayKey = (t: number) => new Date(t * 1000).toDateString();
  const days = $derived([...new Set(located.filter((e) => e.m === mapId).map((e) => dayKey(e.t)))].reverse());
  let day = $state('');
  $effect(() => { mapId; day = ''; });

  let zoom = $state('route');
  const visible = $derived(located.filter((e) => e.m === mapId && (!day || dayKey(e.t) === day)));
  const route = $derived(visible.filter((e) => e.e === 'pos'));
  const marks = $derived(visible.filter((e) => MARKER.includes(e.e)).sort((a, b) => (a.e === 'tod' ? 1 : 0) - (b.e === 'tod' ? 1 : 0)));

  // Ausschnitt: quadratisch in Kartenkoordinaten (bleibt unverzerrt)
  const view = $derived.by(() => {
    if (zoom !== 'route' || !visible.length) return { x: 0, y: 0, w: 1, h: 1 };
    const xs = visible.map((e) => e.x!), ys = visible.map((e) => e.y!);
    const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)];
    const side = Math.min(1, Math.max(x1 - x0, y1 - y0, 0.12) * 1.3);
    const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
    return { x: Math.min(Math.max(cx - side / 2, 0), 1 - side), y: Math.min(Math.max(cy - side / 2, 0), 1 - side), w: side, h: side };
  });

  // Kartenbild
  let img = $state<HTMLImageElement | null>(null);
  let imgState = $state<'none' | 'loading' | 'ready' | 'failed'>('none');
  let aspect = $state(1.5);
  $effect(() => {
    const src = kartenBild(mapId);
    img = null;
    if (!src) { imgState = 'none'; return; }
    imgState = 'loading';
    const i = new Image();
    i.onload = () => { img = i; aspect = i.naturalWidth / i.naturalHeight; imgState = 'ready'; };
    i.onerror = () => (imgState = 'failed');
    i.src = src;
  });

  let canvas = $state<HTMLCanvasElement | null>(null);
  let wrapW = $state(900);
  let hover = $state<{ x: number; y: number; e: WowEvent } | null>(null);
  const H = $derived(Math.round(wrapW / aspect));
  const px = (x: number) => ((x - view.x) / view.w) * wrapW;
  const py = (y: number) => ((y - view.y) / view.h) * H;

  $effect(() => {
    const cv = canvas;
    if (!cv) return;
    const dpr = window.devicePixelRatio || 1;
    cv.width = wrapW * dpr; cv.height = H * dpr;
    const ctx = cv.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // Hintergrund
    if (img) {
      ctx.fillStyle = '#000'; ctx.fillRect(0, 0, wrapW, H);
      ctx.drawImage(img, -view.x / view.w * wrapW, -view.y / view.h * H, wrapW / view.w, H / view.h);
      ctx.fillStyle = 'rgba(0,0,0,0.12)'; ctx.fillRect(0, 0, wrapW, H);
    } else {
      const g = ctx.createLinearGradient(0, 0, wrapW, H);
      g.addColorStop(0, '#f5e8c9'); g.addColorStop(1, '#e6d4ad');
      ctx.fillStyle = g; ctx.fillRect(0, 0, wrapW, H);
      ctx.strokeStyle = 'rgba(140,100,50,0.12)';
      for (let k = 1; k < 10; k++) {
        ctx.beginPath(); ctx.moveTo((wrapW * k) / 10, 0); ctx.lineTo((wrapW * k) / 10, H); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0, (H * k) / 10); ctx.lineTo(wrapW, (H * k) / 10); ctx.stroke();
      }
    }
    // Route: dunkle Kontur, dann farbig je Fortbewegung (Lücken > 90 s = neue Sitzung)
    ctx.lineCap = 'round'; ctx.lineJoin = 'round';
    const segs: [WowEvent, WowEvent][] = [];
    for (let k = 1; k < route.length; k++) if (route[k].t - route[k - 1].t <= 90) segs.push([route[k - 1], route[k]]);
    ctx.lineWidth = 6; ctx.strokeStyle = 'rgba(0,0,0,0.55)';
    for (const [a, b] of segs) { ctx.beginPath(); ctx.moveTo(px(a.x!), py(a.y!)); ctx.lineTo(px(b.x!), py(b.y!)); ctx.stroke(); }
    ctx.lineWidth = 3.5;
    for (const [a, b] of segs) {
      const mode = a.mo ?? 'zu_fuss';
      ctx.strokeStyle = MODES[mode]?.color ?? '#888';
      ctx.setLineDash(mode === 'taxi' ? [6, 4] : []);
      ctx.beginPath(); ctx.moveTo(px(a.x!), py(a.y!)); ctx.lineTo(px(b.x!), py(b.y!)); ctx.stroke();
    }
    ctx.setLineDash([]);
    if (route.length > 1) {
      const s = route[0], e = route[route.length - 1];
      dot(ctx, px(s.x!), py(s.y!), 6, '#3c3', 'rgba(0,0,0,0.7)');
      dot(ctx, px(e.x!), py(e.y!), 7, '#fff', 'rgba(0,0,0,0.8)');
    }
    for (const m of marks) {
      const x = px(m.x!), y = py(m.y!);
      if (m.e === 'tod') {
        for (const [w, col] of [[5.5, 'rgba(255,255,255,0.9)'], [3, '#f22']] as const) {
          ctx.lineWidth = w; ctx.strokeStyle = col;
          ctx.beginPath(); ctx.moveTo(x - 6, y - 6); ctx.lineTo(x + 6, y + 6); ctx.moveTo(x + 6, y - 6); ctx.lineTo(x - 6, y + 6); ctx.stroke();
        }
      } else {
        const col = m.e === 'quest_ab' ? '#f5d742' : m.e === 'notiz' ? '#b04ce0' : m.e === 'level' ? '#3c3' : '#f0a030';
        dot(ctx, x, y, m.e === 'quest_ab' ? 5.5 : 6.5, col, 'rgba(0,0,0,0.75)');
      }
    }
  });

  function dot(ctx: CanvasRenderingContext2D, x: number, y: number, r: number, fill: string, stroke: string) {
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fillStyle = fill; ctx.fill();
    ctx.lineWidth = 1.5; ctx.strokeStyle = stroke; ctx.stroke();
  }

  function onMove(ev: MouseEvent) {
    const r = canvas!.getBoundingClientRect();
    const mx = ev.clientX - r.left, my = ev.clientY - r.top;
    let best: { d: number; e: WowEvent } | null = null;
    for (const m of marks) {
      const d = Math.hypot(px(m.x!) - mx, py(m.y!) - my);
      if (d < 14 && (!best || d < best.d)) best = { d, e: m };
    }
    hover = best ? { x: px(best.e.x!), y: py(best.e.y!), e: best.e } : null;
  }

  // Reisezeit je Fortbewegung (alle Zonen)
  const travel = $derived.by(() => {
    const secs: Record<string, number> = {};
    for (let k = 1; k < positions.length; k++) {
      const dt = positions[k].t - positions[k - 1].t;
      if (dt > 0 && dt <= 30) secs[positions[k - 1].mo ?? 'zu_fuss'] = (secs[positions[k - 1].mo ?? 'zu_fuss'] ?? 0) + dt;
    }
    return Object.entries(secs).sort((a, b) => b[1] - a[1])
      .map(([m, s]) => ({ label: MODES[m]?.label ?? m, value: s, text: duration(s), color: MODES[m]?.color ?? '#888' }));
  });
  const span = $derived(route.length > 1 ? route[route.length - 1].t - route[0].t : 0);
</script>

{#if !mapIds.length}
  <div class="panel box"><h3>Noch keine Reisewege</h3><p class="dim">Sobald du mit dem Addon unterwegs warst, erscheint hier deine Route.</p></div>
{:else}
  <div class="bar">
    <label>Zone <select bind:value={mapId}>{#each mapIds as id}<option value={id}>{mapName(id)}</option>{/each}</select></label>
    <label>Tag <select bind:value={day}><option value="">Alle Tage</option>{#each days as d}<option value={d}>{new Date(d).toLocaleDateString('de-DE', { weekday: 'short', day: 'numeric', month: 'short' })}</option>{/each}</select></label>
    <Segmented bind:value={zoom} options={[{ id: 'route', label: 'Meine Route' }, { id: 'zone', label: 'Ganze Zone' }]} />
  </div>
  <div class="legend">
    {#each Object.values(MODES) as m}<span><i style="background:{m.color}"></i>{m.label}</span>{/each}
    <span><b style="color:#f5d742">●</b> Quest</span><span><b style="color:#f22">✕</b> Tod</span><span><b style="color:#b04ce0">●</b> Notiz</span>
  </div>

  <div class="map" bind:clientWidth={wrapW} style="height:{H}px">
    <canvas bind:this={canvas} style="width:{wrapW}px;height:{H}px" onmousemove={onMove} onmouseleave={() => (hover = null)}></canvas>
    <div class="title serif">{mapId ? mapName(mapId) : ''}</div>
    {#if imgState === 'loading'}<div class="note">Kartenbild wird aus deiner WoW-Installation geladen …</div>{/if}
    {#if imgState === 'failed'}<div class="note">Kein Kartenbild für diese Zone</div>{/if}
    {#if hover}
      <div class="tip" style="left:{Math.min(hover.x + 12, wrapW - 230)}px; top:{Math.max(hover.y - 46, 0)}px">
        <b>{eventTitle(hover.e)}</b><br /><span class="dim">{dateTime(hover.e.t)}</span>
      </div>
    {/if}
  </div>

  <div class="summary dim">
    <span>{visible.filter((e) => e.e === 'quest_ab').length} Quests abgeschlossen</span>
    <span>{visible.filter((e) => e.e === 'tod').length} Tode</span>
    <span>{route.length} Wegpunkte</span>
    {#if span > 60}<span>Zeitraum {duration(span)}</span>{/if}
    <span class="sp"></span><span class="hint">Fahre mit der Maus über eine Markierung für Details</span>
  </div>

  {#if travel.length}<Box title="Reisezeit nach Fortbewegung (alle Zonen)"><HBars rows={travel} /></Box>{/if}
{/if}

<style>
  .bar { display: flex; gap: 16px; align-items: center; flex-wrap: wrap; }
  label { display: flex; gap: 6px; align-items: center; font-size: 13px; }
  select { background: rgba(0, 0, 0, 0.35); color: var(--parchment); border: 1px solid rgba(158, 122, 61, 0.55); border-radius: 6px; padding: 4px 8px; font: inherit; }
  .legend { display: flex; gap: 14px; flex-wrap: wrap; font-size: 12px; color: var(--parchment-dim); }
  .legend i { display: inline-block; width: 14px; height: 4px; border-radius: 2px; margin-right: 5px; vertical-align: middle; }
  .map { position: relative; border-radius: 12px; overflow: hidden; box-shadow: 0 3px 8px rgba(0, 0, 0, 0.6); outline: 2px solid rgba(199, 148, 56, 0.8); }
  canvas { display: block; }
  .title { position: absolute; left: 12px; top: 12px; padding: 4px 10px; border-radius: 6px; background: rgba(0, 0, 0, 0.55); color: var(--gold); font-size: 17px; font-weight: 600; }
  .note { position: absolute; left: 50%; bottom: 12px; transform: translateX(-50%); padding: 6px 12px; border-radius: 999px; background: rgba(240, 224, 189, 0.92); color: var(--ink); font-size: 12px; }
  .tip { position: absolute; padding: 8px; border-radius: 6px; background: rgba(30, 22, 14, 0.95); border: 1px solid rgba(158, 122, 61, 0.6); font-size: 12px; pointer-events: none; white-space: nowrap; }
  .summary { display: flex; gap: 18px; font-size: 13px; }
  .sp { flex: 1; }
  .hint { opacity: 0.7; }
</style>
