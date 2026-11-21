// Item-Tooltip im WoW-Stil: ein einziges schwebendes Fenster für die ganze App.
// Benutzung: <div use:itemTip={{ name, quality, … }}>

export interface ItemTip {
  name?: string;
  quality?: number;
  icon?: number;
  itemLevel?: number;
  slot?: string;
  stats?: Record<string, number>;
  count?: number;
  /** zusätzliche Zeilen, z. B. Herkunft oder Droprate */
  lines?: { text: string; color?: string }[];
  /** Hinweis unten (grau), z. B. „Klicken: auf Wowhead ansehen“ */
  hint?: string;
}

class TipState {
  tip = $state<ItemTip | null>(null);
  x = $state(0);
  y = $state(0);
}
export const tipState = new TipState();

export function itemTip(node: HTMLElement, data: ItemTip | null | undefined) {
  let current = data;
  const move = (e: MouseEvent) => { tipState.x = e.clientX; tipState.y = e.clientY; };
  const enter = (e: MouseEvent) => { if (!current?.name) return; tipState.tip = current; move(e); };
  const leave = () => { tipState.tip = null; };
  node.addEventListener('mouseenter', enter);
  node.addEventListener('mousemove', move);
  node.addEventListener('mouseleave', leave);
  return {
    update(d: ItemTip | null | undefined) { current = d; if (tipState.tip && d?.name) tipState.tip = d; },
    destroy() {
      node.removeEventListener('mouseenter', enter);
      node.removeEventListener('mousemove', move);
      node.removeEventListener('mouseleave', leave);
      if (tipState.tip === current) tipState.tip = null;
    },
  };
}
