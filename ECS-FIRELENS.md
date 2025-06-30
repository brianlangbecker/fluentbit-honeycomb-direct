# ECS FireLens to Honeycomb Integration

This guide shows how to send logs from ECS containers directly to Honeycomb using AWS FireLens (Fluent Bit) integration.

## Overview

AWS FireLens allows you to route container logs to various destinations using Fluent Bit. This setup sends logs directly to Honeycomb's API without requiring intermediate infrastructure.

## Architecture

```
ECS Container → FireLens (Fluent Bit) → Honeycomb API
```

**Components:**
- **FireLens Container**: `amazon/aws-for-fluent-bit:stable`
- **Application Container**: Your app with `awsfirelens` log driver
- **Honeycomb Endpoint**: `api.honeycomb.io/1/events/{dataset}`

## Prerequisites

- AWS ECS cluster (Fargate or EC2)
- Honeycomb API key and dataset
- VPC with internet access or NAT gateway
- IAM roles with appropriate permissions

## Quick Start

### 1. Local Testing (Recommended)

Test the setup locally with **exact ECS FireLens configuration** before deploying to AWS:

```bash
# Configure local setup with your credentials (mirrors ECS exactly)
./configure-local-firelens.sh your_api_key_here your_dataset_name

# Start the local FireLens environment (identical to ECS)
docker-compose -f docker-compose-firelens-configured.yml up -d

# Check logs
docker logs firelens-fluent-bit

# View metrics
curl http://localhost:2020/api/v1/metrics/prometheus
```

**Why this approach?**
- Uses **identical Fluent Bit configuration** as ECS FireLens
- Same `logConfiguration` options format
- Same headers format with proper escaping
- Perfect for testing before AWS deployment

### 2. AWS Deployment

**⚠️ Note:** AWS deployment configurations have not been fully tested. The local testing setup has been verified to work with Honeycomb's API.

#### Option A: Using AWS CLI

```bash
# Set environment variables
export HONEYCOMB_API_KEY=your_api_key_here
export HONEYCOMB_DATASET=your_dataset_name

# Deploy using the script
./deploy-ecs.sh my-cluster my-service
```

#### Option B: Using Terraform

```bash
# Configure variables
terraform init
terraform plan -var="honeycomb_api_key=your_key" -var="honeycomb_dataset=your_dataset"
terraform apply
```

## Configuration Details

### ECS Task Definition

The task definition includes two containers:

**Important Note on Headers:** For reliability, use minimal headers in the ECS logConfiguration. The dataset name should be specified in the URI path, and Content-Type is automatically set by Fluent Bit.

**FireLens Container:**
```json
{
  "name": "firelens-fluent-bit",
  "image": "amazon/aws-for-fluent-bit:stable",
  "essential": true,
  "firelensConfiguration": {
    "type": "fluentbit",
    "options": {
      "enable-ecs-log-metadata": "true"
    }
  }
}
```

**Application Container:**
```json
{
  "name": "app-container",
  "image": "your-app:latest",
  "logConfiguration": {
    "logDriver": "awsfirelens",
    "options": {
      "Name": "http",
      "host": "api.honeycomb.io",
      "port": "443",
      "uri": "/1/events/YOUR_DATASET",
      "format": "json",
      "tls": "on",
      "headers": "{\"X-Honeycomb-Team\":\"YOUR_API_KEY\"}"
    }
  }
}
```

### Fluent Bit Configuration

The FireLens container uses this Fluent Bit configuration that **exactly mirrors** the ECS `logConfiguration` format:

```ini
[SERVICE]
    Flush         5
    Log_Level     info
    HTTP_Server   On
    HTTP_Port     2020

[INPUT]
    Name forward
    Listen 0.0.0.0
    Port 24224

[FILTER]
    Name modify
    Match *
    Add ecs_cluster ${ECS_CLUSTER}
    Add ecs_task_arn ${ECS_TASK_ARN}
    Add container_name ${CONTAINER_NAME}

# This OUTPUT section exactly mirrors the ECS logConfiguration options
[OUTPUT]
    Name http
    Match *
    host api.honeycomb.io
    port 443
    uri /1/events/${HONEYCOMB_DATASET}
    format json
    tls on
    json_date_key date
    json_date_format iso8601
    header X-Honeycomb-Team ${HONEYCOMB_API_KEY}
```

