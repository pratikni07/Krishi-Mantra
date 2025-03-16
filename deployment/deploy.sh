#!/bin/bash

# Create namespace
kubectl apply -f namespace.yaml

# Deploy infrastructure
kubectl apply -f redis/redis-deployment.yaml
kubectl apply -f redis/redis-service.yaml
kubectl apply -f rabbitmq/rabbitmq-secret.yaml
kubectl apply -f rabbitmq/rabbitmq-deployment.yaml
kubectl apply -f rabbitmq/rabbitmq-service.yaml

# Wait for infrastructure to be ready
echo "Waiting for infrastructure to be ready..."
sleep 30

# Deploy services in order
for service in api-gateway main-service feed-service message-service reel-service notification-service; do
  echo "Deploying $service..."
  kubectl apply -f $service/configmap.yaml
  kubectl apply -f $service/secret.yaml
  kubectl apply -f $service/deployment.yaml
  kubectl apply -f $service/service.yaml
  kubectl apply -f $service/hpa.yaml
  sleep 5
done

# Deploy ingress
kubectl apply -f ingress.yaml

echo "Deployment completed! Checking status..."
kubectl get pods -n microservices