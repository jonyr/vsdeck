#!/bin/bash
# Adapter protocol only; deployment remains owned by each repository's script.
set -euo pipefail
if [ "${1:-}" = '--describe' ] && [ "$#" -eq 1 ]; then
  printf '%s\n' '{"version":1,"inputs":[{"name":"app","label":"Aplicación","type":"select","options":[{"value":"backend","label":"Backend"},{"value":"frontend","label":"Frontend"}]}]}'
  exit 0
fi
if [ "$#" -ne 3 ] || [ "$1" != '--run' ] || [ "$2" != '--app' ]; then
  printf '%s\n' 'Uso: --describe | --run --app backend|frontend' >&2
  exit 2
fi
case "$3" in
  backend) repo="${VSDECK_SALES_BACKEND:-}" ;;
  frontend) repo="${VSDECK_SALES_FRONTEND:-}" ;;
  *) printf '%s\n' 'Aplicación inválida' >&2; exit 2 ;;
esac
if [ -z "$repo" ] || [ ! -d "$repo" ]; then
  printf '%s\n' 'Falta configurar el repositorio de Sales' >&2; exit 2
fi
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes}"
cd "$repo"
if [ ! -x ./deploy-sales.sh ]; then
  printf '%s\n' 'No existe deploy-sales.sh o no es ejecutable' >&2; exit 2
fi
printf '%s\n' 'VSDECK_EVENT {"type":"progress","message":"Verificando repositorio"}'
status=$(git status --porcelain)
if [ -n "$status" ]; then
  printf '%s\n' 'El repositorio tiene cambios locales; revisarlos antes de publicar el tag.' >&2; exit 1
fi
printf '%s\n' 'VSDECK_EVENT {"type":"progress","message":"Ejecutando deploy-sales.sh"}'
./deploy-sales.sh
printf '%s\n' 'VSDECK_EVENT {"type":"result","message":"Tag sales publicado"}'
