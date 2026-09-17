import { describe, expect, it } from 'vitest';
import { filterActions } from './filter';
import type { DeckAction } from './bridge';

const action = (overrides: Partial<DeckAction>): DeckAction => ({
  id: 'x', title: '', badge: '', subtitle: '', keywords: '', category: 'Texto', ...overrides,
});

const actions = [
  action({ id: 'translate', title: 'Traducir a inglés', category: 'Texto' }),
  action({ id: 'left', title: 'Mitad izquierda', keywords: 'ventana pantalla', category: 'Ventanas' }),
  action({ id: 'web', title: 'Trabajo', subtitle: 'safari · Work', category: 'Web' }),
];

describe('filterActions', () => {
  it('returns every action for Todas and an empty query', () => {
    expect(filterActions(actions, '', 'Todas').map(a => a.id)).toEqual(['translate', 'left', 'web']);
  });

  it('restricts to the selected category', () => {
    expect(filterActions(actions, '', 'Ventanas').map(a => a.id)).toEqual(['left']);
  });

  it('matches title, subtitle and keywords ignoring accents and case', () => {
    expect(filterActions(actions, 'INGLES', 'Todas').map(a => a.id)).toEqual(['translate']);
    expect(filterActions(actions, 'pantalla', 'Todas').map(a => a.id)).toEqual(['left']);
    expect(filterActions(actions, 'safari', 'Todas').map(a => a.id)).toEqual(['web']);
  });

  it('trims the query and combines it with the category', () => {
    expect(filterActions(actions, '  trabajo ', 'Texto')).toEqual([]);
  });
});
