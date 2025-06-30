# Fluent Bit to Honeycomb Direct Integration

This project demonstrates how to send logs directly from Fluent Bit to Honeycomb using the HTTP output plugin, similar to AWS FireLens configuration. Two configurations are provided for different log formats.

## Prerequisites

- Docker and Docker Compose
- Honeycomb API key and dataset name

## Setup

1. Copy the environment file and configure your credentials:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your Honeycomb credentials:
   ```
   HONEYCOMB_API_KEY=your_actual_api_key
   HONEYCOMB_DATASET=your_actual_dataset_name
   ```

## Configuration Options

### Option 1: JSON Logs (Structured)

For applications that already emit structured JSON logs:

```bash
docker-compose -f docker-compose-json.yml up -d
```

**Features:**
- Parses existing JSON log fields
- Preserves all structured data
- Ideal for microservices with structured logging

**Sample JSON log:**
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "info",
  "service": "api-service",
  "message": "User login successful",
  "request_id": "abc-123",
  "user_id": 456,
  "response_time": 0.045
}
```

### Option 2: Plaintext Logs (Unstructured)

For legacy applications or simple text-based logs:

```bash
docker-compose -f docker-compose-plaintext.yml up -d
```

**Features:**
- Converts plaintext logs to structured format
- Adds metadata fields (timestamp, service, level)
- Suitable for traditional log formats

**Sample plaintext log:**
```
INFO [2024-01-01 12:00:00] api-service: User login successful
```

## Configuration Details

Both setups include:
- **TLS enabled** for secure transmission to Honeycomb
- **ISO8601 timestamp format** with `_timestamp` field
- **Automatic headers** for Honeycomb Team API key
- **JSON formatting** for structured output to Honeycomb
- **Buffer management** for reliable log delivery

### JSON Configuration (`fluent-bit-json.yaml`)
- Uses JSON parser for structured log parsing
- Preserves all original fields
- Optimized for modern applications

### Plaintext Configuration (`fluent-bit-plaintext.yaml`)
- Converts unstructured logs to JSON
- Adds service metadata
- Uses modify and nest filters for field management

## Monitoring

Fluent Bit exposes metrics on http://localhost:2020

## Testing

Both setups include dummy inputs that automatically generate sample logs to verify the pipeline is working. You can verify they're working by:

### Check Fluent Bit logs:
```bash
# For JSON setup
docker logs fluent-bit-honeycomb-json

# For plaintext setup
docker logs fluent-bit-honeycomb-plaintext
```

### Check Honeycomb metrics endpoint:
```bash
curl http://localhost:2020/api/v1/metrics/prometheus
```

### Manual testing with Docker logging driver:
The Forward input (port 24224) expects Docker's logging driver format, not direct HTTP requests. 

#### Single test message:
```bash
# Create a test container that sends logs
docker run --rm --log-driver=fluentd --log-opt fluentd-address=localhost:24224 --log-opt tag=test.manual alpine echo "Test log message"
```

#### Automated test scripts:
```bash
# Send test messages every minute
./send-test-logs.sh

# Send test messages every 10 seconds (for faster testing)
./send-test-logs-fast.sh
```

The test scripts will:
- Create temporary Alpine containers with Fluent logging driver
- Send numbered test messages with timestamps
- Show success/failure status for each message
- Continue until stopped with Ctrl+C

#### Debugging minimal setup:
```bash
# Use minimal Fluent Bit config for testing
docker-compose -f docker-compose-test.yml up -d
docker logs -f fluent-bit-test
```

### Verify data in Honeycomb:
- Log into your Honeycomb account
- Navigate to your dataset
- Look for events with fields like `_timestamp`, `service`, `level`, and `message`

## Cleanup

### Standard cleanup:
```bash
# For JSON setup
docker-compose -f docker-compose-json.yml down

