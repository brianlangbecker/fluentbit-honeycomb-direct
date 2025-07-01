#!/bin/bash

# Configure local OpenTelemetry FireLens setup with your Honeycomb credentials
# Usage: ./configure-local-firelens-otel.sh YOUR_API_KEY YOUR_DATASET

set -e

API_KEY=$1
DATASET=$2

if [ -z "$API_KEY" ] || [ -z "$DATASET" ]; then
    echo "Usage: $0 <api_key> <dataset_name>"
    echo "Example: $0 <your-api-key> my-otel-dataset"
    exit 1
fi

echo "Configuring local OpenTelemetry FireLens setup..."
echo "API Key: ${API_KEY:0:6}..."
echo "Dataset: $DATASET"

# Update the Fluent Bit configuration (using OpenTelemetry format)
cp firelens-local-otel.conf firelens-local-otel-configured.conf
sed -i.bak "s/YOUR_API_KEY/$API_KEY/g" firelens-local-otel-configured.conf
sed -i.bak "s/YOUR_DATASET_NAME/$DATASET/g" firelens-local-otel-configured.conf

# Copy the Docker Compose file
cp docker-compose-firelens-otel.yml docker-compose-firelens-otel-configured.yml

echo "Configuration complete!"
echo ""
echo "The OpenTelemetry FireLens configuration includes:"
echo "  Native OpenTelemetry output plugin"
echo "  Endpoint: /v1/logs (OpenTelemetry standard)"
echo "  Resource attributes: service.name, deployment.environment, cloud.region"
echo "  Instrumentation scope: fluent-bit-firelens v3.0.0"
echo "  Trace context: trace_id, span_id, trace_flags"
echo "  ECS metadata simulation"
echo ""
echo "Ports:"
echo "  Forward input: 24227"
echo "  HTTP input: 9881"
echo "  Metrics: 2023"
echo ""
echo "To start the local OpenTelemetry FireLens setup:"
echo "  docker-compose -f docker-compose-firelens-otel-configured.yml up -d"
echo ""
echo "Note: This setup includes:"
echo "      - Forward input (port 24227) for ECS-like log forwarding"
echo "      - HTTP input (port 9881) for easy testing with curl"
echo "      - Dummy input for automatic test logs"
echo "      - OpenTelemetry native output with full resource attributes"
echo "      - Trace context integration"
echo ""
echo "To view logs:"
echo "  docker logs fluent-bit-otel-firelens"
echo ""
echo "To check metrics:"
echo "  curl http://localhost:2023/api/v1/metrics/prometheus"
echo ""
echo "To test manually:"
echo "  curl -X POST -H 'Content-Type: application/json' \\\\"
echo "       -d '{\\\"log\\\":\\\"INFO [2024-01-01 12:00:00] test-service: Manual test log\\\"}' \\\\"
echo "       http://localhost:9881/manual"
echo ""
echo "Files created:"
echo "  - firelens-local-otel-configured.conf"
echo "  - docker-compose-firelens-otel-configured.yml"

# Clean up backup files
rm -f *.bak