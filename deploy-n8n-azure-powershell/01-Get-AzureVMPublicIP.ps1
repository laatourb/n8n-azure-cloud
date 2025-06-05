[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName = "n8n",

    [Parameter(Mandatory=$true)]
    [string]$VMName = "n8n-VM"
)

# Get the public IP address
$publicIp = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name "$VMName-pip"

if ($publicIp) {
    Write-Host "L'adresse IP publique de votre VM est : $($publicIp.IpAddress)"
    Write-Host "Vous pouvez maintenant configurer votre domaine dans Cloudflare avec cette IP"
} else {
    Write-Error "Impossible de trouver l'IP publique pour la VM $VMName"
} 