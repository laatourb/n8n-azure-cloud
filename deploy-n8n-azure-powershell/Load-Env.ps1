# Fonction pour charger les variables d'environnement depuis un fichier .env
function Import-EnvFile {
    param (
        [string]$Path = ".env"
    )

    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                [Environment]::SetEnvironmentVariable($name, $value, "Process")
            }
        }
        Write-Host "✅ Variables d'environnement chargées depuis $Path" -ForegroundColor Green
    } else {
        Write-Host "❌ Fichier $Path non trouvé" -ForegroundColor Red
        Write-Host "Veuillez créer un fichier .env basé sur .env.example" -ForegroundColor Yellow
        exit 1
    }
}

# Charger les variables d'environnement
Import-EnvFile