#!/bin/bash

# Deploy ECS Task Definition and Service for Honeycomb FireLens integration
# Usage: ./deploy-ecs.sh [cluster-name] [service-name]

set -e

CLUSTER_NAME=${1:-"honeycomb-cluster"}
SERVICE_NAME=${2:-"honeycomb-firelens-service"}
TASK_FAMILY="honeycomb-firelens-task"

echo "Deploying ECS Task Definition and Service..."
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Task Family: $TASK_FAMILY"

# Check if required environment variables are set
if [ -z "$HONEYCOMB_API_KEY" ]; then
    echo "Error: HONEYCOMB_API_KEY environment variable is required"
    exit 1
fi

if [ -z "$HONEYCOMB_DATASET" ]; then
    echo "Error: HONEYCOMB_DATASET environment variable is required"
    exit 1
fi

# Replace placeholders in task definition
cp ecs-task-definition.json ecs-task-definition-deployed.json
sed -i "s/YOUR_API_KEY/$HONEYCOMB_API_KEY/g" ecs-task-definition-deployed.json
sed -i "s/YOUR_DATASET_NAME/$HONEYCOMB_DATASET/g" ecs-task-definition-deployed.json
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" ecs-task-definition-deployed.json

# Register task definition
echo "Registering ECS Task Definition..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file://ecs-task-definition-deployed.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

echo "Task Definition registered: $TASK_DEF_ARN"

# Check if service exists
if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --query 'services[0].serviceName' --output text 2>/dev/null | grep -q "$SERVICE_NAME"; then
    echo "Updating existing ECS Service..."
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --task-definition "$TASK_DEF_ARN" \
        --force-new-deployment
else
    echo "Creating new ECS Service..."
    # Replace placeholders in service definition
    cp ecs-service.json ecs-service-deployed.json
    sed -i "s/your-cluster-name/$CLUSTER_NAME/g" ecs-service-deployed.json
    sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" ecs-service-deployed.json
    
    aws ecs create-service --cli-input-json file://ecs-service-deployed.json
fi

echo "ECS deployment completed!"
echo "Monitor your service with:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"

# Clean up temporary files
rm -f ecs-task-definition-deployed.json ecs-service-deployed.json