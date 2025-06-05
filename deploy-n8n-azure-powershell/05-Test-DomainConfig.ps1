[CmdletBinding()]
param (
    [Parameter()]
    [string]$DomainName = $env:DOMAIN_NAME,

    [Parameter()]
    [string]$N8NSubdomain = $env:N8N_SUBDOMAIN,

    [Parameter()]
    [string]$PortainerSubdomain = $env:PORTAINER_SUBDOMAIN
)

# Vérification des variables d'environnement
if (-not $DomainName -or -not $N8NSubdomain -or -not $PortainerSubdomain) {
    Write-Host "❌ Variables d'environnement manquantes. Veuillez configurer :" -ForegroundColor Red
    Write-Host "1. DOMAIN_NAME" -ForegroundColor Yellow
    Write-Host "2. N8N_SUBDOMAIN" -ForegroundColor Yellow
    Write-Host "3. PORTAINER_SUBDOMAIN" -ForegroundColor Yellow
    Write-Host "`nVous pouvez les définir dans un fichier .env ou les passer en paramètres." -ForegroundColor Yellow
    exit 1
}

# Liste des domaines à tester
$domains = @(
    @{Name=$DomainName; Service="Main Domain"},
    @{Name="$N8NSubdomain.$DomainName"; Service="n8n"},
    @{Name="$PortainerSubdomain.$DomainName"; Service="Portainer"}
)

foreach ($domain in $domains) {
    Write-Host "`n=== Test pour $($domain.Name) ($($domain.Service)) ===" -ForegroundColor Cyan
    
    # Test DNS resolution
    Write-Host "`nTest de résolution DNS..." -ForegroundColor Yellow
    try {
        $dnsResult = Resolve-DnsName -Name $domain.Name -Type A
        Write-Host "✅ Résolution DNS : $($dnsResult.IPAddress)" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erreur de résolution DNS : $_" -ForegroundColor Red
    }

    # Test HTTP/HTTPS
    Write-Host "`nTest des connexions HTTP/HTTPS..." -ForegroundColor Yellow
    $protocols = @("http", "https")
    foreach ($protocol in $protocols) {
        try {
            $response = Invoke-WebRequest -Uri "$protocol`://$($domain.Name)" -Method Head -TimeoutSec 5
            Write-Host "✅ $protocol`://$($domain.Name) : $($response.StatusCode)" -ForegroundColor Green
            if ($protocol -eq "https") {
                Write-Host "   Certificat SSL : $($response.Headers['X-CF-RAY'])" -ForegroundColor Green
            }
        } catch {
            Write-Host "❌ $protocol`://$($domain.Name) : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== Résumé des tests ===" -ForegroundColor Cyan
Write-Host "1. Vérifiez que tous les domaines résolvent vers votre IP Azure" -ForegroundColor Yellow
Write-Host "2. Test des connexions HTTP/HTTPS..." -ForegroundColor Yellow