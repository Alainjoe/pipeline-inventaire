# test-api-distante.ps1 - Labo 2 : valide une API deployee a distance.
#
# Usage (Codespace, partie A) :
#   .\scripts\test-api-distante.ps1 -BaseUrl https://xxxx-5000.app.github.dev -Reference CLOUD-001
# Usage (Render, partie B) :
#   .\scripts\test-api-distante.ps1 -BaseUrl https://inventaire-api-xxxx.onrender.com -Reference RENDER-001
#
# Compatible PowerShell 5.1 : on evite curl.exe + JSON (PS casse les quotes).
# Fichier volontairement en ASCII pur (PS 5.1 lit l'UTF-8 sans BOM en CP1252).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaseUrl,
    [string]$Reference = "CLOUD-001",
    [string]$Nom = "Article deploiement distant",
    [int]$Quantite = 5,
    [double]$PrixUnitaire = 9.99,
    [string]$SortieDir = "docs/preuves"
)

$ErrorActionPreference = "Stop"
$BaseUrl = $BaseUrl.TrimEnd('/')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $SortieDir)) { New-Item -ItemType Directory -Force $SortieDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $SortieDir "tests-$Reference-$stamp.txt"

function Write-Both([string]$texte) {
    Write-Host $texte
    Add-Content -Path $log -Value $texte -Encoding utf8
}

function Invoke-Etape([string]$titre, [scriptblock]$action) {
    Write-Both ""
    Write-Both "=== $titre ==="
    try {
        $r = & $action
        Write-Both ($r | ConvertTo-Json -Depth 6)
        return $r
    } catch {
        Write-Both "ECHEC : $($_.Exception.Message)"
        throw
    }
}

Write-Both "Cible   : $BaseUrl"
Write-Both "Date    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Both "Journal : $log"
Write-Both "Note    : sur Render (plan gratuit) la 1re requete peut prendre 30-60 s (cold start)."

# 1 - Sante du service
Invoke-Etape "1. GET /health" { Invoke-RestMethod "$BaseUrl/health" -TimeoutSec 120 } | Out-Null

# 2 - Liste initiale
$avant = Invoke-Etape "2. GET /articles (liste initiale)" {
    Invoke-RestMethod "$BaseUrl/articles" -TimeoutSec 120
}
Write-Both "Total avant POST : $($avant.total)"

# 3 - Creation (attendu : HTTP 201)
$corps = @{
    reference     = $Reference
    nom           = $Nom
    quantite      = $Quantite
    prix_unitaire = $PrixUnitaire
} | ConvertTo-Json -Compress
$octets = [System.Text.Encoding]::UTF8.GetBytes($corps)

Write-Both ""
Write-Both "=== 3. POST /articles ($Reference) ==="
try {
    $rep = Invoke-WebRequest "$BaseUrl/articles" -Method Post `
        -ContentType "application/json; charset=utf-8" -Body $octets -TimeoutSec 120
    Write-Both "HTTP $([int]$rep.StatusCode) $($rep.StatusDescription)"
    Write-Both $rep.Content
} catch {
    $code = 0
    if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
    if ($code -eq 409) {
        Write-Both "HTTP 409 : $Reference existe deja (POST rejoue). On continue."
    } else {
        Write-Both "ECHEC POST : $($_.Exception.Message)"
        throw
    }
}

# 4 - Verification de la presence
$apres = Invoke-Etape "4. GET /articles (verification)" {
    Invoke-RestMethod "$BaseUrl/articles" -TimeoutSec 120
}
$trouve = $apres.articles | Where-Object { $_.reference -eq $Reference }
if ($trouve) {
    Write-Both "OK : $Reference present (id=$($trouve.id)). Total : $($apres.total)"
} else {
    Write-Both "ECHEC : $Reference absent de la liste."
    exit 1
}

# 5 - Statistiques
Invoke-Etape "5. GET /stats" { Invoke-RestMethod "$BaseUrl/stats" -TimeoutSec 120 } | Out-Null

# 6 - Version de l'image (etape 10 du labo)
try {
    Invoke-Etape "6. GET /version" { Invoke-RestMethod "$BaseUrl/version" -TimeoutSec 120 } | Out-Null
} catch {
    Write-Both "Route /version absente : image 1.0 encore deployee (normal avant l'etape 10)."
}

Write-Both ""
Write-Both "TERMINE. Journal complet : $log"
