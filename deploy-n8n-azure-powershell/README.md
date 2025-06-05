# Déploiement N8N et Portainer sur Azure avec Cloudflare

Ce projet permet de déployer une infrastructure complète pour N8N et Portainer sur Azure, avec une configuration sécurisée via Cloudflare.

## Architecture

```
Client -> Cloudflare (SSL/TLS) -> Nginx (Proxy) -> Services (N8N/Portainer)
```

## Prérequis

- Un compte Azure
- Un compte Cloudflare
- Un domaine géré par Cloudflare
- Azure CLI installé
- PowerShell 7+

## Configuration initiale

### 1. Copier le fichier d'environnement
```bash
cp .env.example .env
```

### 2. Configurer les variables d'environnement
```bash
# Configuration Cloudflare
CLOUDFLARE_EMAIL=votre-email@example.com
CLOUDFLARE_API_KEY=votre-api-key
DOMAIN_NAME=votre-domaine

# Configuration des sous-domaines
N8N_SUBDOMAIN=n8n
PORTAINER_SUBDOMAIN=portainer

# Configuration de la base de données
POSTGRES_USER=root
POSTGRES_PASSWORD=votre-mot-de-passe-securise
POSTGRES_DB=n8n

# Configuration N8N
N8N_ENCRYPTION_KEY=votre-cle-encryption
N8N_JWT_SECRET=votre-jwt-secret
```

## Chargement des variables d'environnement

⚠️ **IMPORTANT** : Avant d'exécuter n'importe quel script PowerShell, vous devez d'abord charger les variables d'environnement :

```powershell
.\Load-Env.ps1
```

Cette commande doit être exécutée :
- Au début de chaque nouvelle session PowerShell
- Avant d'exécuter n'importe quel script du projet
- Si vous modifiez le fichier `.env`

## Guide de déploiement

### 1. Configuration Azure

#### 1.1 Création de la VM
```powershell
.\00-New-AzureUbuntuVM.ps1
```

#### 1.2 Récupération de l'IP
```powershell
.\01-Get-AzureVMPublicIP.ps1 -ResourceGroupName "n8n" -VMName "n8n-VM"
```

⚠️ **IMPORTANT** : Copiez l'IP affichée et ajoutez-la dans votre fichier `.env` :
```bash
AZURE_VM_IP=votre-ip-ici
```

### 2. Configuration Cloudflare

#### 2.1 Récupération de l'ID de zone
```powershell
.\02-Get-CloudflareZoneID.ps1
```

⚠️ **IMPORTANT** : Copiez l'ID de zone affiché et ajoutez-le dans votre fichier `.env` :
```bash
CLOUDFLARE_ZONE_ID=votre-zone-id-ici
```

#### 2.2 Configuration DNS
```powershell
.\03-Set-CloudflareDNS.ps1
```

#### 2.3 Configuration SSL/TLS
1. Dans Cloudflare :
   - SSL/TLS > Overview : Full (Strict)
   - SSL/TLS > Edge Certificates : Activer HTTPS
   - Rules > Transform Rules : HTTP vers HTTPS

### 3. Configuration de la VM

1. Copiez le script de configuration sur la VM :
```bash
scp 04-vm-config.sh .env azureuser@$AZURE_VM_IP:~/
```

2. Connectez-vous à la VM :
```bash
ssh azureuser@$AZURE_VM_IP
```

3. Rendez le script exécutable et lancez-le :
```bash
chmod +x 04-vm-config.sh
./04-vm-config.sh
```

4. Suivez les instructions affichées à l'écran pour finaliser la configuration.

### 4. Test de la configuration

#### 4.1 Test de la configuration DNS et HTTPS
```powershell
.\05-Test-DomainConfig.ps1 -DomainName "$DOMAIN_NAME"
```

Cette commande vérifiera :
- La résolution DNS des sous-domaines
- La configuration HTTPS
- La redirection HTTP vers HTTPS
- La validité des certificats SSL



## Maintenance

### Mise à jour des services

#### N8N
```bash
cd self-hosted-ai-starter-kit
docker compose pull
docker compose up -d
```

#### Portainer
```bash
docker pull portainer/portainer-ce:lts
docker stop portainer
docker rm portainer
docker run -d \
    --name=portainer \
    --restart=always \
    -p 8000:8000 \
    -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    -e EDGE=0 \
    -e EDGE_INSECURE_POLL=0 \
    -e EDGE_ASYNC=0 \
    portainer/portainer-ce:lts
```

### Monitoring

#### N8N
```bash
docker compose logs -f
```

#### Portainer
```bash
docker logs portainer
```

#### Nginx
```bash
sudo tail -f /var/log/nginx/access.log
```

## Sécurité

- SSL/TLS géré par Cloudflare
- Certificats client pour l'authentification
- Nginx comme proxy inverse
- Ports minimaux ouverts
- Isolation des services via Docker
- Variables d'environnement pour les secrets

## Support

Pour toute question ou problème :
1. Vérifier les logs
2. Consulter la documentation
3. Créer une issue sur le repository