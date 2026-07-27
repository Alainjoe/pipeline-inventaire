# publier-v1.1.ps1 - Labo 2, etape 10 : construire et publier l'image api 1.1.
# Fichier volontairement en ASCII pur (PS 5.1 lit l'UTF-8 sans BOM en CP1252).
#
# Prerequis : Docker Desktop demarre + docker login effectue.
# Usage :
#   .\scripts\publier-v1.1.ps1                 # compte par defaut : ajc479
#   .\scripts\publier-v1.1.ps1 -Compte AUTRE -Tag 1.2

[CmdletBinding()]
param(
    [string]$Compte = "ajc479",
    [string]$Tag = "1.1"
)

$ErrorActionPreference = "Stop"
$racine = Split-Path -Parent $PSScriptRoot
$image = "$Compte/inventaire-api:$Tag"

Write-Host "Verification du daemon Docker..."
docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker n'est pas demarre. Ouvrir Docker Desktop puis relancer." }

Write-Host "Construction de $image ..."
docker build -t $image (Join-Path $racine "services\api")
if ($LASTEXITCODE -ne 0) { throw "docker build a echoue." }

docker tag $image "$Compte/inventaire-api:latest"

Write-Host "Publication sur Docker Hub..."
docker push $image
if ($LASTEXITCODE -ne 0) { throw "docker push a echoue (docker login fait ?)." }
docker push "$Compte/inventaire-api:latest"

Write-Host ""
docker images --filter "reference=$Compte/inventaire-api" `
    --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
Write-Host ""
Write-Host "Publie : $image"
Write-Host "Etape suivante : Render > Web Service > Settings > Image URL -> $image > Save Changes"
