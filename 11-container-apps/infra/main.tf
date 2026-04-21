// EP11 — Azure Container Apps for Next.js (modern alternative to App Service).
//
// Why Container Apps?
//   - Scale to zero (App Service can't)
//   - Per-second billing
//   - Native Dapr, KEDA event-driven scaling
//   - Bring your own container — full control of runtime

# Docs: https://developer.hashicorp.com/terraform/language/settings
terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  workload = "theitguy-saas"
  location = "westus2"

  common_tags = {
    Environment = "dev"
    Owner       = "theitguy"
    Project     = local.workload
    ManagedBy   = "Terraform"
    Compute     = "container-apps"
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-aca"
  location = local.location
  tags     = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
# Required by the Container App Environment for centralized logging.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.workload}-aca"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment
# Manages a Container App Environment — the shared hosting environment (networking + logging)
# for one or more Container Apps. Think of it as a lightweight managed Kubernetes cluster.
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.workload}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app
# Manages a Container App — a serverless container that can scale to zero.
resource "azurerm_container_app" "nextjs" {
  name                         = "ca-${local.workload}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single" # Each deploy replaces the previous revision

  tags = local.common_tags

  template {
    min_replicas = 0 # SCALE TO ZERO — container stops after ~5 min idle. You pay $0.
    max_replicas = 5 # Burst capacity — KEDA spins up replicas on demand.

    container {
      name = "web"
      # Default to the Microsoft public quickstart image so the lab runs without
      # requiring a Docker push. Replace with `ghcr.io/${var.github_user}/nextjs-saas:latest`
      # once you've built and pushed your own image (see EP 11 script).
      image  = var.container_image
      cpu    = 0.5 # 0.5 vCPU per replica
      memory = "1Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
    }

    # Docs: https://learn.microsoft.com/en-us/azure/container-apps/scale-app
    # KEDA HTTP scale rule: if any single replica gets > 50 concurrent requests,
    # the environment spins up another replica to share the load.
    http_scale_rule {
      name                = "http-rule"
      concurrent_requests = 50
    }
  }

  # Docs: https://learn.microsoft.com/en-us/azure/container-apps/ingress-overview
  # Ingress exposes the container to the internet and handles TLS termination.
  ingress {
    external_enabled = true # Public internet access (set false for internal-only services)
    target_port      = 3000 # Port your app listens on inside the container
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100 # 100% of traffic goes to the latest revision
    }
  }
}

variable "github_user" {
  type        = string
  description = "Your GitHub username (used when you switch to your own image)"
  default     = "joshbarros"
}

variable "container_image" {
  type        = string
  description = "Container image to deploy. Defaults to MS public quickstart for first run."
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

output "app_url" {
  value = "https://${azurerm_container_app.nextjs.latest_revision_fqdn}"
}