# For plaintext setup
docker-compose -f docker-compose-plaintext.yml down
```

### Complete cleanup (stops, removes containers, networks, and volumes):
```bash
# For JSON setup
docker-compose -f docker-compose-json.yml down --volumes --remove-orphans
docker rmi fluent/fluent-bit:3.0 alpine:latest

# For plaintext setup
docker-compose -f docker-compose-plaintext.yml down --volumes --remove-orphans
docker rmi fluent/fluent-bit:3.0 alpine:latest
```

### Force cleanup (if containers are stuck):
```bash
# Stop and remove all containers for this project
docker stop fluent-bit-honeycomb-json fluent-bit-honeycomb-plaintext json-log-generator plaintext-log-generator 2>/dev/null || true
docker rm fluent-bit-honeycomb-json fluent-bit-honeycomb-plaintext json-log-generator plaintext-log-generator 2>/dev/null || true

# Remove networks created by docker-compose
docker network rm fluentbit-honeycomb-direct_default 2>/dev/null || true
```

## File Structure

```
├── fluent-bit-json.yaml          # JSON log configuration
├── fluent-bit-plaintext.yaml     # Plaintext log configuration
├── fluent-bit-plaintext.yaml.template  # Template with env vars
├── docker-compose-json.yml       # JSON setup
├── docker-compose-plaintext.yml  # Plaintext setup
├── docker-compose-test.yml       # Minimal test setup
├── test-minimal.yaml             # Minimal Fluent Bit config
├── send-test-logs.sh             # Test script (1 minute intervals)
├── send-test-logs-fast.sh        # Test script (10 second intervals)
├── entrypoint.sh                 # Environment variable substitution
├── parsers.conf                  # Log parsers
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Which Setup Should I Use?

- **JSON Setup**: Use if your applications already emit structured JSON logs
- **Plaintext Setup**: Use for legacy applications or simple text-based logging
- **Test Setup**: Use for debugging Fluent Bit Forward input issues

## Troubleshooting

### Common Issues:

1. **Timeout connecting to localhost:24224**
   - Check if Fluent Bit container is running: `docker ps`
   - Check Fluent Bit logs: `docker logs fluent-bit-honeycomb-plaintext`
   - Verify port binding: `docker port fluent-bit-honeycomb-plaintext`

2. **No data reaching Honeycomb**
   - Use the stdout output to see what's being sent
   - Check for 400/401 errors in Fluent Bit logs
   - Verify API key and dataset are correct

3. **Environment variables not working**
   - Use the template approach with entrypoint.sh
   - Or hardcode values directly in the YAML file

### Debugging workflow:
1. Start with `docker-compose-test.yml` minimal setup
2. Use `send-test-logs-fast.sh` for rapid testing
3. Check `docker logs -f fluent-bit-test` for detailed output
4. Once working, switch to full plaintext or JSON setup

## Dummy Input Configuration

The configurations include a **dummy input** that automatically generates test messages every ~5 seconds:

```yaml
inputs:
  - name: dummy
    dummy: 'INFO [2024-01-01 12:00:00] plaintext-service: Sample plaintext log message'
    tag: plaintext.sample
```

**What you'll see in Honeycomb:**
```
date: 2025-06-30T18:27:29.353504Z
level: info
message: dummy
service: plaintext-service
```

### Controlling the Dummy Input:

**Stop dummy messages** (use only real logs):
```yaml
# Comment out or remove the dummy input
# - name: dummy
#   dummy: 'Sample message'
#   tag: plaintext.sample
```

**Change frequency** (default is ~5 seconds):
```yaml
- name: dummy
  dummy: 'Sample message'
  tag: plaintext.sample
  interval_sec: 60  # Send every 60 seconds
```

**Custom message content:**
```yaml
- name: dummy
  dummy: '{"level":"info","service":"my-app","message":"Custom test message"}'
  tag: test.custom
```

> **Note:** The dummy input is useful for verifying your pipeline works. If you see these messages in Honeycomb, your configuration is working correctly! 🎉

Both configurations send data to Honeycomb in the same format, but handle input parsing differently.