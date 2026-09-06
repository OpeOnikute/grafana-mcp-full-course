resource "kubernetes_namespace" "demo" {
  metadata {
    name = "demo"
  }
}

resource "kubernetes_config_map" "demo" {
  metadata {
    name      = "demo-config"
    namespace = kubernetes_namespace.demo.metadata[0].name
  }

  data = {
    APP_GREETING = "Hello from the Grafana MCP course"
    LOG_LEVEL    = "info"
  }
}

resource "kubernetes_deployment" "demo" {
  metadata {
    name      = "demo-app"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = "demo-app" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "demo-app" }
    }

    template {
      metadata {
        labels = { app = "demo-app" }
      }

      spec {
        container {
          name  = "demo-app"
          image = "quay.io/brancz/prometheus-example-app:v0.5.0"

          port {
            container_port = 8080
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.demo.metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "demo" {
  metadata {
    name      = "demo-app"
    namespace = kubernetes_namespace.demo.metadata[0].name
    labels    = { app = "demo-app" }
  }

  spec {
    selector = { app = "demo-app" }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_manifest" "demo_servicemonitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"

    metadata = {
      name      = "demo-app"
      namespace = "monitoring"
      labels = {
        release = "kube-prometheus-stack"
      }
    }

    spec = {
      namespaceSelector = {
        matchNames = ["demo"]
      }
      selector = {
        matchLabels = { app = "demo-app" }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "15s"
        }
      ]
    }
  }
}