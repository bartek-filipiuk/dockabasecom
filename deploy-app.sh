#!/bin/bash

# Dockabase Application Deployment Script
# This script deploys and manages the Dockabase application with SSL support using Caddy
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
  configure_caddy
  start_containers
  
  print_message "Deployment completed successfully!"
  print_message "Your Dockabase application is now running at https://$DOMAIN_NAME"
  print_message "Caddy automatically handles SSL certificates and their renewal"
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
  # This function prepares the project files for Caddy deployment
  # It will be called by deploy_app
  
  # Check if user is in docker group
  if ! groups | grep -q '\bdocker\b'; then
    print_error "Current user is not in the docker group. Please run setup-system.sh first."
    print_error "After adding yourself to the docker group, log out and log back in before running this script."
    exit 1
  fi
  
  # Check if Dockerfile exists
  if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found in the current directory."
    print_error "Please make sure you are in the project directory."
    exit 1
  fi
  
  # Check if docker-compose.yml exists
  if [ ! -f "docker-compose.yml" ]; then
    print_message "docker-compose.yml not found. Creating one..."
    # This will be created by the configure_caddy function
  fi
  
  # Create dist directory if it doesn't exist
  if [ ! -d "dist" ]; then
    print_message "Creating dist directory..."
    mkdir -p dist
  fi
  
  # Check if we need to build the application
  if [ -f "package.json" ] && [ ! -f "dist/index.html" ]; then
    print_message "Building the application using Docker..."
    
    # Build the application inside a temporary Node container
    print_message "Running build in Docker container..."
    docker run --rm -v "$(pwd):/app" -w /app node:18 sh -c "npm install && npm run build"
    
    # Check if build was successful
    if [ ! -f "dist/index.html" ]; then
      print_error "Build failed. Check for errors above."
      exit 1
    fi
  fi
  
  print_message "File preparation completed"
}

configure_caddy() {
  # This function configures Caddy with the domain
  print_message "Configuring Caddy for domain: $DOMAIN_NAME..."

  # Create Caddyfile with domain configuration
  print_message "Creating Caddyfile for domain: $DOMAIN_NAME"
  cat > Caddyfile << EOF
{
    # Global settings
    email $EMAIL
    # Automatic HTTP to HTTPS redirection
    auto_https on
}

# Main domain configuration
$DOMAIN_NAME {
    # Static files directory
    root * /srv/www
    
    # Serve files
    file_server
    
    # Compression
    encode gzip
    
    # Redirect www to non-www
    redir www.$DOMAIN_NAME/* https://$DOMAIN_NAME{uri} permanent
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
    
    # SPA (Single Page Application) handling
    try_files {path} /index.html
    
    # Cache for static files
    @static {
        path *.css *.js *.ico *.gif *.jpg *.jpeg *.png *.svg *.woff *.woff2
    }
    header @static Cache-Control "public, max-age=31536000, immutable"
}
EOF

  print_message "Caddy configuration completed for domain: $DOMAIN_NAME"
}

# The prepare_files function has been updated to handle Caddy instead of Nginx

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

# Check if services are running
docker compose ps

print_message "To view logs, run: cd $PROJECT_DIR && docker compose logs -f"
