<script lang="ts">
  // Symbole nach Namen (Lucide, MIT-Lizenz)
  import {
    LogIn, LogOut, Map, Shield, CircleAlert, BadgeCheck, CircleX, CircleArrowUp, Trophy, HeartCrack, Plane,
    NotebookPen, ShieldCheck, Sparkles, Shirt, Backpack, Circle, Users, Clock, Coins, Flame, BookOpen,
    RefreshCw, FolderOpen, Search, ChevronLeft, Crown, Hourglass, PawPrint, HeartPulse, Swords, ScrollText,
    Radio, WandSparkles, House, ChartColumn, Archive, UserRound, Castle, Skull, Pickaxe, Timer,
    ChevronDown, ChevronRight, TriangleAlert, Zap, Droplet, MapPin,
  } from '@lucide/svelte';

  const icons: Record<string, any> = {
    'log-in': LogIn, 'log-out': LogOut, map: Map, shield: Shield, 'circle-alert': CircleAlert,
    'badge-check': BadgeCheck, 'circle-x': CircleX, 'circle-arrow-up': CircleArrowUp, trophy: Trophy,
    'heart-crack': HeartCrack, plane: Plane, 'notebook-pen': NotebookPen, 'shield-check': ShieldCheck,
    sparkles: Sparkles, shirt: Shirt, backpack: Backpack, circle: Circle, users: Users, clock: Clock, coins: Coins,
    flame: Flame, 'book-open': BookOpen, 'refresh-cw': RefreshCw, 'folder-open': FolderOpen, search: Search,
    'chevron-left': ChevronLeft, crown: Crown, hourglass: Hourglass, 'paw-print': PawPrint,
    'heart-pulse': HeartPulse, swords: Swords, 'scroll-text': ScrollText, radio: Radio,
    'wand-sparkles': WandSparkles, house: House, chart: ChartColumn, archive: Archive, user: UserRound,
    castle: Castle, skull: Skull, pickaxe: Pickaxe, timer: Timer,
    'chevron-down': ChevronDown, 'chevron-right': ChevronRight, 'triangle-alert': TriangleAlert, zap: Zap,
    droplet: Droplet, 'map-pin': MapPin,
  };

  let { name, size = 16, color = 'currentColor', strokeWidth = 2 }: { name: string; size?: number; color?: string; strokeWidth?: number } = $props();
  const Comp = $derived(icons[name] ?? Circle);
</script>

<Comp {size} {color} {strokeWidth} />
