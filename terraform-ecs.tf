# ECS Task Definition with FireLens and Honeycomb
resource "aws_ecs_task_definition" "honeycomb_firelens" {
  family                   = "honeycomb-firelens-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "firelens-fluent-bit"
      image     = "amazon/aws-for-fluent-bit:stable"
      essential = true
      
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
          "config-file-type"        = "file"
          "config-file-value"       = "/fluent-bit/etc/fluent-bit.conf"
        }
      }
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/firelens-fluent-bit"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "firelens"
        }
      }
      
      memoryReservation = 50
    },
    {
      name      = "app-container"
      image     = "nginx:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awsfirelens"
        options = {
          Name               = "http"
          Match              = "*"
          host               = "api.honeycomb.io"
          port               = "443"
          uri                = "/1/events/${var.honeycomb_dataset}"
          format             = "json"
          tls                = "on"
          json_date_key      = "date"
          json_date_format   = "iso8601"
          headers            = "{\"X-Honeycomb-Team\":\"${var.honeycomb_api_key}\",\"Content-Type\":\"application/json\"}"
        }
      }
      
      environment = [
        {
          name  = "ENV"
          value = "production"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "honeycomb_firelens" {
  name            = "honeycomb-firelens-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.honeycomb_firelens.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.app]
}

# Variables
variable "honeycomb_api_key" {
  description = "Honeycomb API key"
  type        = string
  sensitive   = true
}

variable "honeycomb_dataset" {
  description = "Honeycomb dataset name"
  type        = string
  default     = "ecs-logs"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

# IAM Roles
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}