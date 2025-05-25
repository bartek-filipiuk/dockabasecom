#!/bin/bash

# Dockabase System Setup Script for Ubuntu 24.04
# This script installs Docker, Docker Compose, and sets up the environment
# Must be run as root

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

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  print_error "This script must be run as root (use sudo)"
  exit 1
fi

# Get username to add to docker group
if [ -z "$1" ]; then
  read -p "Enter the username to add to the docker group (your regular user): " USERNAME
else
  USERNAME=$1
  print_message "Using username: $USERNAME"
fi

# Validate that user exists
if ! id "$USERNAME" &>/dev/null; then
  print_error "User $USERNAME does not exist"
  exit 1
fi

# Update system packages
print_message "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
print_message "Installing required packages..."
apt-get install -y ca-certificates curl gnupg lsb-release git

# Install Docker
print_message "Installing Docker..."
if command -v docker &> /dev/null; then
  print_warning "Docker is already installed, skipping installation"
else
  # Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Add the repository to Apt sources
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  # Verify Docker installation
  docker --version
  if [ $? -ne 0 ]; then
    print_error "Docker installation failed"
    exit 1
  fi
  
  print_message "Docker installed successfully"
fi

# Add user to docker group
print_message "Adding user $USERNAME to the docker group..."
usermod -aG docker $USERNAME
print_message "User added to docker group. You'll need to log out and back in for this to take effect."

# Create project directory with proper permissions
PROJECT_DIR="/opt/dockabase"
print_message "Creating project directory at $PROJECT_DIR..."
mkdir -p $PROJECT_DIR
chown -R $USERNAME:$USERNAME $PROJECT_DIR

# Setup firewall rules
print_message "Setting up firewall rules..."
if command -v ufw &> /dev/null; then
  ufw allow 80/tcp
  ufw allow 443/tcp
  print_message "Firewall rules added for HTTP (80) and HTTPS (443)"
else
  print_warning "UFW not installed, skipping firewall configuration"
fi

# Setup automatic renewal of SSL certificates via cron
print_message "Setting up automatic SSL certificate renewal..."
cat > /etc/cron.weekly/certbot-renewal << EOF
#!/bin/bash
cd $PROJECT_DIR
docker compose run --rm certbot certbot renew
docker compose restart nginx
EOF

chmod +x /etc/cron.weekly/certbot-renewal
chown root:root /etc/cron.weekly/certbot-renewal

# Final message
print_message "System setup completed successfully!"
print_message "Now you can run the deploy-app.sh script as your regular user ($USERNAME)"
print_message "You may need to log out and log back in for the docker group membership to take effect"
