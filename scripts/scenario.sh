#!/usr/bin/env bash
# Para ejecutar en la instancia Ubuntu con K3s: bash scripts/scenario.sh A [--fix]
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 || ! "$1" =~ ^[ABC]$ ]]; then
  echo 'Uso: bash scripts/scenario.sh A|B|C [--fix]' >&2
  exit 2
fi
state=broken
if [[ $# -eq 2 ]]; then
  if [[ "$2" != '--fix' ]]; then
    echo 'El segundo argumento debe ser --fix' >&2
    exit 2
  fi
  state=fixed
fi
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ns=practica-s12
kube() { sudo k3s kubectl "$@"; }
kube get namespace "$ns"
case "$1" in
  A) resource=configmap/s12-config; file="a-config-$state.yaml" ;;
  B) resource=service/db; file="b-network-$state.yaml" ;;
  C) resource=deployment/s12-app; file="c-probes-$state.yaml" ;;
esac
kube patch "$resource" -n "$ns" --type=strategic --patch-file "$repo_root/scenarios/$file"
if [[ "$1" == A ]]; then
  kube rollout restart deployment/s12-app -n "$ns"
fi
if [[ "$state" == fixed ]]; then
  kube rollout status deployment/s12-app -n "$ns" --timeout=180s
  echo 'Correccion aplicada. Espera a que desaparezcan Pods Terminating y toma captura DESPUES.'
else
  echo 'Falla aplicada. Observa el sintoma y toma captura ANTES de corregir.'
  echo 'En A/C puede coexistir el Pod anterior sano con el nuevo defectuoso.'
fi
kube get pods -n "$ns"
