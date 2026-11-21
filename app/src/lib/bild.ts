// Adressen für Bilder aus der WoW-Installation (vom Rust-Teil über das Protokoll wowbild:// geliefert).
// Bewusst ohne convertFileSrc gebaut: das kodiert die Schrägstriche im Pfad.

const inApp = typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
const windows = typeof navigator !== 'undefined' && /Windows/i.test(navigator.userAgent);
// macOS/Linux: wowbild://localhost/…, Windows (WebView2): http://wowbild.localhost/…
const base = windows ? 'http://wowbild.localhost/' : 'wowbild://localhost/';

/** Kartenbild einer Zone (uiMapID) – null in der Browser-Vorschau */
export const kartenBild = (mapId?: number | null) => (inApp && mapId ? `${base}karte/${mapId}` : null);

/** Gegenstandssymbol (FileDataID) */
export const symbolBild = (fdid?: number | null) => (inApp && fdid ? `${base}symbol/${fdid}` : null);
