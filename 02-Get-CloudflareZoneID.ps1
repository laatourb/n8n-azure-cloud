[CmdletBinding()]
param (
    [Parameter()]
    [string]$CloudflareEmail = $env:CLOUDFLARE_EMAIL,

    [Parameter()]
    [string]$CloudflareAPIKey = $env:CLOUDFLARE_API_KEY,

    [Parameter()]
    [string]$DomainName = $env:DOMAIN_NAME
)

# Vérification des variables d'environnement
if (-not $CloudflareEmail -or -not $CloudflareAPIKey -or -not $DomainName) {
    Write-Host "❌ Variables d'environnement manquantes. Veuillez configurer :" -ForegroundColor Red
    Write-Host "1. CLOUDFLARE_EMAIL" -ForegroundColor Yellow
    Write-Host "2. CLOUDFLARE_API_KEY" -ForegroundColor Yellow
    Write-Host "3. DOMAIN_NAME" -ForegroundColor Yellow
    Write-Host "`nVous pouvez les définir dans un fichier .env ou les passer en paramètres." -ForegroundColor Yellow
    exit 1
}

$headers = @{
    "X-Auth-Email" = $CloudflareEmail
    "X-Auth-Key" = $CloudflareAPIKey
    "Content-Type" = "application/json"
}

$uri = "https://api.cloudflare.com/client/v4/zones"

Write-Host "Recherche de la Zone ID pour $DomainName..." -ForegroundColor Yellow

try {
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
    if ($response.success) {
        $zone = $response.result | Where-Object { $_.name -eq $DomainName }
        if ($zone) {
            Write-Host "`n✅ Zone ID trouvée !" -ForegroundColor Green
            Write-Host "Zone ID : $($zone.id)" -ForegroundColor Green
            Write-Host "`nVous pouvez maintenant utiliser cette Zone ID dans le script Set-CloudflareDNS.ps1"
            # Sauvegarder la Zone ID dans une variable d'environnement
            $env:CLOUDFLARE_ZONE_ID = $zone.id
        } else {
            Write-Host "❌ Aucune zone trouvée pour le domaine $DomainName" -ForegroundColor Red
            Write-Host "Domaines disponibles :" -ForegroundColor Yellow
            $response.result | ForEach-Object {
                Write-Host "- $($_.name)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "❌ Erreur lors de la recherche de la Zone ID" -ForegroundColor Red
        Write-Host $response.errors
    }
} catch {
    Write-Host "❌ Erreur lors de la communication avec l'API Cloudflare" -ForegroundColor Red
    Write-Host "Message d'erreur : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nVérifiez que :" -ForegroundColor Yellow
    Write-Host "1. Votre email Cloudflare est correct" -ForegroundColor Yellow
    Write-Host "2. Votre clé API est valide" -ForegroundColor Yellow
    Write-Host "3. Votre domaine est bien enregistré dans Cloudflare" -ForegroundColor Yellow
}