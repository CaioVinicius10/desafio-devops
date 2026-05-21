# Exporta kubeconfig minimo apenas para docker-desktop (uso no secret KUBECONFIG do GitHub Actions)
# Uso: .\scripts\export-kubeconfig-docker-desktop.ps1

$ErrorActionPreference = "Stop"

$outDir = Join-Path $PSScriptRoot "..\k8s\deploy"
$outFile = Join-Path $outDir "kubeconfig.docker-desktop.yaml"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

kubectl config view --minify --context=docker-desktop --flatten -o yaml | Set-Content -Path $outFile -Encoding utf8

Write-Host "Arquivo gerado: $outFile"
Write-Host ""
Write-Host "Proximo passo — copiar para o secret KUBECONFIG no GitHub:"
Write-Host ""
$bytes = [IO.File]::ReadAllBytes((Resolve-Path $outFile))
$b64 = [Convert]::ToBase64String($bytes)
Write-Host "Cole em Settings > Secrets > KUBECONFIG:"
Write-Host $b64
