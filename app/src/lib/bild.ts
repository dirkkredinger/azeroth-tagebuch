// Adressen für Bilder aus der WoW-Installation (vom Rust-Teil über das Protokoll wowbild:// geliefert).
// Bewusst ohne convertFileSrc gebaut: das kodiert die Schrägstriche im Pfad.

const inApp = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
const windows = typeof navigator !== 'undefined' && /Windows/i.test(navigator.userAgent);
// macOS/Linux: wowbild://localhost/…, Windows (WebView2): http://wowbild.localhost/…
const base = windows ? 'http://wowbild.localhost/' : 'wowbild://localhost/';

/** Selbst gezeichnete Karten für die Beispieldaten (keine Blizzard-Grafik) */
const DEMO_KARTEN = new Set([2393, 2395, 2413, 2437]);

/** Kartenbild einer Zone (uiMapID). Beispieldaten nutzen eigene Fantasy-Karten. */
export const kartenBild = (mapId?: number | null, demo = false) => {
  if (!mapId) return null;
  if (demo || !inApp) return DEMO_KARTEN.has(mapId) ? `/demo-karten/${mapId}.svg` : null;
  return `${base}karte/${mapId}`;
};

/** Gegenstandssymbol (FileDataID) */
export const symbolBild = (fdid?: number | null) => (inApp && fdid ? `${base}symbol/${fdid}` : null);