**Key Points:**
- Lowercase field names (`host`, `port`, `uri`) match ECS `logConfiguration` exactly
- Dataset specified in URI path: `/1/events/${HONEYCOMB_DATASET}`
- Minimal headers approach: only `X-Honeycomb-Team` needed
- Content-Type automatically set by Fluent Bit
- Same format works in both local testing and ECS deployment

## Environment Variables

Set these environment variables for the FireLens container:

| Variable | Description | Example |
|----------|-------------|---------|
| `HONEYCOMB_API_KEY` | Your Honeycomb API key | `<Your API Key>` |
| `HONEYCOMB_DATASET` | Target dataset name | `ecs-logs` |
| `ECS_SERVICE_NAME` | Auto-populated by ECS | `my-service` |
| `ECS_CLUSTER_NAME` | Auto-populated by ECS | `my-cluster` |
| `ECS_TASK_ARN` | Auto-populated by ECS | `arn:aws:ecs:...` |

## IAM Permissions

### Execution Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

### Task Role (Optional)

Add additional permissions if your application needs AWS services access.

## Log Format

### Input (from your application)
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "level": "info",
  "message": "User login successful",
  "user_id": "12345"
}
```

### Output (sent to Honeycomb)
```json
{
  "date": "2024-01-01T12:00:00.000Z",
  "level": "info",
  "message": "User login successful",
  "user_id": "12345",
  "service": "my-ecs-service",
  "cluster": "my-cluster",
  "task_arn": "arn:aws:ecs:us-east-1:123456789012:task/abc123",
  "container_name": "app-container",
  "ecs_cluster": "my-cluster",
  "ecs_task_arn": "arn:aws:ecs:us-east-1:123456789012:task/abc123"
}
```

## Monitoring

### Fluent Bit Metrics
Access metrics at: `http://task-ip:2020/api/v1/metrics/prometheus`

### CloudWatch Logs
FireLens container logs go to: `/ecs/firelens-fluent-bit`

### Honeycomb
Check your dataset for incoming events with ECS metadata.

## Header Configuration Best Practices

### Minimal Headers Approach (Recommended)

For maximum reliability in ECS FireLens, use minimal headers:

```json
{
  "logConfiguration": {
    "logDriver": "awsfirelens",
    "options": {
      "Name": "http",
      "host": "api.honeycomb.io",
      "port": "443",
      "uri": "/1/events/YOUR_DATASET_NAME",
      "format": "json",
      "tls": "on", 
      "headers": "{\"X-Honeycomb-Team\":\"YOUR_API_KEY\"}"
    }
  }
}
```

**Why this works:**
- **Dataset in URI**: `/1/events/YOUR_DATASET_NAME` eliminates need for `X-Honeycomb-Dataset` header
- **Auto Content-Type**: Fluent Bit automatically sets `Content-Type: application/json` when using `format: json`
- **Fewer escaping issues**: Single header reduces JSON escaping complexity
- **ECS compatibility**: Simpler header structure works across all ECS FireLens versions

### Multiple Headers (If Needed)

If you need multiple headers, ensure proper JSON escaping:

```json
"headers": "{\"X-Honeycomb-Team\":\"YOUR_API_KEY\",\"X-Custom-Header\":\"value\"}"
```

**Common issues with multiple headers:**
- JSON escaping errors (missing `\"`)
- ECS FireLens version compatibility
- Complex parsing in older AWS images

### Events Endpoint (Recommended)

**Use Events Endpoint Only:**
- URI: `/1/events/DATASET_NAME`
- Format: `json_lines` (individual JSON objects)
- Works reliably with Fluent Bit
- One HTTP request per log event

**Note:** The batch endpoint (`/1/batch/`) does not work reliably with Fluent Bit due to JSON array formatting requirements. Fluent Bit cannot natively create the JSON array structure that Honeycomb's batch API expects.

## Troubleshooting

### Common Issues

**1. No logs appearing in Honeycomb**
```bash
# Check FireLens container logs
aws ecs describe-tasks --cluster my-cluster --tasks task-id
docker logs container-id  # for local testing
```

**2. HTTP 401/403 errors**
- Verify API key is correct
- Check dataset name matches Honeycomb setup
- Ensure no extra spaces in headers

**3. HTTP 400 errors**
- Check JSON format is valid
- Verify timestamp format
- Review Fluent Bit output logs

