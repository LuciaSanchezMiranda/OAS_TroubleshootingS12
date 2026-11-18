$ErrorActionPreference = 'Stop'
$ns = 'practica-s12'
Write-Host 'CONTEXTO Y RECURSOS'
kubectl config current-context
kubectl get pods,svc -n $ns -o wide
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron consultar los recursos.' }
Write-Host 'SERVICIO DE BASE DE DATOS Y DESTINOS'
kubectl get service db -n $ns -o yaml
kubectl get endpointslices -n $ns -l kubernetes.io/service-name=db -o wide
Write-Host 'PODS DE LA APLICACION: LOGS ACTUALES, ANTERIORES Y EVENTOS'
$podNames = kubectl get pods -n $ns -l app=s12-app -o jsonpath='{.items[*].metadata.name}'
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron consultar los Pods.' }
foreach ($podName in ($podNames -split '\s+' | Where-Object { $_ })) {
    Write-Host "--- $podName ---"
    kubectl logs $podName -n $ns --tail=50 --timestamps
    kubectl logs $podName -n $ns --previous --tail=30 --timestamps
    # --previous can report no previous container before the first restart. This is expected.
    kubectl describe pod $podName -n $ns
}
Write-Host 'ULTIMOS EVENTOS DEL NAMESPACE'
kubectl get events -n $ns --sort-by=.metadata.creationTimestamp
Write-Host 'Este script no imprime el contenido del Secret.'
