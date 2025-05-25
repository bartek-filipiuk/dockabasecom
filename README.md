# Dockabase Website

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Astro](https://img.shields.io/badge/Astro-5.8.0-orange.svg)
![Tailwind CSS](https://img.shields.io/badge/Tailwind%20CSS-3.4.1-blue.svg)
![Node.js](https://img.shields.io/badge/Node.js-22-orange.svg)

This repository contains the source code for the Dockabase informational website. The site provides documentation, tutorials, and guides for using the Dockabase project, which helps developers set up and use the Qdrant vector database in a Docker environment.

## About This Repository

This is the website codebase only, not the actual Qdrant implementation. The Qdrant implementation can be found in a separate repository.

## Features

- Modern, responsive documentation website
- Dark theme with Tailwind CSS
- Step-by-step guides for Dockabase usage
- Deployment instructions for various environments
- FAQ and troubleshooting sections

## Tech Stack

- **Framework**: [Astro](https://astro.build/) v5.8.0
- **Styling**: [Tailwind CSS](https://tailwindcss.com/) v3.4.1
- **Content**: Markdown (MDX) with @astrojs/mdx v4.3.0
- **Runtime**: [Node.js](https://nodejs.org/) v22
- **Deployment**: Docker, Docker Compose, Caddy

## Development

### Prerequisites

- Node.js v22 or higher
- npm or yarn
- Docker and Docker Compose
- Git

### Local Development

#### Option 1: Native Development

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dockabase.com.git
   cd dockabase.com
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm run dev
   ```

4. Open your browser and visit `http://localhost:4321`

#### Option 2: Docker Development

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/dockabase.com.git
   cd dockabase.com
   ```

2. Start the development environment with Docker:
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

3. Open your browser and navigate to `http://localhost:3000` (Astro runs on port 4321 inside the container, but it's mapped to port 3000 on your host)

### Building for Production

#### Local Build

```bash
npm run build
```

The built site will be in the `dist/` directory.

#### Docker Production Build

```bash
docker-compose -f docker-compose.yml up --build
```

## Deployment

The website can be deployed to a VPS like DigitalOcean using the included Docker configuration. For security reasons, we've separated the deployment process into two scripts:

### 1. System Setup (as root)

First, run the `setup-system.sh` script as root to install system dependencies:

```bash
sudo ./setup-system.sh your-username
```

This script will:
- Install Docker and Docker Compose
- Add your user to the docker group
- Create necessary directories with proper permissions
- Configure firewall rules
- Set up automatic SSL certificate renewal

### 2. Creating a New User (Optional)

If you need to create a new user on your VPS, you can use these commands:

```bash
# Create a new user
sudo adduser username

# Add user to sudo group
sudo usermod -aG sudo username

# Add user to docker group
sudo usermod -aG docker username

# Verify the groups
groups username
```

After adding a user to the docker group, you need to log out and log back in for the changes to take effect.

### 3. Application Deployment (as regular user)

After setting up the system, log in as your regular user and run the `deploy-app.sh` script:

```bash
./deploy-app.sh yourdomain.com your@email.com
```

This script will:
- Configure Caddy with your domain
- Automatically handle SSL certificates (Caddy manages this for you)
- Deploy the Dockabase application

Your website will be accessible at `https://yourdomain.com`

For detailed deployment instructions, refer to the `deployment.md` file.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
