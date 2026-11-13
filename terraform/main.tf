# main.tf - Complete Fixed Version

locals {
  your_id   = var.your_id
  full_name = "lks-${local.your_id}"
  
  tags = {
    Project     = "OrderManagementSystem"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Owner       = local.your_id
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================
# S3 BUCKET FOR CLOUDFORMATION (Pre-step)
# ============================================
resource "aws_s3_bucket" "infrastructure" {
  bucket = "lks-infrastructure-${local.your_id}"
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "infrastructure" {
  bucket = aws_s3_bucket.infrastructure.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================
# VPC
# ============================================
resource "aws_vpc" "main" {
  cidr_block                       = "20.1.0.0/20"
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = true
  
  tags = merge(local.tags, {
    Name = "lks-vpc-${local.your_id}-serverless"
  })
}

# Public Subnets (2 subnets, each with /25 = 126 hosts)
resource "aws_subnet" "public" {
  count = 2
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  map_public_ip_on_launch = true
  
  tags = merge(local.tags, {
    Name = "lks-public-subnet-${local.your_id}-${count.index + 1}"
    Type = "Public"
  })
}

# Private Subnets (2 subnets, each with /26 = 62 hosts)
resource "aws_subnet" "private" {
  count = 2
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2)
  ipv6_cidr_block   = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = merge(local.tags, {
    Name = "lks-private-subnet-${local.your_id}-${count.index + 1}"
    Type = "Private"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.tags, {
    Name = "lks-igw-${local.your_id}"
  })
}

# Egress-only Internet Gateway for IPv6
resource "aws_egress_only_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.tags, {
    Name = "lks-eigw-${local.your_id}"
  })
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.tags, {
    Name = "lks-rt-public-${local.your_id}"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "public_ipv6" {
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.main.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(local.tags, {
    Name = "lks-rt-private-${local.your_id}"
  })
}

resource "aws_route" "private_ipv6" {
  route_table_id              = aws_route_table.private.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.main.id
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = 2
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = 2
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================
# SECURITY GROUPS
# ============================================

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name        = "lks-sg-lambda-${local.your_id}"
  description = "security for lambda function"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.tags, {
    Name = "lks-sg-lambda-${local.your_id}"
  })
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "lks-sg-rds-${local.your_id}"
  description = "security for RDS"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }
  
  tags = merge(local.tags, {
    Name = "lks-sg-rds-${local.your_id}"
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoint" {
  name        = "lks-sg-vpc-endpoint-${local.your_id}"
  description = "security for vpc endpoint"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = merge(local.tags, {
    Name = "lks-sg-vpc-endpoint-${local.your_id}"
  })
}

# ============================================
# VPC ENDPOINTS
# ============================================

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  route_table_ids = [aws_route_table.private.id]
  
  tags = merge(local.tags, {
    Name = "lks-s3-${local.your_id}-endpoints"
  })
}

# EventBridge Interface Endpoint
resource "aws_vpc_endpoint" "eventbridge" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.events"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  
  tags = merge(local.tags, {
    Name = "lks-eventbridge-${local.your_id}-endpoints"
  })
}

# Step Functions Interface Endpoint
resource "aws_vpc_endpoint" "step_functions" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.states"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  
  tags = merge(local.tags, {
    Name = "lks-steps-${local.your_id}-endpoints"
  })
}

# SNS Interface Endpoint
resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  
  tags = merge(local.tags, {
    Name = "lks-sns-${local.your_id}-endpoints"
  })
}

# ============================================
# S3 BUCKETS
# ============================================

# Orders Bucket
resource "aws_s3_bucket" "orders" {
  bucket = "lks-orders-${local.your_id}-2026"
  
  tags = merge(local.tags, {
    Name    = "lks-orders-${local.your_id}-2026"
    Purpose = "Order Documents"
  })
}

