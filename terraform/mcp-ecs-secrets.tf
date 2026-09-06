resource "aws_secretsmanager_secret" "grafana_sa_token" {
  name        = "${var.project_name}/grafana-sa-token"
  description = "Grafana service account token for the MCP server"
}