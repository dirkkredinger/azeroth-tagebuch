// Kleine Einstellungen der Oberfläche, im Browser-Speicher der App abgelegt

export type GuideSite = 'wowhead-en' | 'wowhead-de';
const KEY = 'guide-quelle';

function load(): GuideSite {
  try {
    const v = localStorage.getItem(KEY);
    if (v === 'wowhead-en' || v === 'wowhead-de') return v;
  } catch { /* kein Speicher */ }
  // Die deutschen Wowhead-Guides leiten teils zu 4Fansites weiter – daher standardmäßig das englische Original
  return 'wowhead-en';
}

export const settings = $state({ guides: load() });

export function setGuideSite(v: GuideSite) {
  settings.guides = v;
  try { localStorage.setItem(KEY, v); } catch { /* egal */ }
}