**4. Container fails to start**
- Check IAM permissions
- Verify VPC has internet access
- Review task definition syntax

### Debug Commands

**Local testing:**
```bash
# Configure and start local FireLens (exact ECS format)
./configure-local-firelens.sh your_api_key your_dataset
docker-compose -f docker-compose-firelens-configured.yml up -d

# Check container status
docker-compose -f docker-compose-firelens-configured.yml ps

# View FireLens logs
docker logs firelens-fluent-bit

# Check metrics endpoint
curl http://localhost:2020/api/v1/metrics/prometheus

# Test with custom log message
docker exec log-generator echo '{"level":"info","message":"test log from local"}'
```

**AWS ECS:**
```bash
# Describe service
aws ecs describe-services --cluster my-cluster --services my-service

# Get task details
aws ecs list-tasks --cluster my-cluster --service-name my-service
aws ecs describe-tasks --cluster my-cluster --tasks task-arn

# View logs
aws logs get-log-events --log-group-name /ecs/firelens-fluent-bit --log-stream-name stream-name
```

## Best Practices

### Security
- Store API keys in AWS Secrets Manager or SSM Parameter Store
- Use least-privilege IAM policies
- Enable VPC Flow Logs for network debugging

### Performance
- Set appropriate CPU/memory for FireLens container (50-100 MB usually sufficient)
- Configure Fluent Bit storage for buffering during network issues
- Use retry logic for failed deliveries

### Monitoring
- Set up CloudWatch alarms for task failures
- Monitor Honeycomb ingestion rates
- Track Fluent Bit metrics for buffer usage

### Cost Optimization
- Use Fargate Spot for non-critical workloads
- Configure log retention policies
- Monitor data transfer costs

## Example Applications

### Web Application
```yaml
# docker-compose override for your app
services:
  web-app:
    image: nginx:latest
    logging:
      driver: fluentd
      options:
        fluentd-address: localhost:24224
        tag: ecs.web-app
```

### Background Worker
```yaml
services:
  worker:
    image: my-worker:latest
    logging:
      driver: fluentd
      options:
        fluentd-address: localhost:24224
        tag: ecs.worker
```

## Files Reference

| File | Purpose |
|------|---------|
| `ecs-task-definition.json` | ECS task definition template |
| `firelens-fluent-bit.conf` | Fluent Bit config for ECS (with env vars) |
| `firelens-local.conf` | Fluent Bit config for local testing (exact ECS format) |
| `ecs-service.json` | ECS service definition |
| `terraform-ecs.tf` | Infrastructure as code |
| `docker-compose-ecs.yml` | Basic local testing setup |
| `docker-compose-firelens-exact.yml` | Local setup with exact ECS format |
| `configure-local-firelens.sh` | Script to configure local setup with credentials |
| `deploy-ecs.sh` | Deployment automation script |

### Local vs ECS Files

**For Local Testing (Exact ECS Format):**
- `firelens-local.conf` - Mirrors ECS logConfiguration exactly
- `docker-compose-firelens-exact.yml` - Local FireLens setup
- `configure-local-firelens.sh` - Configure with your API key/dataset

**For ECS Deployment:**
- `firelens-fluent-bit.conf` - Uses environment variables
- `ecs-task-definition.json` - Full task definition
- `deploy-ecs.sh` - Automated deployment

## Next Steps

1. **Test locally with exact ECS format**:
   ```bash
   ./configure-local-firelens.sh your_api_key your_dataset
   docker-compose -f docker-compose-firelens-configured.yml up -d
   ```

2. **Verify logs in Honeycomb** from local testing

3. **Customize** the ECS task definition for your application

4. **Deploy** using Terraform or AWS CLI:
   ```bash
   ./deploy-ecs.sh my-cluster my-service
   ```

5. **Monitor** logs in Honeycomb and CloudWatch

6. **Scale** by adjusting desired count in service

## Configuration Compatibility

✅ **Perfect Match**: Local testing uses **identical** Fluent Bit configuration as ECS
✅ **Same Headers**: Proper JSON escaping works in both environments  
✅ **Same Options**: All `logConfiguration` options mirror exactly
✅ **Easy Transition**: Test locally → deploy to ECS with confidence

For questions or issues, refer to:
- [AWS FireLens Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/using_firelens.html)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [Honeycomb API Documentation](https://docs.honeycomb.io/api/)