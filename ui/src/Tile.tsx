import type { DeckAction } from './bridge';
import { iconFor } from './icons';

interface Props {
  action: DeckAction;
  index: number;
  fired: boolean;
  onRun(action: DeckAction): void;
}

export function Tile({ action, index, fired, onRun }: Props) {
  const Icon = iconFor(action.category);
  return (
    <button
      className={fired ? 'tile fired' : 'tile'}
      data-category={action.category}
      title={action.subtitle}
      style={{ animationDelay: `${index * 25}ms` }}
      onClick={() => onRun(action)}
    >
      <span className="tile-head" aria-hidden="true">
        <span className="icon"><Icon size={18} strokeWidth={2} /></span>
        <span className="badge">{action.badge}</span>
      </span>
      <span className="title">{action.title}</span>
      <span className="subtitle">{action.subtitle}</span>
    </button>
  );
}
