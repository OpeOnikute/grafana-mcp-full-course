resource "kubernetes_namespace" "monitoring" {
  count = var.deploy_monitoring ? 1 : 0

  metadata {
    name = "monitoring"
  }
}

# Prometheus + Grafana + Alertmanager + node exporters + the Prometheus Operator
# (the Operator installs the ServiceMonitor CRD used by demo-app.tf).
resource "helm_release" "kube_prometheus_stack" {
  count = var.deploy_monitoring ? 1 : 0

  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "61.0.0" # bump as needed
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password
        service = {
          type = "LoadBalancer"
        }
        # Auto-provision Loki as a datasource so no manual UI step is needed.
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            url       = "http://loki:3100"
            access    = "proxy"
            isDefault = false
          }
        ]
      }
    })
  ]
}

# Read the Grafana LoadBalancer Service back so its external hostname is
# available as a Terraform output / to the ECS MCP task — no manual copy needed.
# depends_on defers the read until the Helm release (and its Service) exist.
data "kubernetes_service" "grafana" {
  count = var.deploy_monitoring ? 1 : 0

  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = kubernetes_namespace.monitoring[0].metadata[0].name
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

locals {
  grafana_lb_hostname = try(data.kubernetes_service.grafana[0].status[0].load_balancer[0].ingress[0].hostname, "")
  grafana_url         = local.grafana_lb_hostname != "" ? "http://${local.grafana_lb_hostname}" : ""
}

# Loki + Promtail (Promtail tails every node's container logs and ships to Loki)
resource "helm_release" "loki" {
  count = var.deploy_monitoring ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = "2.10.2" # bump as needed
  namespace  = kubernetes_namespace.monitoring[0].metadata[0].name

  values = [
    yamlencode({
      promtail = {
        enabled = true
      }
    })
  ]
}
