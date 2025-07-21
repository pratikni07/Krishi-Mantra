# Krishi Mantra Backend Deployment Guide

This document outlines the steps to deploy the Krishi Mantra microservices architecture for production environments.

## System Architecture

The system consists of multiple microservices:

1. **API Gateway** - Entry point for all client requests
2. **Main Service** - Core functionality and authentication
3. **Feed Service** - User feeds and content management
4. **Message Service** - User-to-user messaging
5. **Reel Service** - Short video content
6. **Notification Service** - Push notifications and alerts

All services are containerized with Docker and can be deployed using Docker Compose or Kubernetes.

## Prerequisites

- Docker and Docker Compose (for basic deployment)
- Kubernetes cluster (for advanced scaling)
- MongoDB (6.0+)
- Redis (7.0+)
- Node.js 16+ (for local development)

## Deployment Options

### Option 1: Docker Compose Deployment (Simplest)

Docker Compose is suitable for small to medium deployments.

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/krishi-mantra-backend.git
   cd krishi-mantra-backend
   ```

2. Create .env file from template:
   ```bash
   cp .env.example .env
   ```

3. Update .env with your production values:
   - Set `NODE_ENV=production`
   - Configure database credentials
   - Set JWT secrets
   - Configure service URLs and ports
   - Set proper CORS origins
   - Configure mail settings

4. Start the services:
   ```bash
   docker-compose up -d
   ```

5. Monitor logs:
   ```bash
   docker-compose logs -f
   ```

6. Scale services as needed:
   ```bash
   docker-compose up -d --scale main-service=3 --scale feed-service=3
   ```

### Option 2: Kubernetes Deployment (Advanced)

For larger scale deployments with high availability:

1. Build Docker images and push to registry:
   ```bash
   # Set your registry
   REGISTRY=your-registry.com
   
   # Build and push images
   for service in api-gateway-service main-service feed-service message-svc notification-service reel-service; do
     docker build -t $REGISTRY/$service:latest ./$service
     docker push $REGISTRY/$service:latest
   done
   ```

2. Apply Kubernetes manifests:
   ```bash
   # Create namespace
   kubectl create namespace krishi-mantra
   
   # Apply secrets
   kubectl apply -f kubernetes/secrets.yaml
   
   # Apply deployments and services
   kubectl apply -f kubernetes/deployments
   kubectl apply -f kubernetes/services
   ```

3. Configure ingress for API Gateway:
   ```bash
   kubectl apply -f kubernetes/ingress.yaml
   ```

4. Monitor the deployment:
   ```bash
   kubectl get pods -n krishi-mantra
   kubectl logs -f deployment/api-gateway -n krishi-mantra
   ```

## Database Setup

### MongoDB

1. For production, we recommend a MongoDB replica set:
   ```bash
   # Example for creating a replica set
   mongo --host mongodb:27017
   
   rs.initiate({
     _id: "krishi-rs",
     members: [
       { _id: 0, host: "mongodb-0.mongodb:27017" },
       { _id: 1, host: "mongodb-1.mongodb:27017" },
       { _id: 2, host: "mongodb-2.mongodb:27017" }
     ]
   })
   ```

2. Create databases for each service:
   ```
   use krishi-mantra-main
   use krishi-mantra-feed
   use krishi-mantra-messages
   use krishi-mantra-notifications
   use krishi-mantra-reels
   ```

3. Create users with appropriate permissions.

### Redis

1. For production, configure Redis with persistence and authentication.
2. For high availability, set up Redis Sentinel or Redis Cluster.

## Scaling Guidelines

To support 10 lakh+ users:

1. **Database Scaling**:
   - Use MongoDB sharding for horizontal scaling
   - Implement proper indexing strategies
   - Consider read replicas for read-heavy services

2. **Service Scaling**:
   - Scale stateless services horizontally (main-service, feed-service)
   - Monitor resource usage and scale based on metrics
   - Implement circuit breakers and rate limiting

3. **Caching Strategy**:
   - Cache user authentication data in Redis
   - Implement response caching for common requests
   - Use distributed rate limiting with Redis

4. **Monitoring**:
   - Set up alerts for service health
   - Monitor database performance
   - Track API response times

## Health Checks and Monitoring

- Each service exposes a `/health` endpoint
- Prometheus and Grafana are included for monitoring
- Configure alerts for service outages

## Backup Strategy

1. Set up regular MongoDB backups:
   ```bash
   mongodump --uri="mongodb://user:pass@host:port/db" --out=/path/to/backup
   ```

2. Schedule regular backup jobs:
   ```bash
   # Example cron job for daily backups
   0 2 * * * /usr/local/bin/mongodb-backup.sh
   ```

3. Test restoration process regularly.

## Troubleshooting

- Check service logs: `docker-compose logs -f <service-name>`
- Verify connectivity between services
- Check MongoDB and Redis connections
- Validate environment variables

## Security Considerations

1. **API Gateway**: 
   - Implement rate limiting
   - Set up proper CORS
   - Use HTTPS only

2. **Authentication**:
   - Rotate JWT secrets regularly
   - Implement token blacklisting
   - Use secure cookie settings

3. **Database**:
   - Restrict network access
   - Use strong passwords
   - Enable authentication

4. **General**:
   - Keep all packages updated
   - Apply security patches promptly
   - Implement proper logging (avoid sensitive data)

## Contact

For deployment assistance, contact the development team at:
- Email: support@krishimantra.com 