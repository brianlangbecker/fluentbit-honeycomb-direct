# AWS Quick Test Setup - ECS Fargate with Minimal Config

⚠️ **WARNING: This AWS deployment guide has not been fully tested. Use at your own risk and verify all configurations before deploying to production.**

This guide shows you how to create the simplest working setup to test Fluent Bit → Honeycomb integration using AWS ECS Fargate and the AWS Console (clickops).

## Prerequisites

- AWS Account with ECS access
- Honeycomb API key and dataset name
- Basic familiarity with AWS Console

## Step 1: Create ECS Cluster

1. **Go to ECS Console**: https://console.aws.amazon.com/ecs/
2. Click **"Clusters"** in left sidebar
3. Click **"Create Cluster"**
4. **Cluster template**: Select **"Networking only (Powered by AWS Fargate)"**
5. **Cluster name**: `honeycomb-test`
6. Click **"Create"**

## Step 2: Create Task Definition

1. In ECS Console, click **"Task Definitions"** → **"Create new Task Definition"**
2. **Launch type**: Select **"Fargate"**
3. Click **"Next step"**

**Configure task:**
- **Task Definition Name**: `honeycomb-test-task`
- **Task Role**: Leave blank (or select existing)
- **Operating system family**: Linux
- **Task execution IAM role**: `ecsTaskExecutionRole`
- **Task memory (GB)**: `0.5GB`
- **Task CPU (vCPU)**: `0.25 vCPU`

## Step 3: Add FireLens Container

Click **"Add container"**:

**Container 1 - Log Router:**
- **Container name**: `log-router`
- **Image**: `amazon/aws-for-fluent-bit:stable`
- **Memory Limits**: Soft limit `128`
- **Essential**: ✅ **Yes**

**Scroll down to "FIRELENS INTEGRATION":**
- **Enable FireLens integration**: ✅ **Yes**
- **Type**: `fluentbit`
- **Configuration file type**: `file`
- **Enable logging**: ✅ **Yes**

**Log Configuration:**
- **Log driver**: `awslogs`
- **Log options**:
  - `awslogs-group`: `/ecs/honeycomb-test` (create this CloudWatch group)
  - `awslogs-region`: `us-east-1` (or your region)
  - `awslogs-stream-prefix`: `firelens`

Click **"Add"**

## Step 4: Add Application Container

Click **"Add container"** again:

**Container 2 - Test App:**
- **Container name**: `nginx-app`
- **Image**: `nginx:latest`
- **Memory Limits**: Soft limit `256`
- **Essential**: ✅ **Yes**
- **Port mappings**: `80:80`

**Log Configuration:**
- **Log driver**: `awsfirelens`
- **Log options**:
  ```
  Name          http
  host          api.honeycomb.io
  port          443
  uri           /1/events/test-dataset
  format        json
  tls           on
  headers       {"X-Honeycomb-Team":"YOUR_ACTUAL_API_KEY"}
  ```

**⚠️ Replace `YOUR_ACTUAL_API_KEY` with your real Honeycomb API key**

Click **"Add"** → **"Create"**

## Step 5: Create Service

1. Go to your `honeycomb-test` cluster
2. Click **"Services"** tab → **"Create"**
3. **Launch type**: `Fargate`
4. **Task Definition**: Select `honeycomb-test-task:1`
5. **Platform version**: `LATEST`
6. **Cluster**: `honeycomb-test`
7. **Service name**: `honeycomb-test-service`
8. **Number of tasks**: `1`
9. Click **"Next step"**

**Configure network:**
- **Cluster VPC**: Select your default VPC
- **Subnets**: Select 2 public subnets
- **Security groups**: Create new or select existing
- **Auto-assign public IP**: `ENABLED`

Click **"Next step"** → **"Next step"** → **"Create Service"**

## Step 6: Test the Setup

1. **Wait for service to start** (2-3 minutes)
2. **Check logs**:
   - Go to CloudWatch → Log groups → `/ecs/honeycomb-test`
   - Look for Fluent Bit startup messages
3. **Generate test logs**:
   - Nginx will automatically generate access logs
   - You can also visit the public IP to generate more logs
4. **Check Honeycomb**:
   - Go to your Honeycomb account
   - Look for dataset named `test-dataset`
   - Should see nginx logs appearing

## What You Should See in Honeycomb

**Expected log format:**
```json
{
  "date": "2024-01-01T12:00:00.000Z",
  "log": "127.0.0.1 - - [01/Jan/2024:12:00:00 +0000] \"GET / HTTP/1.1\" 200 615",
  "container_id": "abc123...",
  "container_name": "nginx-app",
  "source": "stdout",
  "ecs_cluster": "honeycomb-test",
  "ecs_task_arn": "arn:aws:ecs:...",
  "ecs_task_definition": "honeycomb-test-task:1"
}
```

## Troubleshooting

### Common Issues

**1. No logs appearing in Honeycomb**
- Check CloudWatch logs for Fluent Bit errors
- Verify API key is correct (no extra spaces/quotes)
- Ensure security group allows HTTPS outbound (port 443)

**2. Task fails to start**
- Check IAM permissions for `ecsTaskExecutionRole`
- Verify VPC has internet access (public subnet + internet gateway)
- Check CloudWatch logs for detailed error messages

**3. HTTP 401/403 errors**
- Verify Honeycomb API key is correct
- Check dataset name doesn't have special characters
- Ensure API key has write permissions

**4. Task starts but no logs in CloudWatch**
- Verify CloudWatch log group `/ecs/honeycomb-test` exists
- Check IAM permissions for CloudWatch Logs
- Ensure task execution role has proper permissions

### Debugging Commands

**Check task status:**
```bash
aws ecs describe-tasks --cluster honeycomb-test --tasks TASK_ARN
```

**View CloudWatch logs:**
```bash
aws logs get-log-events --log-group-name /ecs/honeycomb-test --log-stream-name LOG_STREAM_NAME
```

**Test connectivity from task:**
```bash
# If you add a debug container with curl
curl -v https://api.honeycomb.io/1/events/test-dataset \
  -H "X-Honeycomb-Team: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test": "message"}'
```

## Security Considerations

**For production use:**
- Store API keys in AWS Secrets Manager or Systems Manager Parameter Store
- Use private subnets with NAT Gateway for outbound internet access
- Implement least-privilege IAM policies
- Enable VPC Flow Logs for network monitoring

## Cleanup

**To avoid charges:**
1. **Stop the service**: ECS Console → Services → Update → Desired count: 0
2. **Delete the service**: After tasks stop, delete the service
3. **Delete task definition**: Deregister all revisions
4. **Delete cluster**: Remove the empty cluster
5. **Delete CloudWatch log group**: `/ecs/honeycomb-test`

## Cost Estimation

**Minimal setup cost (us-east-1):**
- ECS Fargate: ~$0.01/hour (0.25 vCPU, 0.5GB RAM)
- CloudWatch Logs: ~$0.50/GB ingested
- Data Transfer: First 1GB free/month

**Daily cost**: ~$0.25 for compute + log volume

## Next Steps

Once this basic setup is working:
1. **Customize log format** - Add structured logging to your application
2. **Scale up** - Increase task count for production workloads  
3. **Add monitoring** - Set up CloudWatch alarms for task health
4. **Implement IaC** - Convert to Terraform or CloudFormation
5. **Security hardening** - Use Secrets Manager and private networking

For more advanced configurations, see the main [ECS-FIRELENS.md](./ECS-FIRELENS.md) documentation.

---

⚠️ **REMINDER: This AWS configuration has not been tested in practice. Please validate all steps and configurations before using in any environment.**