output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs for load balancers"
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "grafana_url" {
  description = "External Grafana URL (kube-prometheus-stack LoadBalancer)"
  value       = local.grafana_url
}

output "mcp_ecs_cluster_name" {
  description = "ECS cluster running MCP"
  value       = aws_ecs_cluster.mcp.name
}

output "mcp_ecs_log_group" {
  description = "CloudWatch log group for MCP on ECS"
  value       = aws_cloudwatch_log_group.mcp.name
}