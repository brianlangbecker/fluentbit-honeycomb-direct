# Fluent Bit to Honeycomb Direct Integration

This project provides comprehensive Fluent Bit configurations for sending logs directly to Honeycomb using both modern OpenTelemetry and traditional HTTP approaches. Includes local testing setups that mirror AWS ECS FireLens deployments, with support for JSON and plaintext log formats.

## Configuration Options

Choose between **OpenTelemetry** (recommended) or **HTTP endpoint** approaches:

### OpenTelemetry Approach (Recommended)

Uses Honeycomb's OpenTelemetry API (`/v1/logs`) with native OTel output plugin.

#### Option 1: JSON Logs (OpenTelemetry)

**⚠️ Setup Required:** Edit `fluent-bit-json-otel.yaml` and replace `<Your API Key>` with your actual Honeycomb API key.

```bash
docker-compose -f docker-compose-json-otel.yml up -d
```

**Features:**

- Native OpenTelemetry support
- Full OTel resource attributes and instrumentation scope
- Trace context integration (trace_id, span_id)
- Uses `/v1/logs` OTel endpoint
- Future-proof observability standard

#### Option 2: Plaintext Logs (OpenTelemetry)

**⚠️ Setup Required:** Edit `fluent-bit-plaintext-otel.yaml` and replace `<Your API Key>` with your actual Honeycomb API key.

```bash
docker-compose -f docker-compose-plaintext-otel.yml up -d
```

**Features:**

- Native OpenTelemetry support
- Converts plaintext to OTel log format
- Full resource attributes and trace context
- Uses `/v1/logs` OTel endpoint

### HTTP Endpoint Approach

Uses Honeycomb's events API (`/1/events/`) with HTTP output plugin.

#### Option 3: JSON Logs (HTTP)

For applications that already emit structured JSON logs:

**⚠️ Setup Required:** Edit `fluent-bit-json.yaml` and replace `<Your API Key>` with your actual Honeycomb API key.

```bash
docker-compose -f docker-compose-json.yml up -d
```

**Features:**

- Parses existing JSON log fields
- Preserves all structured data
- Uses HTTP events endpoint
- OpenTelemetry field conventions

#### Option 4: Plaintext Logs (HTTP)

For legacy applications or simple text-based logs:

**⚠️ Setup Required:** Edit `fluent-bit-plaintext.yaml` and replace `<Your API Key>` with your actual Honeycomb API key.

```bash
docker-compose -f docker-compose-plaintext.yml up -d
```

**Features:**

- Converts plaintext logs to structured format
- Adds metadata fields and OpenTelemetry conventions
- Uses HTTP events endpoint

### Sample Log Formats

**OpenTelemetry Output (Recommended):**

```json
{
  "timestamp": "2024-01-01T12:00:00.000Z",
  "body": "User login successful",
  "severity_text": "INFO",
  "severity_number": 9,
  "resource": {
    "service.name": "api-service",
    "service.version": "1.0.0",
    "deployment.environment": "production",
    "cloud.region": "us-east-1"
  },
  "instrumentation_scope": {
    "name": "fluent-bit",
    "version": "3.0.0"
  },
  "trace_id": "1234567890abcdef1234567890abcdef",
  "span_id": "1234567890abcdef"
}
```

**HTTP Output (Simple):**

```json
{
  "date": "2024-01-01T12:00:00.000Z",
  "body": "User login successful",
  "severity": "info",
  "service.name": "api-service",
  "environment": "production",
  "version": "1.0.0",
  "team": "backend",
  "region": "us-east-1",
  "meta.signal.type": "log"
}
```

**Input Log Formats (both approaches support):**

**JSON Log Input:**
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "info",
  "service": "api-service",
  "message": "User login successful",
  "request_id": "abc-123",
  "user_id": 456
}
```

**Plaintext Log Input:**
```
INFO [2024-01-01 12:00:00] api-service: User login successful
```

## Key Features

### OpenTelemetry Approach (Recommended)

- **Native OTel support** with `/v1/logs` endpoint
- **Rich resource attributes** (service.name, deployment.environment, cloud.region)
- **Instrumentation scope** metadata (name, version)
- **Trace context integration** (trace_id, span_id, trace_flags)
- **Standardized severity** (both text and numeric values)
- **Future-proof observability** standards compliance
- **TLS encryption** for secure transmission
- **Automatic retry logic** with response logging

### HTTP Endpoint Approach

- **Simple HTTP integration** with `/1/events/` endpoint
- **OpenTelemetry field conventions** (body, severity, service.name)
- **Custom metadata fields** (environment, version, team, region)
- **Signal type classification** (meta.signal.type)
- **JSON lines format** for individual event sending
- **TLS encryption** for secure transmission
- **Hardcoded API keys** for reliable authentication
- **Debugging output** via stdout

## Monitoring

Fluent Bit exposes metrics on different ports depending on the setup:

### OpenTelemetry Setups
- **JSON OTel**: http://localhost:2022/api/v1/metrics/prometheus
- **Plaintext OTel**: http://localhost:2021/api/v1/metrics/prometheus

### HTTP Endpoint Setups
- **JSON & Plaintext HTTP**: http://localhost:2020/api/v1/metrics/prometheus

## Testing

Both setups include dummy inputs that automatically generate sample logs to verify the pipeline is working. You can verify they're working by:

### Start your chosen setup:

**OpenTelemetry setups:**
```bash
# For OpenTelemetry JSON setup
docker-compose -f docker-compose-json-otel.yml up -d

