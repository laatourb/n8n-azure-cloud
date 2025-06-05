#!/bin/bash

# Chargement des variables d'environnement
if [ -f .env ]; then
    source .env
else
    echo "❌ Fichier .env non trouvé"
    echo "Veuillez créer un fichier .env basé sur .env.example"
    exit 1
fi

# Vérification des variables requises
required_vars=(
    "DOMAIN_NAME"
    "N8N_SUBDOMAIN"
    "PORTAINER_SUBDOMAIN"
    "POSTGRES_PASSWORD"
    "N8N_ENCRYPTION_KEY"
    "N8N_JWT_SECRET"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Variable $var manquante dans le fichier .env"
        exit 1
    fi
done

# Configuration des noms de domaine
N8N_DOMAIN="${N8N_SUBDOMAIN}.${DOMAIN_NAME}"
PORTAINER_DOMAIN="${PORTAINER_SUBDOMAIN}.${DOMAIN_NAME}"

# Install any updates
sudo apt update && sudo apt dist-upgrade && sudo apt upgrade -y

# Install Nginx
sudo apt install -y nginx

# Install docker
# Source https://docs.docker.com/engine/install/ubuntu/
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add the current user to the docker group
sudo usermod -aG docker $USER

# Enable Docker to start on boot
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# Création du répertoire pour les certificats
sudo mkdir -p /etc/nginx/ssl
sudo chmod 700 /etc/nginx/ssl

# Instructions pour les certificats
echo "Configuration des certificats Cloudflare :"
echo "1. Placez votre certificat client Cloudflare dans /etc/nginx/ssl/client.pem"
echo "2. Placez votre clé privée dans /etc/nginx/ssl/client.key"
echo "3. Assurez-vous que les fichiers ont les bonnes permissions :"
echo "   sudo chmod 600 /etc/nginx/ssl/client.*"
echo "   sudo chown root:root /etc/nginx/ssl/client.*"
echo ""
echo "Appuyez sur Entrée une fois que vous avez placé les certificats..."
read

# Configuration Nginx
sudo tee /etc/nginx/sites-available/n8n > /dev/null << EOF
server {
    listen 80;
    server_name ${N8N_DOMAIN} ${PORTAINER_DOMAIN};

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name ${N8N_DOMAIN};

    ssl_certificate /etc/nginx/ssl/client.pem;
    ssl_certificate_key /etc/nginx/ssl/client.key;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 443 ssl;
    server_name ${PORTAINER_DOMAIN};

    ssl_certificate /etc/nginx/ssl/client.pem;
    ssl_certificate_key /etc/nginx/ssl/client.key;

    location / {
        proxy_pass https://localhost:9443;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

###########################
# Install Portainer
# Source: https://docs.portainer.io/start/install-ce/server/docker/linux
###########################

docker volume create portainer_data
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

###########################
# Install the N8N Ai starter kit
# Source: https://github.com/n8n-io/self-hosted-ai-starter-kit
###########################

# Clone the Ai Starter kit repo
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit

# Configuration des variables d'environnement
cat > .env << EOF
POSTGRES_USER=root
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=n8n

WEBHOOK_URL=https://${N8N_DOMAIN}/

N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
N8N_USER_MANAGEMENT_JWT_SECRET=${N8N_JWT_SECRET}
N8N_DEFAULT_BINARY_DATA_MODE=filesystem
N8N_HOST=${N8N_DOMAIN}
N8N_PROTOCOL=https
N8N_PORT=5678
EOF

# Start the docker containers
docker compose --profile cpu up -d

echo "✅ Installation terminée !"
echo "📝 Accès aux services :"
echo "   - N8N : https://${N8N_DOMAIN}"
echo "   - Portainer : https://${PORTAINER_DOMAIN}"
echo ""
echo "🔒 Sécurité :"
echo "   - Les certificats SSL sont installés"
echo "   - Les services sont protégés par HTTPS"
echo ""
echo "📚 Documentation :"
echo "   - Consultez le README.md pour plus d'informations"
echo "   - Les logs sont disponibles dans /var/log/nginx/"