resource "aws_s3_bucket_versioning" "orders" {
  bucket = aws_s3_bucket.orders.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "orders" {
  bucket = aws_s3_bucket.orders.id
  
  rule {
    id     = "noncurrent-transition"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "INTELLIGENT_TIERING"
    }
    
    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

resource "aws_s3_bucket_policy" "orders" {
  bucket = aws_s3_bucket.orders.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.orders.arn,
          "${aws_s3_bucket.orders.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_cors_configuration" "orders" {
  bucket = aws_s3_bucket.orders.id
  
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Logs Bucket
resource "aws_s3_bucket" "logs" {
  bucket = "lks-logs-${local.your_id}-2026"
  
  tags = merge(local.tags, {
    Name    = "lks-logs-${local.your_id}-2026"
    Purpose = "Application Logs"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }
    
    expiration {
      days = 90
    }
  }
}

# ============================================
# RDS
# ============================================

resource "aws_db_subnet_group" "main" {
  name        = "lks-rds-subnet-group-${local.your_id}"
  description = "Subnet group for RDS"
  subnet_ids  = aws_subnet.private[*].id
  
  tags = merge(local.tags, {
    Name = "lks-rds-subnet-group-${local.your_id}"
  })
}

resource "aws_db_parameter_group" "postgres" {
  name        = "lks-rds-pg-${local.your_id}"
  family      = "postgres15"
  description = "Parameter group for PostgreSQL 15"
  
  parameter {
    name  = "log_connections"
    value = "1"
  }
  
  tags = merge(local.tags, {
    Name = "lks-rds-pg-${local.your_id}"
  })
}

resource "aws_db_instance" "orders" {
  identifier = "lks-rds-${local.your_id}-orders"
  
  engine         = "postgres"
  engine_version = "15"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = "ordersdb"
  username = "dbadmin"
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  publicly_accessible = false
  
  backup_retention_period = 14
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = merge(local.tags, {
    Name = "lks-rds-${local.your_id}-orders"
  })
}

# ============================================
# IAM ROLE FOR LAMBDA
# ============================================
resource "aws_iam_role" "lambda_role" {
  name = "lks-lambda-role-${local.your_id}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lks-lambda-policy-${local.your_id}"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "rds-db:connect",
          "states:StartExecution",
          "states:DescribeExecution",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================
# SNS TOPIC
# ============================================
resource "aws_sns_topic" "order_notifications" {
  name = "lks-sns-${local.your_id}-order-notifications"
  
  tags = merge(local.tags, {
    Name = "lks-sns-${local.your_id}-order-notifications"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.order_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ============================================
# LAMBDA LAYER
# ============================================
resource "aws_lambda_layer_version" "dependencies" {
  layer_name = "lks-layer-${local.your_id}-dependencies"
  
  filename         = "${path.module}/lambda-zips/layer.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/layer.zip")
  
  compatible_runtimes = ["python3.11"]
  description         = "Shared dependencies: psycopg2-binary, boto3, requests, pandas, openpyxl"
}

# ============================================
# LAMBDA FUNCTIONS
# ============================================

# Lambda Function: Order Management
resource "aws_lambda_function" "order_management" {
  filename         = "${path.module}/lambda-zips/order_management.zip"
  function_name    = "lks-lambda-${local.your_id}-order-management"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 512
  
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/order_management.zip")
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      RDS_ENDPOINT        = aws_db_instance.orders.endpoint
      RDS_DB_NAME         = aws_db_instance.orders.db_name
      RDS_USERNAME        = aws_db_instance.orders.username
      RDS_PASSWORD        = var.db_password
      ORDERS_BUCKET       = aws_s3_bucket.orders.id
      LOGS_BUCKET         = aws_s3_bucket.logs.id
      SNS_TOPIC_ARN       = aws_sns_topic.order_notifications.arn
    }
  }
  
  layers = [aws_lambda_layer_version.dependencies.arn]
  
  tags = local.tags
  
  depends_on = [aws_db_instance.orders]
}

# Lambda Function: Process Payment
resource "aws_lambda_function" "process_payment" {
  filename         = "${path.module}/lambda-zips/process_payment.zip"
  function_name    = "lks-lambda-${local.your_id}-process-payment"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 512
  
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/process_payment.zip")
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      RDS_ENDPOINT  = aws_db_instance.orders.endpoint
      RDS_DB_NAME   = aws_db_instance.orders.db_name
      RDS_USERNAME  = aws_db_instance.orders.username
      RDS_PASSWORD  = var.db_password
      SNS_TOPIC_ARN = aws_sns_topic.order_notifications.arn
    }
  }
  
  layers = [aws_lambda_layer_version.dependencies.arn]
  
  tags = local.tags
  
  depends_on = [aws_db_instance.orders]
}

# Lambda Function: Update Inventory
resource "aws_lambda_function" "update_inventory" {
  filename         = "${path.module}/lambda-zips/update_inventory.zip"
  function_name    = "lks-lambda-${local.your_id}-update-inventory"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 45
  memory_size      = 256
  
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/update_inventory.zip")
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      RDS_ENDPOINT  = aws_db_instance.orders.endpoint
      RDS_DB_NAME   = aws_db_instance.orders.db_name
      RDS_USERNAME  = aws_db_instance.orders.username
      RDS_PASSWORD  = var.db_password
      SNS_TOPIC_ARN = aws_sns_topic.order_notifications.arn
    }
  }
  
  layers = [aws_lambda_layer_version.dependencies.arn]
  
  tags = local.tags
  
  depends_on = [aws_db_instance.orders]
}

# Lambda Function: Send Notification
resource "aws_lambda_function" "send_notification" {
  filename         = "${path.module}/lambda-zips/send_notification.zip"
  function_name    = "lks-lambda-${local.your_id}-send-notification"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 256
  
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/send_notification.zip")
  
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.order_notifications.arn
    }
  }
  
  layers = [aws_lambda_layer_version.dependencies.arn]
  
  tags = local.tags
}