# For OpenTelemetry plaintext setup
docker-compose -f docker-compose-plaintext-otel.yml up -d
```

**HTTP endpoint setups:**
```bash
# For HTTP JSON setup
docker-compose -f docker-compose-json.yml up -d

# For HTTP plaintext setup
docker-compose -f docker-compose-plaintext.yml up -d
```

### Check Fluent Bit logs:

**OpenTelemetry setups:**
```bash
# For OpenTelemetry JSON setup
docker logs fluent-bit-otel-json

# For OpenTelemetry plaintext setup
docker logs fluent-bit-otel-plaintext
```

**HTTP endpoint setups:**
```bash
# For HTTP JSON setup
docker logs fluent-bit-honeycomb-json

# For HTTP plaintext setup
docker logs fluent-bit-honeycomb-plaintext
```

### Check Honeycomb metrics endpoint:

**OpenTelemetry setups:**
```bash
# For OpenTelemetry JSON setup (port 2022)
curl http://localhost:2022/api/v1/metrics/prometheus

# For OpenTelemetry plaintext setup (port 2021)
curl http://localhost:2021/api/v1/metrics/prometheus
```

**HTTP endpoint setups:**
```bash
# For HTTP setups (port 2020)
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

- Check your Honeycomb dataset for incoming events
- Look for fields like `date`, `service`, `level`, and `message`

## Cleanup

### Standard cleanup:

**OpenTelemetry setups:**
```bash
# For OpenTelemetry JSON setup
docker-compose -f docker-compose-json-otel.yml down

# For OpenTelemetry plaintext setup
docker-compose -f docker-compose-plaintext-otel.yml down
```

**HTTP endpoint setups:**
```bash
# For HTTP JSON setup
docker-compose -f docker-compose-json.yml down

# For HTTP plaintext setup
docker-compose -f docker-compose-plaintext.yml down
```

### Complete cleanup (stops, removes containers, networks, and volumes):

**OpenTelemetry setups:**
```bash
# For OpenTelemetry JSON setup
docker-compose -f docker-compose-json-otel.yml down --volumes --remove-orphans

# For OpenTelemetry plaintext setup
docker-compose -f docker-compose-plaintext-otel.yml down --volumes --remove-orphans
```

**HTTP endpoint setups:**
```bash
# For HTTP JSON setup
docker-compose -f docker-compose-json.yml down --volumes --remove-orphans

# For HTTP plaintext setup
docker-compose -f docker-compose-plaintext.yml down --volumes --remove-orphans
```

**Remove images (all setups):**
```bash
docker rmi fluent/fluent-bit:3.0 alpine:latest
```

### Force cleanup (if containers are stuck):

```bash
# Stop and remove all containers for this project
docker stop fluent-bit-otel-json fluent-bit-otel-plaintext fluent-bit-honeycomb-json fluent-bit-honeycomb-plaintext json-log-generator plaintext-log-generator 2>/dev/null || true
docker rm fluent-bit-otel-json fluent-bit-otel-plaintext fluent-bit-honeycomb-json fluent-bit-honeycomb-plaintext json-log-generator plaintext-log-generator 2>/dev/null || true

# Remove networks created by docker-compose
docker network rm fluentbit-honeycomb-direct_default 2>/dev/null || true
```

## File Structure

```
├── fluent-bit-json.yaml          # JSON log configuration
├── fluent-bit-plaintext.yaml     # Plaintext log configuration
├── fluent-bit.yaml               # Base configuration
├── docker-compose-json.yml       # JSON setup
├── docker-compose-plaintext.yml  # Plaintext setup
├── docker-compose-test.yml       # Minimal test setup
├── test-minimal.yaml             # Minimal Fluent Bit config
├── send-test-logs.sh             # Test script (1 minute intervals)
├── send-test-logs-fast.sh        # Test script (10 second intervals)
├── parsers.conf                  # Log parsers
├── .gitignore                    # Git ignore rules
└── README.md                     # This file
```

## Quick Start

### OpenTelemetry (Recommended)

- **JSON OTel Setup**: `docker-compose -f docker-compose-json-otel.yml up -d`
- **Plaintext OTel Setup**: `docker-compose -f docker-compose-plaintext-otel.yml up -d`

### HTTP Endpoint (Simple)

- **JSON Setup**: `docker-compose -f docker-compose-json.yml up -d`
- **Plaintext Setup**: `docker-compose -f docker-compose-plaintext.yml up -d`

### Other

- **Test Setup**: `docker-compose -f docker-compose-test.yml up -d`

### Port Assignments

- **HTTP JSON**: 2020 (metrics), 24224 (forward input)
- **HTTP Plaintext**: 2020 (metrics), 24224 (forward input)
- **OTel JSON**: 2022 (metrics), 24226 (forward input)
- **OTel Plaintext**: 2021 (metrics), 24225 (forward input)

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

3. **Authentication errors (401/403)**
   - Verify API key is correct in the YAML files
   - Check dataset name matches your Honeycomb setup

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
  interval_sec: 60 # Send every 60 seconds
```

**Custom message content:**

```yaml
- name: dummy
  dummy: '{"level":"info","service":"my-app","message":"Custom test message"}'
  tag: test.custom
```

> **Note:** The dummy input is useful for verifying your pipeline works. If you see these messages in Honeycomb, your configuration is working correctly! 🎉

Both configurations send data to Honeycomb in the same format, but handle input parsing differently.
