import { AppWindow, Globe, Lightbulb, ListChecks, Sparkles, Zap, type LucideIcon } from 'lucide-react';

const byCategory: Record<string, LucideIcon> = {
  Texto: Sparkles,
  Ventanas: AppWindow,
  Web: Globe,
  Tareas: ListChecks,
  Luces: Lightbulb,
};

export const iconFor = (category: string): LucideIcon => byCategory[category] ?? Zap;