# Lambda Function: Generate Report
resource "aws_lambda_function" "generate_report" {
  filename         = "${path.module}/lambda-zips/generate_report.zip"
  function_name    = "lks-lambda-${local.your_id}-generate-report"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 1024
  
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/generate_report.zip")
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      RDS_ENDPOINT    = aws_db_instance.orders.endpoint
      RDS_DB_NAME     = aws_db_instance.orders.db_name
      RDS_USERNAME    = aws_db_instance.orders.username
      RDS_PASSWORD    = var.db_password
      ORDERS_BUCKET   = aws_s3_bucket.orders.id
      LOGS_BUCKET     = aws_s3_bucket.logs.id
    }
  }
  
  layers = [aws_lambda_layer_version.dependencies.arn]
  
  tags = local.tags
  
  depends_on = [aws_db_instance.orders]
}

# Lambda Function: Init Database
resource "aws_lambda_function" "init_db" {
  filename         = "${path.module}/lambda-zips/init_database.zip"
  function_name    = "lks-lambda-${local.your_id}-init-db"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  timeout          = 300
  memory_size      = 512
  
  source_code_hash = filebase64sha256("${path.module}/lambda-zips/init_database.zip")
  
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  environment {
    variables = {
      RDS_ENDPOINT = aws_db_instance.orders.endpoint
      RDS_DB_NAME  = aws_db_instance.orders.db_name
      RDS_USERNAME = aws_db_instance.orders.username
      RDS_PASSWORD = var.db_password
    }
  }
  
  layers = [aws_lambda_layer_version.dependencies.arn]
  
  tags = local.tags
  
  depends_on = [aws_db_instance.orders]
}

# ============================================
# IAM ROLE FOR STEP FUNCTIONS
# ============================================
resource "aws_iam_role" "step_functions" {
  name = "lks-stepfunctions-role-${local.your_id}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.tags
}

resource "aws_iam_role_policy" "step_functions" {
  name = "lks-stepfunctions-policy-${local.your_id}"
  role = aws_iam_role.step_functions.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          aws_lambda_function.order_management.arn,
          aws_lambda_function.process_payment.arn,
          aws_lambda_function.update_inventory.arn,
          aws_lambda_function.send_notification.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================
# STEP FUNCTIONS
# ============================================
resource "aws_sfn_state_machine" "order_workflow" {
  name     = "lks-stepfunctions-${local.your_id}-order-workflow"
  role_arn = aws_iam_role.step_functions.arn
  type     = "STANDARD"
  
  definition = jsonencode({
    Comment = "Order Processing Workflow"
    StartAt = "ValidateOrder"
    States = {
      ValidateOrder = {
        Type     = "Task"
        Resource = aws_lambda_function.order_management.arn
        Next     = "ProcessPayment"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "OrderFailed"
        }]
      }
      ProcessPayment = {
        Type     = "Task"
        Resource = aws_lambda_function.process_payment.arn
        Next     = "PaymentChoice"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "PaymentFailed"
        }]
      }
      PaymentChoice = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.paymentStatus"
            StringEquals = "SUCCESS"
            Next = "UpdateInventory"
          },
          {
            Variable = "$.paymentStatus"
            StringEquals = "FAILED"
            Next = "PaymentFailed"
          }
        ]
        Default = "PaymentFailed"
      }
      UpdateInventory = {
        Type     = "Task"
        Resource = aws_lambda_function.update_inventory.arn
        Next     = "InventoryChoice"
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "InventoryFailed"
        }]
      }
      InventoryChoice = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.inventoryStatus"
            StringEquals = "SUCCESS"
            Next = "SendConfirmation"
          },
          {
            Variable = "$.inventoryStatus"
            StringEquals = "FAILED"
            Next = "InventoryFailed"
          }
        ]
        Default = "InventoryFailed"
      }
      SendConfirmation = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        End      = true
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "OrderFailed"
        }]
      }
      PaymentFailed = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Next     = "OrderFailed"
      }
      InventoryFailed = {
        Type     = "Task"
        Resource = aws_lambda_function.send_notification.arn
        Next     = "OrderFailed"
      }
      OrderFailed = {
        Type = "Fail"
        Cause = "Order processing failed"
      }
    }
  })
  
  tags = local.tags
}

