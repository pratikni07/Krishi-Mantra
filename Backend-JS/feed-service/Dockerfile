# API Gateway Dockerfile
FROM node:18-alpine as builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (production only)
RUN npm ci --only=production

# Copy application code
COPY . .

# Set environment variables
ENV NODE_ENV=production

# Use a smaller image for the final stage
FROM node:18-alpine

WORKDIR /app

# Copy node modules and app from builder stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app .

# Expose the port from .env.production
EXPOSE 3003

# Start the app in production mode
CMD ["npm", "start"]