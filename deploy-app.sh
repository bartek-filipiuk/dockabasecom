#!/bin/bash

# Dockabase Application Deployment Script for Ubuntu 24.04
# This script deploys the Dockabase application with SSL support
# Can be run as a regular user (who is in the docker group)

# Exit on error
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Print colored message
print_message() {
  echo -e "${GREEN}[DOCKABASE]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if user is in docker group
if ! groups | grep -q '\bdocker\b'; then
  print_error "Current user is not in the docker group. Please run setup-system.sh first."
  print_error "After adding yourself to the docker group, log out and log back in before running this script."
  exit 1
fi

# Get domain name
if [ -z "$1" ]; then
  read -p "Enter your domain name (e.g., dockabase.com): " DOMAIN_NAME
else
  DOMAIN_NAME=$1
  print_message "Using domain: $DOMAIN_NAME"
fi

# Validate domain name format
if [[ ! $DOMAIN_NAME =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
  print_error "Invalid domain name format. Please use a valid domain (e.g., example.com)"
  exit 1
fi

# Check if email is provided for Let's Encrypt
if [ -z "$2" ]; then
  read -p "Enter your email address for Let's Encrypt notifications: " EMAIL
else
  EMAIL=$2
  print_message "Using email: $EMAIL"
fi

# Validate email format
if [[ ! $EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  print_error "Invalid email format. Please provide a valid email address"
  exit 1
fi

# Set project directory
PROJECT_DIR="/opt/dockabase"
print_message "Using project directory: $PROJECT_DIR"

# Check if project directory exists and is writable
if [ ! -d "$PROJECT_DIR" ]; then
  print_error "Project directory $PROJECT_DIR does not exist"
  print_error "Please run setup-system.sh first to create the directory"
  exit 1
fi

if [ ! -w "$PROJECT_DIR" ]; then
  print_error "Project directory $PROJECT_DIR is not writable by current user"
  print_error "Please run setup-system.sh first to set proper permissions"
  exit 1
fi

# Navigate to project directory
cd $PROJECT_DIR

# Check for skip-download flag
SKIP_DOWNLOAD=false
if [ "$1" == "--skip-download" ]; then
  SKIP_DOWNLOAD=true
  # Shift arguments so domain becomes $1 and email becomes $2
  shift
  DOMAIN_NAME=$1
  EMAIL=$2
fi

# Clone the repository or copy project files
if [ "$SKIP_DOWNLOAD" = false ]; then
  print_message "Checking for project files..."
  
  # Check if we're running from the project directory and can copy files
  SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
  if [ -f "$SCRIPT_DIR/Dockerfile" ] && [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    print_message "Found project files in script directory. Copying to $PROJECT_DIR..."
    
    # Create necessary directories
    mkdir -p $PROJECT_DIR/docker/nginx/certbot/conf
    mkdir -p $PROJECT_DIR/docker/nginx/certbot/www
    
    # Copy all project files to the deployment directory
    cp -r $SCRIPT_DIR/* $PROJECT_DIR/
    cp -r $SCRIPT_DIR/.* $PROJECT_DIR/ 2>/dev/null || true
    
    print_message "Project files copied successfully."
  else
    print_error "Project files not found in the script directory."
    print_message "Please copy all project files to $PROJECT_DIR manually, including:"
    print_message "- Dockerfile"
    print_message "- docker-compose.yml"
    print_message "- src/ directory"
    print_message "- package.json and other configuration files"
    print_message "Then run this script again with the --skip-download flag:"
    print_message "./deploy-app.sh --skip-download $DOMAIN_NAME $EMAIL"
    exit 1
  fi
else
  print_message "Skipping file download/copy as requested."
  
  # Check if necessary files exist
  if [ ! -f "$PROJECT_DIR/Dockerfile" ]; then
    print_error "Dockerfile not found in $PROJECT_DIR"
    print_error "Please make sure all project files are copied to $PROJECT_DIR"
    exit 1
  fi
  
  # Create necessary directories if they don't exist
  mkdir -p $PROJECT_DIR/docker/nginx/certbot/conf
  mkdir -p $PROJECT_DIR/docker/nginx/certbot/www
fi

# Update Nginx configuration with the correct domain name
print_message "Configuring Nginx for domain: $DOMAIN_NAME..."

# Check if we have an existing Nginx configuration template
if [ -f "$PROJECT_DIR/docker/nginx/default.conf.template" ]; then
  print_message "Found Nginx configuration template. Using it as base..."
  mkdir -p docker/nginx
  cp "$PROJECT_DIR/docker/nginx/default.conf.template" "$PROJECT_DIR/docker/nginx/default.conf"
  
  # Replace domain placeholders with actual domain
  sed -i "s/dockabase\.com/$DOMAIN_NAME/g" "$PROJECT_DIR/docker/nginx/default.conf"
  sed -i "s/www\.dockabase\.com/www.$DOMAIN_NAME/g" "$PROJECT_DIR/docker/nginx/default.conf"
  
  print_message "Nginx configuration updated with domain: $DOMAIN_NAME"
else
  # If no template exists, check for the default.conf file
  if [ -f "$PROJECT_DIR/docker/nginx/default.conf" ]; then
    print_message "Found existing Nginx configuration. Updating domain..."
    
    # Create a backup of the original file
    cp "$PROJECT_DIR/docker/nginx/default.conf" "$PROJECT_DIR/docker/nginx/default.conf.bak"
    
    # Replace domain in the existing file
    sed -i "s/server_name .*\$/server_name $DOMAIN_NAME www.$DOMAIN_NAME;/g" "$PROJECT_DIR/docker/nginx/default.conf"
    sed -i "s/ssl_certificate .*\/fullchain\.pem;/ssl_certificate \/etc\/letsencrypt\/live\/$DOMAIN_NAME\/fullchain.pem;/g" "$PROJECT_DIR/docker/nginx/default.conf"
    sed -i "s/ssl_certificate_key .*\/privkey\.pem;/ssl_certificate_key \/etc\/letsencrypt\/live\/$DOMAIN_NAME\/privkey.pem;/g" "$PROJECT_DIR/docker/nginx/default.conf"
    
    print_message "Existing Nginx configuration updated with domain: $DOMAIN_NAME"
  else
    print_message "No Nginx configuration found. Creating one with domain: $DOMAIN_NAME"
    mkdir -p docker/nginx
    
    # Create the Nginx configuration from scratch
    cat > docker/nginx/default.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    server_tokens off;

    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    server_tokens off;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # Diffie-Hellman parameter for DHE ciphersuites
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    # Intermediate configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (ngx_http_headers_module is required)
    add_header Strict-Transport-Security "max-age=63072000" always;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # Root directory and index files
    root /usr/share/nginx/html;
    index index.html;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Main location block
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF
  fi
fi

# Check for existing docker-compose.yml file
print_message "Checking Docker Compose configuration..."
if [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
  print_message "Found existing docker-compose.yml file. Using it..."
  
  # Check if we need to update any domain-specific settings in the docker-compose file
  # This is usually not necessary, but we could add it if needed
  
  print_message "Using existing Docker Compose configuration"
else
  print_message "No docker-compose.yml found. Creating one..."
  cat > docker-compose.yml << EOF
services:
  astro:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: dockabase-prod
    restart: unless-stopped
    networks:
      - dockabase-network

  nginx:
    image: nginx:alpine
    container_name: dockabase-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./dist:/usr/share/nginx/html
      - ./docker/nginx/certbot/conf:/etc/letsencrypt
      - ./docker/nginx/certbot/www:/var/www/certbot
    depends_on:
      - astro
    networks:
      - dockabase-network

  certbot:
    image: certbot/certbot
    container_name: dockabase-certbot
    volumes:
      - ./docker/nginx/certbot/conf:/etc/letsencrypt
      - ./docker/nginx/certbot/www:/var/www/certbot
    depends_on:
      - nginx
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"

networks:
  dockabase-network:
    driver: bridge
EOF
  print_message "Docker Compose configuration created"
fi

# Create initial SSL certificate
print_message "Preparing for SSL certificate generation..."
mkdir -p docker/nginx/certbot/conf
mkdir -p docker/nginx/certbot/www

# Start Nginx container for initial certificate generation
print_message "Starting Nginx container for SSL certificate generation..."
docker compose up -d nginx

# Wait for Nginx to start
sleep 5

# Generate SSL certificate with Let's Encrypt
print_message "Generating SSL certificate with Let's Encrypt..."
docker compose run --rm certbot certbot certonly --webroot --webroot-path=/var/www/certbot \
  --email $EMAIL --agree-tos --no-eff-email \
  -d $DOMAIN_NAME -d www.$DOMAIN_NAME

# Restart Nginx to apply SSL configuration
print_message "Restarting Nginx to apply SSL configuration..."
docker compose restart nginx

# Build and start all services
print_message "Building and starting all services..."
docker compose up -d --build

# Final message
print_message "Deployment completed successfully!"
print_message "Your Dockabase application is now running at https://$DOMAIN_NAME"
print_message "SSL certificates will be automatically renewed"

# Check if services are running
docker compose ps

print_message "To view logs, run: cd $PROJECT_DIR && docker compose logs -f"
