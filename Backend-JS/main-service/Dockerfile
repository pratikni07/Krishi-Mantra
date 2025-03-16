FROM node:18-alpine as builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
ENV NODE_ENV=production

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app .

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3002

# Expose the application port
EXPOSE 3002

# Start the application
CMD ["npm", "start"] 