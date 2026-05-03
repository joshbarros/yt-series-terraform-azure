# EP23 — AKS Monitoring with kube-prometheus-stack (Prometheus + Grafana).
#
# ⚠️  APPEND-PATTERN: Extends EP17 AKS cluster.
#     AKS must be running and kubectl configured.
#
# kube-prometheus-stack installs:
#   - Prometheus (metrics collection + storage)
#   - Grafana (dashboards + visualization)
#   - AlertManager (alert routing)
#   - Node Exporter, kube-state-metrics (cluster metrics)

terraform {
  required_version = ">= 1.5"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Assumes Helm provider is already configured (see EP19 for pattern).

# Docs: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
# One Helm chart installs the entire observability stack.
resource "helm_release" "prometheus_stack" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "65.0.0"

  # Grafana admin password — change this in production.
  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_password
  }

  # Enable persistent storage for Prometheus (retain metrics across restarts).
  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  # Retention — how long Prometheus keeps metrics.
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  # Enable Azure Monitor integration (forwards metrics to Log Analytics too).
  set {
    name  = "prometheus.prometheusSpec.enableRemoteWriteReceiver"
    value = "true"
  }
}

variable "grafana_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
}

output "grafana_url" {
  description = "Port-forward command + URL to open Grafana in your browser"
  value       = <<-EOT
    Step 1 — Run this in a terminal:
      kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

    Step 2 — Open in your browser:
      http://localhost:3000

    Step 3 — Login:
      Username: admin
      Password: (the grafana_password you set in tfvars)
  EOT
}

output "prometheus_url" {
  description = "Port-forward command + URL to open Prometheus in your browser"
  value       = <<-EOT
    Step 1 — Run this in a terminal:
      kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

    Step 2 — Open in your browser:
      http://localhost:9090
  EOT
}

output "alertmanager_url" {
  description = "Port-forward command + URL to open AlertManager in your browser"
  value       = <<-EOT
    Step 1 — Run this in a terminal:
      kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-alertmanager 9093:9093

    Step 2 — Open in your browser:
      http://localhost:9093
  EOT
}

output "grafana_password" {
  description = "Grafana admin password (sensitive)"
  value       = var.grafana_password
  sensitive   = true
}
