#!/usr/bin/env bash
set -euo pipefail
ns=practica-s12
kube() { sudo k3s kubectl "$@"; }
echo 'RECURSOS'
kube get pods,svc -n "$ns" -o wide
echo 'SERVICE DE BASE DE DATOS Y DESTINOS'
kube get service db -n "$ns" -o yaml
kube get endpointslices -n "$ns" -l kubernetes.io/service-name=db -o wide
while IFS= read -r pod; do
  [[ -n "$pod" ]] || continue
  echo "LOGS Y EVENTOS: $pod"
  kube logs "$pod" -n "$ns" --tail=50 --timestamps || true
  kube logs "$pod" -n "$ns" --previous --tail=30 --timestamps || true
  kube describe pod "$pod" -n "$ns"
done < <(kube get pods -n "$ns" -l app=s12-app -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
kube get events -n "$ns" --sort-by=.metadata.creationTimestamp
echo 'No se muestra el contenido del Secret.'
