output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = aws_api_gateway_stage.production.invoke_url
}

output "api_key" {
  description = "API Key for API Gateway"
  value       = aws_api_gateway_api_key.orders.value
  sensitive   = true
}

output "amplify_app_url" {
  description = "Amplify application URL"
  value       = "https://${aws_amplify_app.order_app.default_domain}"
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.orders.endpoint
  sensitive   = true
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = aws_sns_topic.order_notifications.arn
}

output "step_function_arn" {
  description = "Step Function ARN"
  value       = aws_sfn_state_machine.order_workflow.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "orders_bucket_name" {
  description = "Orders S3 bucket name"
  value       = aws_s3_bucket.orders.id
}

output "logs_bucket_name" {
  description = "Logs S3 bucket name"
  value       = aws_s3_bucket.logs.id
}