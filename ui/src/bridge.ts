export type Mode = 'replace' | 'copy';

export interface DeckAction {
  id: string;
  title: string;
  badge: string;
  subtitle: string;
  keywords: string;
  category: string;
}

type Message = { type: 'close' } | { type: 'run'; id: string; mode: Mode };

declare global {
  interface Window {
    webkit?: { messageHandlers?: { deck?: { postMessage(body: Message): void } } };
  }
}

// Hammerspoon replaces the placeholder inside #deck-data with the catalog JSON.
// Outside Hammerspoon (npm run dev) the placeholder stays, so mock data is used.
export function getActions(): DeckAction[] {
  const text = document.getElementById('deck-data')?.textContent?.trim() ?? '';
  if (!text.startsWith('[')) return MOCK_ACTIONS;
  try {
    return JSON.parse(text) as DeckAction[];
  } catch {
    return [];
  }
}

export function send(message: Message): void {
  const handler = window.webkit?.messageHandlers?.deck;
  if (handler) handler.postMessage(message);
  else console.log('[deck]', message);
}

const MOCK_ACTIONS: DeckAction[] = [
  { id: 'text.translate', title: 'Traducir a ingles', badge: 'EN', subtitle: 'Traducir la selección', keywords: 'translate', category: 'Texto' },
  { id: 'text.fix', title: 'Corregir mismo idioma', badge: 'FIX', subtitle: 'Corregir ortografía', keywords: 'fix', category: 'Texto' },
  { id: 'window.left', title: 'Mitad izquierda', badge: '◧', subtitle: 'Organizar a la izquierda', keywords: 'ventana', category: 'Ventanas' },
  { id: 'window.right', title: 'Mitad derecha', badge: '◨', subtitle: 'Organizar a la derecha', keywords: 'ventana', category: 'Ventanas' },
  { id: 'window.maximize', title: 'Maximizar', badge: '↗', subtitle: 'Ocupar el área disponible', keywords: 'ventana', category: 'Ventanas' },
  { id: 'web.work', title: 'Trabajo · Safari', badge: 'Work', subtitle: 'safari · Work · 2 URL(s)', keywords: 'web', category: 'Web' },
  { id: 'task.snapshot', title: 'Snapshot trabajo', badge: 'RDS', subtitle: 'Crear snapshot', keywords: 'aws', category: 'Tareas' },
  { id: 'hue.desk', title: 'Escritorio', badge: 'HUE', subtitle: 'Alternar luz', keywords: 'luz', category: 'Luces' },
];
