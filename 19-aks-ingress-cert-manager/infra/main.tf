# EP19 — NGINX Ingress Controller + cert-manager on AKS.
#
# ⚠️  APPEND-PATTERN: This extends your EP17 AKS cluster.
#     Apply after AKS is running and kubectl is configured.
#
# This uses Helm provider to install NGINX ingress + cert-manager
# directly from Terraform — no separate helm install commands.

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Read AKS credentials for Helm + Kubernetes providers.
data "azurerm_kubernetes_cluster" "main" {
  name                = "aks-theitguy-saas"
  resource_group_name = "rg-theitguy-saas-aks"
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
}

# Docs: https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
# NGINX Ingress Controller — the "front door" of your Kubernetes cluster.
# Routes external traffic to internal services based on hostname + path rules.
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.11.0"

  # Azure-specific: provision a public Load Balancer with a static IP.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path"
    value = "/healthz"
  }
}

# cert-manager — automates TLS certificate issuance via Let's Encrypt.
# Your ingress rules get free, auto-renewing HTTPS certificates.
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "1.16.0"

  # CRDs (Custom Resource Definitions) must be installed for cert-manager to work.
  set {
    name  = "installCRDs"
    value = "true"
  }
}

# ClusterIssuer — tells cert-manager to use Let's Encrypt for all certs.
resource "kubernetes_manifest" "letsencrypt_prod" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.cert_email
        privateKeySecretRef = {
          name = "letsencrypt-prod-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "nginx"
            }
          }
        }]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

variable "cert_email" {
  type        = string
  description = "Email for Let's Encrypt certificate notifications"
}

output "ingress_ip_command" {
  value = "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}
