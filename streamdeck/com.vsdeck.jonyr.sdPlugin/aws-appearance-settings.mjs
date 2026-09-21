export const defaultBackgroundColor = '#2563EB';
export function backgroundColor(value) {
  const color = typeof value === 'string' ? value.trim() : '';
  if (!color) return defaultBackgroundColor;
  if (!/^#[0-9a-f]{6}$/i.test(color)) throw new Error('backgroundColor');
  return color.toUpperCase();
}

export function iconColor(value) {
  const color = typeof value === 'string' ? value.trim() : '';
  if (!color) return '#FFFFFF';
  if (!/^#[0-9a-f]{6}$/i.test(color)) throw new Error('iconColor');
  return color.toUpperCase();
}
