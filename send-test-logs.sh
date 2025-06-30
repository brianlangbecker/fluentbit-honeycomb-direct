#!/bin/bash

# Script to send test log messages to Fluent Bit every minute
# Usage: ./send-test-logs.sh

echo "Starting test log sender - sending messages every 60 seconds"
echo "Press Ctrl+C to stop"

# Counter for message numbering
counter=1

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    message="Test log message #${counter} sent at ${timestamp}"
    
    echo "Sending: ${message}"
    
    # Send the message via Docker logging driver
    docker run --rm \
        --log-driver=fluentd \
        --log-opt fluentd-address=localhost:24224 \
        --log-opt tag=test.script \
        alpine echo "${message}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "✓ Message ${counter} sent successfully"
    else
        echo "✗ Failed to send message ${counter}"
    fi
    
    counter=$((counter + 1))
    
    # Wait 60 seconds
    sleep 60
done