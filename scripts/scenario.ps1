param(
    [Parameter(Mandatory = $true)][ValidateSet('A', 'B', 'C')][string]$Scenario,
    [switch]$Fix
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$ns = 'practica-s12'
function Invoke-Kube {
    param([string[]]$KubeArgs)
    & kubectl @KubeArgs
    if ($LASTEXITCODE -ne 0) { throw "kubectl fallo: $($KubeArgs -join ' ')" }
}
Invoke-Kube -KubeArgs @('config', 'current-context')
Invoke-Kube -KubeArgs @('get', 'namespace', $ns)
$state = if ($Fix) { 'fixed' } else { 'broken' }
switch ($Scenario) {
    'A' { $resource = 'configmap/s12-config'; $file = "a-config-$state.yaml" }
    'B' { $resource = 'service/db'; $file = "b-network-$state.yaml" }
    'C' { $resource = 'deployment/s12-app'; $file = "c-probes-$state.yaml" }
}
Invoke-Kube -KubeArgs @('patch', $resource, '-n', $ns, '--type=strategic', '--patch-file', (Join-Path $repoRoot "scenarios/$file"))
if ($Scenario -eq 'A') {
    # envFrom is resolved at Pod creation; changing a ConfigMap alone is insufficient.
    Invoke-Kube -KubeArgs @('rollout', 'restart', 'deployment/s12-app', '-n', $ns)
}
if ($Fix) {
    Invoke-Kube -KubeArgs @('rollout', 'status', 'deployment/s12-app', '-n', $ns, '--timeout=180s')
    # rollout status already waits for updated replicas to be available. A label-wide
    # Pod wait can capture old terminating Pods and time out after they disappear.
    Write-Host 'Correccion aplicada. Toma la captura DESPUES con Pods Ready y la consulta HTTP.'
} else {
    Write-Host 'Falla aplicada. Espera a observar el sintoma y toma la captura ANTES de corregir.'
    Write-Host 'En A/C el Pod anterior puede seguir Ready durante el rolling update. Captura tambien el Pod nuevo defectuoso.'
}
Invoke-Kube -KubeArgs @('get', 'pods', '-n', $ns)
