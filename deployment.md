# Deployment Guide for Dockabase

This guide explains how to deploy Dockabase on a VPS (Virtual Private Server) like DigitalOcean with Ubuntu 24.04, including custom domain setup and SSL configuration.

## Prerequisites

- A VPS with Ubuntu 24.04 (e.g., DigitalOcean Droplet)
- A domain name pointing to your server's IP address
- SSH access to your server
- Basic knowledge of Linux command line

## Domain Configuration

Before deploying, make sure your domain is pointing to your server's IP address:

1. Log in to your domain registrar's website
2. Find the DNS management section
3. Create or update A records for your domain:
   - Create an A record for `@` or the root domain pointing to your server's IP address
   - Create an A record for `www` pointing to the same IP address
4. DNS changes may take up to 24-48 hours to propagate globally

## Automatic Installation

We've provided an installation script that automates the entire deployment process:

1. Connect to your server via SSH:
   ```bash
   ssh root@your-server-ip
   ```

2. Download the installation script:
   ```bash
   curl -O https://raw.githubusercontent.com/yourusername/dockabase/main/install.sh
   ```

   Alternatively, you can upload the script from your local machine:
   ```bash
   scp install.sh root@your-server-ip:/root/
   ```

3. Make the script executable:
   ```bash
   chmod +x install.sh
   ```

4. Run the installation script with your domain name and email:
   ```bash
   ./install.sh yourdomain.com your@email.com
   ```

   The script will:
   - Install Docker and Docker Compose
   - Configure Nginx with your domain
   - Set up SSL certificates with Let's Encrypt
   - Deploy the Dockabase application
   - Configure automatic SSL certificate renewal

5. After completion, your site should be accessible at `https://yourdomain.com`

## Manual Installation Steps

If you prefer to install manually or if the script encounters issues, follow these steps:

### 1. Install Docker and Docker Compose

```bash
# Update system packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y ca-certificates curl gnupg lsb-release git

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
```

### 2. Set Up Project Directory

```bash
# Create project directory
mkdir -p /opt/dockabase
cd /opt/dockabase

# Clone the repository or copy project files
git clone https://github.com/yourusername/dockabase.git .
# OR copy files from your local machine
# scp -r /path/to/local/dockabase/* root@your-server-ip:/opt/dockabase/
```

### 3. Configure Nginx for Your Domain

Create the Nginx configuration file:

```bash
mkdir -p docker/nginx/certbot/conf
mkdir -p docker/nginx/certbot/www

# Create Nginx configuration file
nano docker/nginx/default.conf
```

Copy the Nginx configuration template and replace `yourdomain.com` with your actual domain:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name yourdomain.com www.yourdomain.com;
    server_tokens off;

    # Redirect all HTTP requests to HTTPS
    location / {
        return 301 https://$host$request_uri;
    }

    # Let's Encrypt verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;
    server_tokens off;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
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
        try_files $uri $uri/ /index.html;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

### 4. Generate SSL Certificate

```bash
# Start Nginx for initial certificate generation
docker compose up -d nginx

# Generate SSL certificate
docker compose run --rm certbot certbot certonly --webroot --webroot-path=/var/www/certbot \
  --email your@email.com --agree-tos --no-eff-email \
  -d yourdomain.com -d www.yourdomain.com

# Restart Nginx to apply SSL configuration
docker compose restart nginx
```

### 5. Deploy the Application

```bash
# Build and start all services
docker compose up -d --build
```

### 6. Set Up Automatic SSL Certificate Renewal

```bash
# Create a weekly cron job for certificate renewal
cat > /etc/cron.weekly/certbot-renewal << EOF
#!/bin/bash
cd /opt/dockabase
docker compose run --rm certbot certbot renew
docker compose restart nginx
EOF

chmod +x /etc/cron.weekly/certbot-renewal
```

## Troubleshooting

### SSL Certificate Issues

If you encounter issues with SSL certificates:

1. Check that your domain is correctly pointing to your server's IP address:
   ```bash
   dig yourdomain.com
   ```

2. Verify that ports 80 and 443 are open on your server:
   ```bash
   ufw status
   ```

3. If needed, open these ports:
   ```bash
   ufw allow 80/tcp
   ufw allow 443/tcp
   ```

4. Check Certbot logs:
   ```bash
   docker compose logs certbot
   ```

### Application Not Loading

If the application doesn't load properly:

1. Check Docker container status:
   ```bash
   docker compose ps
   ```

2. View container logs:
   ```bash
   docker compose logs -f
   ```

3. Verify Nginx configuration:
   ```bash
   docker compose exec nginx nginx -t
   ```

## Updating the Application

To update the application:

1. Pull the latest changes:
   ```bash
   cd /opt/dockabase
   git pull
   ```

2. Rebuild and restart containers:
   ```bash
   docker compose down
   docker compose up -d --build
   ```

## Backup and Restore

### Backup

To backup your deployment:

1. Backup SSL certificates:
   ```bash
   tar -czf letsencrypt-backup.tar.gz -C /opt/dockabase/docker/nginx/certbot/conf .
   ```

2. Backup Docker Compose configuration:
   ```bash
   cp /opt/dockabase/docker-compose.yml docker-compose-backup.yml
   ```

### Restore

To restore from backup:

1. Restore SSL certificates:
   ```bash
   mkdir -p /opt/dockabase/docker/nginx/certbot/conf
   tar -xzf letsencrypt-backup.tar.gz -C /opt/dockabase/docker/nginx/certbot/conf
   ```

2. Restore Docker Compose configuration:
   ```bash
   cp docker-compose-backup.yml /opt/dockabase/docker-compose.yml
   ```

3. Restart services:
   ```bash
   cd /opt/dockabase
   docker compose up -d
   ```

## Security Considerations

- Consider setting up a firewall (UFW) to restrict access
- Regularly update your server and Docker images
- Monitor logs for suspicious activity
- Consider implementing rate limiting in Nginx for additional protection

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [DigitalOcean Documentation](https://docs.digitalocean.com/)