# ============================================
# API GATEWAY
# ============================================
resource "aws_api_gateway_rest_api" "orders" {
  name        = "lks-api-${local.your_id}-orders"
  description = "Order Management System API"
  
  endpoint_configuration {
    types           = ["REGIONAL"]
    ip_address_type = "dualstack"
  }
  
  tags = local.tags
}

# API Resources
resource "aws_api_gateway_resource" "orders_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "orders"
}

resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_resource.orders_resource.id
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "status_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "status"
}

resource "aws_api_gateway_resource" "status_id_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_resource.status_resource.id
  path_part   = "{id}"
}

resource "aws_api_gateway_resource" "customers_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "customers"
}

resource "aws_api_gateway_resource" "products_resource" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "products"
}

# GET /orders
resource "aws_api_gateway_method" "get_orders" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.get_orders.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# POST /orders
resource "aws_api_gateway_method" "post_orders" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.orders_resource.id
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "post_orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.orders_resource.id
  http_method = aws_api_gateway_method.post_orders.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# GET /orders/{id}
resource "aws_api_gateway_method" "get_order" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_order" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.get_order.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# PUT /orders/{id}
resource "aws_api_gateway_method" "put_order" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "PUT"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "put_order" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.put_order.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# DELETE /orders/{id}
resource "aws_api_gateway_method" "delete_order" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "DELETE"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "delete_order" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.delete_order.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# GET /status/{id}
resource "aws_api_gateway_method" "get_status" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.status_id_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_status" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.status_id_resource.id
  http_method = aws_api_gateway_method.get_status.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# GET /customers
resource "aws_api_gateway_method" "get_customers" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.customers_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_customers" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.customers_resource.id
  http_method = aws_api_gateway_method.get_customers.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# GET /products
resource "aws_api_gateway_method" "get_products" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.products_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_products" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  resource_id = aws_api_gateway_resource.products_resource.id
  http_method = aws_api_gateway_method.get_products.http_method
  
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.order_management.invoke_arn
}

# API Deployment
resource "aws_api_gateway_deployment" "production" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders_resource.id,
      aws_api_gateway_resource.order_resource.id,
      aws_api_gateway_resource.status_resource.id,
      aws_api_gateway_resource.status_id_resource.id,
      aws_api_gateway_resource.customers_resource.id,
      aws_api_gateway_resource.products_resource.id,
    ]))
  }
  
  depends_on = [
    aws_api_gateway_integration.get_orders,
    aws_api_gateway_integration.post_orders,
    aws_api_gateway_integration.get_order,
    aws_api_gateway_integration.put_order,
    aws_api_gateway_integration.delete_order,
    aws_api_gateway_integration.get_status,
    aws_api_gateway_integration.get_customers,
    aws_api_gateway_integration.get_products,
  ]
  
  lifecycle {
    create_before_destroy = true
  }
}

# API Stage
resource "aws_api_gateway_stage" "production" {
  deployment_id = aws_api_gateway_deployment.production.id
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  stage_name    = "production"
  
  tags = local.tags
}

# API Key
resource "aws_api_gateway_api_key" "orders" {
  name = "lks-api-${local.your_id}-key"
  
  tags = local.tags
}

# Usage Plan
resource "aws_api_gateway_usage_plan" "orders" {
  name = "lks-usage-${local.your_id}-plan"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.orders.id
    stage  = aws_api_gateway_stage.production.stage_name
  }
  
  throttle_settings {
    burst_limit = 2000
    rate_limit  = 1000
  }
  
  quota_settings {
    limit  = 100000
    period = "MONTH"
  }
  
  tags = local.tags
}

# Usage Plan Key
resource "aws_api_gateway_usage_plan_key" "orders" {
  key_id        = aws_api_gateway_api_key.orders.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.orders.id
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_management.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.orders.execution_arn}/*/*"
}

# ============================================
# AMPLIFY
# ============================================
resource "aws_amplify_app" "order_app" {
  name         = "lks-amplify-${local.your_id}-order-app"
  repository   = "https://github.com/Cydnrin/wakawaka"
  
  build_spec = <<-EOT
    version: 1
    frontend:
      phases:
        preBuild:
          commands:
            - echo "No build steps required for static site"
        build:
          commands:
            - echo "Build completed"
      artifacts:
        baseDirectory: frontend
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT
  
  environment_variables = {
    ENV     = "production"
    API_URL = aws_api_gateway_stage.production.invoke_url
  }
  
  tags = local.tags
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.order_app.id
  branch_name = "main"
  
  framework = "Static HTML/CSS/JavaScript"
  stage     = "PRODUCTION"
  
  enable_auto_build = true
  
  tags = local.tags
}

resource "aws_amplify_domain_association" "main" {
  app_id      = aws_amplify_app.order_app.id
  domain_name = aws_amplify_app.order_app.default_domain
  
  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = ""
  }
}