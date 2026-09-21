#!/bin/bash
# Bash 3.2. Explicit arguments; no credentials or instance defaults.
set -euo pipefail
export AWS_PAGER='' AWS_CLI_AUTO_PROMPT=off
fail() { printf '%s\n' "$1" >&2; exit 1; }
[ "$#" -ge 5 ] || fail 'Uso: script inspect|create AWS_BINARY PROFILE REGION INSTANCE [SNAPSHOT ACCOUNT]'
mode=$1; aws_bin=$2; profile=$3; region=$4; instance=$5
[[ "$aws_bin" = /* && -x "$aws_bin" ]] || fail 'AWS CLI no disponible.'
[[ "$profile" =~ ^[a-zA-Z0-9_-]+$ && "$region" =~ ^[a-z0-9-]+$ && "$instance" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]] || fail 'Destino no válido.'
aws_call() { "$aws_bin" --profile "$profile" --region "$region" --no-cli-pager --cli-connect-timeout 10 --cli-read-timeout 60 "$@"; }
account=$(aws_call sts get-caller-identity --query Account --output text 2>/dev/null) || fail 'No se pudo autenticar. Revisa el perfil o inicia sesión SSO desde la terminal.'
[[ "$account" =~ ^[0-9]{12}$ ]] || fail 'Cuenta AWS no válida.'
state=$(aws_call rds describe-db-instances --db-instance-identifier "$instance" --query 'DBInstances[0].[Engine,DBInstanceStatus]' --output text 2>/dev/null) || fail 'No se pudo consultar la instancia. Revisa región, identificador y permisos.'
read -r engine status <<< "$state"
[ "$engine" = postgres ] || fail 'La instancia no es PostgreSQL convencional; este script no maneja clusters Aurora.'
[[ "$status" = available || "$status" = storage-optimization ]] || fail "La instancia $instance no está disponible para snapshot (estado: $status). Espera a que esté disponible antes de reintentar."
if [ "$mode" = inspect ]; then printf '%s\n' "$account"; exit 0; fi
[ "$mode" = create ] && [ "$#" -eq 7 ] || fail 'Operación o argumentos no válidos.'
snapshot=$6; expected=$7
[ "$account" = "$expected" ] || fail 'La cuenta cambió desde la confirmación. Operación cancelada.'
[[ "$snapshot" =~ ^[a-zA-Z][a-zA-Z0-9-]+$ && "$snapshot" != *--* && "$snapshot" != *- && ${#snapshot} -le 255 ]] || fail 'Nombre de snapshot no válido.'
# No retry on create: a duplicate name or uncertain response needs manual inspection.
aws_call rds create-db-snapshot --db-instance-identifier "$instance" --db-snapshot-identifier "$snapshot" --query DBSnapshot.DBSnapshotIdentifier --output text >/dev/null 2>&1 || fail 'No se confirmó la creación. Revisa AWS antes de reintentar; puede existir ya un snapshot con ese nombre.'
printf 'Solicitado: %s. Esperando disponibilidad...\n' "$snapshot"
if ! aws_call rds wait db-snapshot-available --db-snapshot-identifier "$snapshot" >/dev/null 2>&1; then
  fail 'La espera terminó sin confirmar disponibilidad. El snapshot puede seguir creándose; revísalo en RDS. No se eliminó ni se volvió a crear.'
fi
final=$(aws_call rds describe-db-snapshots --db-snapshot-identifier "$snapshot" --query 'DBSnapshots[0].[DBInstanceIdentifier,Status]' --output text 2>/dev/null) || fail 'No se pudo verificar el estado final.'
read -r source status <<< "$final"
[[ "$source" = "$instance" && "$status" = available ]] || fail 'No se pudo verificar la disponibilidad del snapshot esperado.'
printf 'Disponible: %s\n' "$snapshot"
