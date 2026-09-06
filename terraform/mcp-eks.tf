resource "helm_release" "grafana_mcp" {
  name       = "grafana-mcp"
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "grafana-mcp"
  version    = "0.22.0"
  namespace  = "mcp"

  create_namespace = true

  set_sensitive {
    name  = "grafana.apiKey"
    value = var.mcp_grafana_token
  }

  values = [yamlencode({
    grafana = {
      url = "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local"
    }
    disableWrite = true
    extraArgs    = ["-t", "streamable-http", "--address", "0.0.0.0:8000", "--allowed-hosts=*"]
  })]
}