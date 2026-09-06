variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "grafana-mcp"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "cluster_version" {
  description = "Kubernetes version for EKS (use a version currently in EKS standard support)"
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.large"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
  default     = "admin12345"
}

variable "deploy_monitoring" {
  description = "Deploy Prometheus/Loki/Grafana (lecture 4.4). Requires EKS."
  type        = bool
  default     = true
}

variable "mcp_grafana_url" {
  description = "Override for the Grafana URL the ECS MCP task uses. Leave empty to auto-use the Chapter 4 Grafana LoadBalancer."
  type        = string
  default     = ""
}

variable "mcp_image" {
  description = "Container image for the MCP server"
  type        = string
  default     = "grafana/mcp-grafana:latest"
}

# Just for show -- used only if you uncomment mcp-ecs-dns.tf.
# Do not declare these until then, or terraform plan will demand values.
# variable "mcp_domain_name" {
#   description = "FQDN for the MCP endpoint, e.g. mcp.example.com"
#   type        = string
# }
#
# variable "mcp_hosted_zone_name" {
#   description = "Route 53 hosted zone you own, e.g. example.com"
#   type        = string
# }

variable "mcp_grafana_token" {
  description = "Grafana token"
  type        = string
}