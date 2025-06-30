#!/bin/bash

# Configure local FireLens setup with your Honeycomb credentials
# Usage: ./configure-local-firelens.sh YOUR_API_KEY YOUR_DATASET

set -e

API_KEY=$1
DATASET=$2

if [ -z "$API_KEY" ] || [ -z "$DATASET" ]; then
    echo "Usage: $0 <api_key> <dataset_name>"
    echo "Example: $0 hcaik_01xyz... my-dataset"
    exit 1
fi

echo "Configuring local FireLens setup..."
echo "API Key: ${API_KEY:0:10}..."
echo "Dataset: $DATASET"

# Update the Fluent Bit configuration (using ECS-format with escaped JSON headers)
cp firelens-local-ecs-format.conf firelens-local-configured.conf
sed -i.bak "s/YOUR_API_KEY/$API_KEY/g" firelens-local-configured.conf
sed -i.bak "s/YOUR_DATASET_NAME/$DATASET/g" firelens-local-configured.conf

# Copy the simplified Docker Compose file (avoids Docker logging driver networking issues)
cp docker-compose-firelens-simple.yml docker-compose-firelens-configured.yml

echo "Configuration complete!"
echo ""
echo "The Fluent Bit configuration mirrors ECS FireLens logConfiguration:"
echo "  Name: http"
echo "  host: api.honeycomb.io" 
echo "  port: 443"
echo "  uri: /1/events/$DATASET"
echo "  format: json"
echo "  tls: on"
echo "  header: X-Honeycomb-Team $API_KEY"
echo "  header: X-Honeycomb-Dataset $DATASET"
echo "  header: Content-Type application/json"
echo ""
echo "Note: ECS uses JSON headers format: {\\\"X-Honeycomb-Team\\\":\\\"key\\\",...}"
echo "      Fluent Bit uses individual 'header' entries (same functionality)"
echo ""
echo "To start the local FireLens setup:"
echo "  docker-compose -f docker-compose-firelens-configured.yml up -d"
echo ""
echo "Note: This setup includes:"
echo "      - Forward input (port 24224) for ECS-like log forwarding"
echo "      - HTTP input (port 9880) for easy testing with curl"
echo "      - Dummy input for automatic test logs"
echo "      - Fluent Bit config identical to ECS FireLens"
echo ""
echo "To view logs:"
echo "  docker logs firelens-fluent-bit"
echo ""
echo "To check metrics:"
echo "  curl http://localhost:2020/api/v1/metrics/prometheus"
echo ""
echo "To test manually:"
echo "  curl -X POST -H 'Content-Type: application/json' \\"
echo "       -d '{\"level\":\"info\",\"message\":\"test from curl\"}' \\"
echo "       http://localhost:9880/manual"
echo ""
echo "Files created:"
echo "  - firelens-local-configured.conf"
echo "  - docker-compose-firelens-configured.yml"

# Clean up backup files
rm -f *.bak