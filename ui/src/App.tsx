import { useEffect, useMemo, useRef, useState } from 'react';
import { X } from 'lucide-react';
import { getActions, send, type DeckAction, type Mode } from './bridge';
import { ALL, filterActions } from './filter';
import { Tile } from './Tile';

const CATEGORIES = [
  [ALL, 'Todas'], ['Texto', 'Texto e IA'], ['Ventanas', 'Ventanas'],
  ['Web', 'Web'], ['Tareas', 'Tareas'], ['Luces', 'Luces'],
] as const;
const COLUMNS = 4;

export function App() {
  const actions = useMemo(getActions, []);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<string>(ALL);
  const [mode, setMode] = useState<Mode>('replace');
  const [fired, setFired] = useState<string | null>(null);
  const visible = filterActions(actions, query, category);
  const locked = useRef(false);

  // Same 500 ms guard as the original panel against double dispatch.
  const run = (action: DeckAction) => {
    if (locked.current) return;
    locked.current = true;
    setFired(action.id);
    send({ type: 'run', id: action.id, mode });
    setTimeout(() => { locked.current = false; setFired(null); }, 500);
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { event.preventDefault(); send({ type: 'close' }); }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  const rows = Math.max(3, Math.ceil(visible.length / COLUMNS));

  return (
    <div className="deck">
      <header>
        <div>
          <h1>Tu Deck</h1>
          <p>Un lugar para tus acciones cotidianas.</p>
        </div>
        <button className="close" aria-label="Ocultar botonera" title="Ocultar (Esc)" onClick={() => send({ type: 'close' })}>
          <X size={18} />
        </button>
      </header>

      <div className="controls">
        <input
          type="search"
          placeholder="Buscar una acción…"
          aria-label="Buscar acción"
          autoFocus
          value={query}
          onChange={event => setQuery(event.target.value)}
          onKeyDown={event => { if (event.key === 'Enter' && visible[0]) run(visible[0]); }}
        />
        <select aria-label="Resultado de las acciones de texto" value={mode} onChange={event => setMode(event.target.value as Mode)}>
          <option value="replace">Texto: reemplazar selección</option>
          <option value="copy">Texto: copiar resultado</option>
        </select>
      </div>

      <nav aria-label="Categorías">
        {CATEGORIES.map(([value, label]) => (
          <button key={value} aria-pressed={category === value} onClick={() => setCategory(value)}>{label}</button>
        ))}
      </nav>

      {visible.length > 0 ? (
        <main className="grid" aria-label="Acciones" style={{ gridTemplateRows: `repeat(${rows}, minmax(0, 1fr))` }}>
          {visible.map((action, index) => (
            <Tile key={action.id} action={action} index={index} fired={fired === action.id} onRun={run} />
          ))}
        </main>
      ) : (
        <p className="empty">No hay acciones para esta búsqueda.</p>
      )}

      <footer>
        <span>{visible.length} acciones disponibles</span>
        <span>Esc · ocultar | Hyper + D · mostrar / ocultar</span>
      </footer>
    </div>
  );
}
