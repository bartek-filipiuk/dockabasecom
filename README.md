# Dockabase

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Astro](https://img.shields.io/badge/Astro-4.6.3-orange.svg)
![Tailwind CSS](https://img.shields.io/badge/Tailwind%20CSS-3.4.1-blue.svg)
![Node.js](https://img.shields.io/badge/Node.js-22-orange.svg)

Dockabase is an open-source project that enables developers to quickly set up and use the Qdrant vector database in a Docker container environment. This project provides a ready-to-use docker-compose.yml configuration, simple tutorials, and a set of useful commands.

## Features

- Pre-configured Docker setup for Qdrant vector database
- Simple and elegant documentation website
- Step-by-step tutorials for Qdrant API usage
- Troubleshooting guides and FAQ
- Deployment instructions including domain and SSL configuration

## Tech Stack

- **Frontend**: [Astro](https://astro.build/) v4.6.3 with [Tailwind CSS](https://tailwindcss.com/) v3.4.1 on [Node.js](https://nodejs.org/) v22
- **Content**: Markdown (MDX) with @astrojs/mdx
- **Containerization**: Docker and Docker Compose
- **Web Server**: Nginx
- **Hosting**: DigitalOcean VPS with Ubuntu
- **SSL**: Let's Encrypt
- **CI/CD**: GitHub Actions

## Development

### Prerequisites

- Docker and Docker Compose
- Git

### Local Development

1. Clone this repository
   ```bash
   git clone https://github.com/bartek-filipiuk/qdrant_caddy.git
   cd dockabase.com
   ```

2. Start the development environment with Docker
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

3. Open your browser and navigate to `http://localhost:3000` (Astro runs on port 4321 inside the container, but it's mapped to port 3000 on your host)

### Building for Production

```bash
docker-compose -f docker-compose.yml up --build
```

## Deployment

See the [Deployment documentation](https://dockabase.com/deployment) for detailed instructions on deploying to a VPS.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
