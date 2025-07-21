# Krishi Mantra Backend

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

A scalable microservices architecture for an agriculture platform connecting farmers, fertilizer companies, and equipment providers. Built to support 10 lakh+ users with high availability and performance.

## Architecture Overview

![Architecture Diagram](https://i.ibb.co/3YdrcDy/krishi-mantra-architecture.png)

The backend system consists of the following microservices:

- **API Gateway**: Entry point for all client requests, handles routing, authentication verification, and request/response transformation
- **Main Service**: Core service for user management, authentication, and general platform functionality
- **Feed Service**: Manages content feeds, posts, and related interactions
- **Message Service**: Handles user-to-user messaging and communications
- **Notification Service**: Manages push notifications and alerts
- **Reel Service**: Handles short-form video content

## Key Features

- **Centralized Authentication**: Secure JWT-based authentication with token blacklisting
- **Redis Caching**: Improved performance with caching for frequently accessed data
- **Horizontal Scaling**: Services designed for horizontal scaling to handle increasing load
- **Circuit Breakers**: Prevent cascading failures across services
- **Structured Logging**: Comprehensive logging for monitoring and debugging
- **Health Checks**: Service health monitoring for high availability
- **Rate Limiting**: Protection against abuse and DoS attacks
- **Prometheus & Grafana**: Integrated metrics and monitoring
- **Docker & Kubernetes Ready**: Containerized for easy deployment

## Prerequisites

- Node.js 16+
- MongoDB 6.0+
- Redis 7.0+
- Docker & Docker Compose (for containerized deployment)

## Getting Started

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/krishi-mantra-backend.git
   cd krishi-mantra-backend
   ```

2. Create .env files:
   ```bash
   cp .env.example .env
   ```

3. Install dependencies for each service:
   ```bash
   # Example for one service
   cd main-service
   npm install
   ```

4. Start MongoDB and Redis (using Docker):
   ```bash
   docker-compose up -d mongodb redis
   ```

5. Run services in development mode:
   ```bash
   # In separate terminals
   cd api-gateway-service && npm run dev
   cd main-service && npm run dev
   cd feed-service && npm run dev
   # ... etc for other services
   ```

### Docker Deployment

Run all services with Docker Compose:

```bash
docker-compose up -d
```

Scale specific services:

```bash
docker-compose up -d --scale main-service=3 --scale feed-service=2
```

## Project Structure

```
├── api-gateway-service    # API Gateway
├── main-service           # Main service & authentication
├── feed-service           # Content feeds management
├── message-svc            # Messaging functionality
├── notification-service   # Push notifications
├── reel-service           # Short videos
├── Ms-setup               # Shared utilities and templates
├── monitoring             # Prometheus and Grafana configs
├── kubernetes             # Kubernetes manifests
├── docker-compose.yml     # Docker deployment config
├── .env.example           # Environment variables template
└── DEPLOYMENT.md          # Detailed deployment guide
```

## API Documentation

Each service exposes its own API documentation:

- API Gateway: `http://localhost:3001/docs`
- Main Service: `http://localhost:3002/docs`
- Feed Service: `http://localhost:3003/docs`

## Authentication Flow

1. User registers/logs in via Main Service
2. JWT token issued with user role and permissions
3. Token used for subsequent requests via API Gateway
4. API Gateway validates token and forwards to appropriate service
5. Services validate user permissions for specific actions

## Development Guidelines

- **Code Style**: Follow ESLint rules defined in each service
- **Commit Messages**: Use conventional commits format
- **API Design**: Follow RESTful principles with consistent response formats
- **Testing**: Write unit and integration tests for critical functionality
- **Documentation**: Document all API endpoints and configuration options

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## Deployment

For production deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 