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

# Check if user is in docker group
check_docker_permissions() {
  if ! groups | grep -q docker; then
    print_warning "You are not in the docker group. You may need to use sudo."
  fi
}

# Validate domain name format
validate_domain() {
  local domain=$1
  if [[ ! $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid domain name format. Please use a valid domain (e.g., example.com)"
    exit 1
  fi
}

# Validate email format
validate_email() {
  local email=$1
  if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    print_error "Invalid email format. Please provide a valid email address"
    exit 1
  fi
}

# Check required files
check_required_files() {
  # Check if Dockerfile exists
  if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found. Please make sure you are in the correct directory."
    exit 1
  fi
  
  # Check if docker-compose.yml exists
  if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please make sure you are in the correct directory."
    exit 1
  fi
  
  # Check if Caddyfile exists
  if [ ! -f "Caddyfile" ]; then
    print_error "Caddyfile not found. Please make sure you are in the correct directory."
    exit 1
  fi
}

# Start containers
start_containers() {
  print_message "Starting containers..."
  docker compose up -d --build
  print_message "Containers started successfully"
  docker compose ps
}

# Stop containers
stop_containers() {
  print_message "Stopping containers..."
  docker compose down
  print_message "Containers stopped successfully"
}

# Build application if needed
build_application() {
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
    docker run --rm -v "$(pwd):/app" -w /app node:22 sh -c "npm install && npm run build"
    
    # Check if build was successful
    if [ ! -f "dist/index.html" ]; then
      print_error "Build failed. Check for errors above."
      exit 1
    fi
    
    print_message "Application built successfully"
  else
    print_message "Application already built or does not require building"
  fi
}

# Update domain in Caddyfile
update_caddyfile() {
  local domain=$1
  local email=$2
  
  print_message "Updating Caddyfile for domain: $domain..."
  
  # Update email in Caddyfile
  sed -i "s/email .*/email $email/" Caddyfile
  
  # Update domain in Caddyfile
  sed -i "s/^[a-zA-Z0-9][a-zA-Z0-9.-]* {/$domain {/" Caddyfile
  
  # Update www redirect
  sed -i "s/redir www\.[a-zA-Z0-9][a-zA-Z0-9.-]*\//redir www.$domain\//" Caddyfile

  print_message "Caddyfile has been updated"
}

# Deploy the application
deploy_app() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    print_error "Missing arguments for deploy command"
    print_message "Usage: $0 deploy <domain_name> <email>"
    exit 1
  fi

  local domain=$1
  local email=$2

  # Validate domain and email
  validate_domain "$domain"
  validate_email "$email"

  # Check required files
  check_required_files
  
  # Build application
  build_application
  
  # Update Caddyfile
  update_caddyfile "$domain" "$email"

  # Start the application
  print_message "Starting the application..."
  docker compose up -d --build

  print_message "Deployment completed successfully!"
  print_message "Your application is now available at https://$domain"
  print_message "SSL certificates are automatically managed by Caddy"
}

# Start the application
start_app() {
  check_required_files
  print_message "Starting the application..."
  docker compose up -d
  print_message "Application started"
}

# Stop the application
stop_app() {
  print_message "Stopping the application..."
  docker compose down
  print_message "Application stopped"
}

# Restart the application
restart_app() {
  print_message "Restarting the application..."
  docker compose restart
  print_message "Application restarted"
}

# Show application status
show_status() {
  print_message "Application status:"
  docker compose ps
}

# Show application logs
show_logs() {
  print_message "Application logs:"
  docker compose logs -f
}

# Main function
main() {
  # Check Docker permissions
  check_docker_permissions

  # Process command
  case "$1" in
    deploy)
      deploy_app "$2" "$3"
      ;;
    start)
      start_app
      ;;
    stop)
      stop_app
      ;;
    restart)
      restart_app
      ;;
    status)
      show_status
      ;;
    logs)
      show_logs
      ;;
    *)
      print_message "Usage: $0 <command> [options]"
      print_message "Commands:"
      print_message "  deploy <domain_name> <email>  - Deploy the application"
      print_message "  start                        - Start the application"
      print_message "  stop                         - Stop the application"
      print_message "  restart                      - Restart the application"
      print_message "  status                       - Show application status"
      print_message "  logs                         - Show application logs"
      exit 1
      ;;
  esac
}

# Run the script
main "$@"
