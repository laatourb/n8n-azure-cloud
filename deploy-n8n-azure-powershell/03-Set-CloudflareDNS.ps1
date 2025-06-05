[CmdletBinding()]
param (
    [Parameter()]
    [string]$DomainName = $env:DOMAIN_NAME,

    [Parameter()]
    [string]$IPAddress = $env:AZURE_VM_IP,

    [Parameter()]
    [string]$N8NSubdomain = $env:N8N_SUBDOMAIN,

    [Parameter()]
    [string]$PortainerSubdomain = $env:PORTAINER_SUBDOMAIN,

    [Parameter()]
    [string]$CloudflareEmail = $env:CLOUDFLARE_EMAIL,

    [Parameter()]
    [string]$CloudflareAPIKey = $env:CLOUDFLARE_API_KEY,

    [Parameter()]
    [string]$CloudflareZoneID = $env:CLOUDFLARE_ZONE_ID
)

# Vérification des variables d'environnement
$requiredVars = @{
    "DOMAIN_NAME" = $DomainName
    "AZURE_VM_IP" = $IPAddress
    "CLOUDFLARE_EMAIL" = $CloudflareEmail
    "CLOUDFLARE_API_KEY" = $CloudflareAPIKey
    "CLOUDFLARE_ZONE_ID" = $CloudflareZoneID
}

$missingVars = $requiredVars.GetEnumerator() | Where-Object { -not $_.Value }
if ($missingVars) {
    Write-Host "❌ Variables d'environnement manquantes :" -ForegroundColor Red
    $missingVars | ForEach-Object {
        Write-Host "- $($_.Key)" -ForegroundColor Yellow
    }
    Write-Host "`nVous pouvez les définir dans un fichier .env ou les passer en paramètres." -ForegroundColor Yellow
    exit 1
}

$headers = @{
    "X-Auth-Email" = $CloudflareEmail
    "X-Auth-Key" = $CloudflareAPIKey
    "Content-Type" = "application/json"
}

# Liste des domaines à configurer
$domains = @(
    @{Name="@"; Type="A"; Content=$IPAddress},
    @{Name=$N8NSubdomain; Type="CNAME"; Content=$DomainName},
    @{Name=$PortainerSubdomain; Type="CNAME"; Content=$DomainName}
)

foreach ($domain in $domains) {
    $displayName = if ($domain.Name -eq "@") { $DomainName } else { "$($domain.Name).$DomainName" }
    
    $body = @{
        type = $domain.Type
        name = $domain.Name
        content = $domain.Content
        proxied = $false
        ttl = 1
    } | ConvertTo-Json

    $uri = "https://api.cloudflare.com/client/v4/zones/$CloudflareZoneID/dns_records"
    
    Write-Host "`nConfiguration de $displayName..." -ForegroundColor Yellow
    Write-Host "Type: $($domain.Type)" -ForegroundColor Yellow
    Write-Host "Content: $($domain.Content)" -ForegroundColor Yellow
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
        if ($response.success) {
            Write-Host "✅ Configuration réussie pour $displayName" -ForegroundColor Green
        } else {
            Write-Host "❌ Erreur lors de la configuration de $displayName" -ForegroundColor Red
            Write-Host "Détails de l'erreur :" -ForegroundColor Red
            $response.errors | ForEach-Object {
                Write-Host "- $($_.message)" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "❌ Erreur lors de la configuration de $displayName" -ForegroundColor Red
        Write-Host "Message d'erreur : $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) {
            Write-Host "Détails supplémentaires :" -ForegroundColor Red
            Write-Host $_.ErrorDetails.Message -ForegroundColor Red
        }
    }
}

Write-Host "`nConfiguration terminée."