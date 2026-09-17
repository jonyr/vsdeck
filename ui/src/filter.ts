import type { DeckAction } from './bridge';

export const ALL = 'Todas';

const normalize = (value: string) =>
  value.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

export function filterActions(actions: DeckAction[], query: string, category: string): DeckAction[] {
  const needle = normalize(query.trim());
  return actions.filter(action =>
    (category === ALL || action.category === category) &&
    normalize([action.title, action.subtitle, action.keywords].join(' ')).includes(needle));
}
