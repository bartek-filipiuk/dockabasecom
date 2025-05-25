#!/bin/bash

# Dockabase Application Deployment Script
# This script deploys and manages the Dockabase application with SSL support
# Can be run as a regular user (who is in the docker group)
#
# Usage:
#   ./deploy-app.sh deploy domain.com email@example.com  - Deploy application with SSL
#   ./deploy-app.sh start                               - Start containers
#   ./deploy-app.sh stop                                - Stop containers
#   ./deploy-app.sh restart                             - Restart containers
#   ./deploy-app.sh status                              - Show container status
#   ./deploy-app.sh logs                                - Show container logs

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

# Define functions for container management
deploy_app() {
  local domain=$1
  local email=$2
  
  # Validate domain name format
  if [[ ! $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid domain name format. Please use a valid domain (e.g., example.com)"
    exit 1
  fi

  # Validate email format
  if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid email format. Please provide a valid email address"
    exit 1
  fi
  
  print_message "Deploying application with domain: $domain and email: $email"
  
  # Set domain and email for later use
  DOMAIN_NAME=$domain
  EMAIL=$email
  
  # Continue with deployment process
  prepare_files
  configure_nginx
  generate_ssl_certificate
  start_containers
  
  print_message "Deployment completed successfully!"
  print_message "Your Dockabase application is now running at https://$DOMAIN_NAME"
  print_message "SSL certificates will be automatically renewed"
}

start_containers() {
  print_message "Starting containers..."
  docker compose up -d --build
  print_message "Containers started successfully"
  docker compose ps
}

stop_containers() {
  print_message "Stopping containers..."
  docker compose down
  print_message "Containers stopped successfully"
}

restart_containers() {
  print_message "Restarting containers..."
  docker compose restart
  print_message "Containers restarted successfully"
  docker compose ps
}

show_status() {
  print_message "Container status:"
  docker compose ps
}

show_logs() {
  print_message "Container logs:"
  docker compose logs
}

prepare_files() {
  # This function prepares the project files
  # It will be called by deploy_app
  
  # Check if user is in docker group
  if ! groups | grep -q '\bdocker\b'; then
    print_error "Current user is not in the docker group. Please run setup-system.sh first."
    print_error "After adding yourself to the docker group, log out and log back in before running this script."
    exit 1
  fi
  
  # Continue with file preparation
  # (This part will be implemented later)
}

configure_nginx() {
  # This function configures Nginx with the domain
  print_message "Configuring Nginx for domain: $DOMAIN_NAME..."

  # Check if we have an existing Nginx configuration template
  if [ -f "docker/nginx/default.conf.template" ]; then
    print_message "Found Nginx configuration template. Using it as base..."
    mkdir -p docker/nginx
    cp "docker/nginx/default.conf.template" "docker/nginx/default.conf"
    
    # Replace domain placeholders with actual domain
    sed -i "s/dockabase\.com/$DOMAIN_NAME/g" "docker/nginx/default.conf"
    sed -i "s/www\.dockabase\.com/www.$DOMAIN_NAME/g" "docker/nginx/default.conf"
    
    print_message "Nginx configuration updated with domain: $DOMAIN_NAME"
  else
    # If no template exists, check for the default.conf file
    if [ -f "docker/nginx/default.conf" ]; then
      print_message "Found existing Nginx configuration. Updating domain..."
      
      # Create a backup of the original file
      cp "docker/nginx/default.conf" "docker/nginx/default.conf.bak"
      
      # Replace domain in the existing file
      sed -i "s/server_name .*\$/server_name $DOMAIN_NAME www.$DOMAIN_NAME;/g" "docker/nginx/default.conf"
      sed -i "s/ssl_certificate .*\/fullchain\.pem;/ssl_certificate \/etc\/letsencrypt\/live\/$DOMAIN_NAME\/fullchain.pem;/g" "docker/nginx/default.conf"
      sed -i "s/ssl_certificate_key .*\/privkey\.pem;/ssl_certificate_key \/etc\/letsencrypt\/live\/$DOMAIN_NAME\/privkey.pem;/g" "docker/nginx/default.conf"
      
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
}

generate_ssl_certificate() {
  # This function generates SSL certificates using Let's Encrypt
  print_message "Generating SSL certificate for domain: $DOMAIN_NAME..."
  
  # Create necessary directories for certbot
  mkdir -p docker/nginx/certbot/conf
  mkdir -p docker/nginx/certbot/www
  
  # Create a temporary HTTP-only Nginx configuration
  print_message "Creating temporary HTTP-only Nginx configuration..."
  
  # Backup the original configuration if it exists
  if [ -f "docker/nginx/default.conf" ]; then
    cp docker/nginx/default.conf docker/nginx/default.conf.ssl.bak
  fi
  
  # Create HTTP-only configuration
  cat > docker/nginx/default.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    server_tokens off;

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Serve static content
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
  
  # Start Nginx container for initial certificate generation
  print_message "Starting Nginx container for SSL certificate generation..."
  docker compose up -d nginx
  
  # Wait for Nginx to start
  print_message "Waiting for Nginx to start..."
  sleep 5
  
  # Generate SSL certificate with Let's Encrypt
  print_message "Requesting certificate from Let's Encrypt..."
  docker compose run --rm certbot certbot certonly --webroot --webroot-path=/var/www/certbot \
    --email $EMAIL --agree-tos --no-eff-email \
    -d $DOMAIN_NAME -d www.$DOMAIN_NAME
  
  # Restore the original SSL configuration
  if [ -f "docker/nginx/default.conf.ssl.bak" ]; then
    print_message "Restoring SSL configuration..."
    cp docker/nginx/default.conf.ssl.bak docker/nginx/default.conf
  else
    # Create a new SSL configuration
    print_message "Creating SSL configuration..."
    configure_nginx
  fi
  
  # Restart Nginx to apply SSL configuration
  print_message "Restarting Nginx to apply SSL configuration..."
  docker compose restart nginx
  
  print_message "SSL certificate generated successfully"
}

# Parse command line arguments
COMMAND=${1:-"help"}
shift || true

case "$COMMAND" in
  deploy)
    if [ -z "$1" ] || [ -z "$2" ]; then
      print_error "Missing arguments for deploy command"
      print_message "Usage: ./deploy-app.sh deploy domain.com email@example.com"
      exit 1
    fi
    deploy_app "$1" "$2"
    ;;
  start)
    start_containers
    ;;
  stop)
    stop_containers
    ;;
  restart)
    restart_containers
    ;;
  status)
    show_status
    ;;
  logs)
    show_logs
    ;;
  help|*)
    print_message "Dockabase Application Management Script"
    print_message "Usage:"
    print_message "  ./deploy-app.sh deploy domain.com email@example.com  - Deploy application with SSL"
    print_message "  ./deploy-app.sh start                               - Start containers"
    print_message "  ./deploy-app.sh stop                                - Stop containers"
    print_message "  ./deploy-app.sh restart                             - Restart containers"
    print_message "  ./deploy-app.sh status                              - Show container status"
    print_message "  ./deploy-app.sh logs                                - Show container logs"
    exit 0
    ;;
esac

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
