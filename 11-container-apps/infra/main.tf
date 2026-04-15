// EP11 — Azure Container Apps for Next.js (modern alternative to App Service).
//
// Why Container Apps?
//   - Scale to zero (App Service can't)
//   - Per-second billing
//   - Native Dapr, KEDA event-driven scaling
//   - Bring your own container — full control of runtime

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

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-aca"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.workload}-aca"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.workload}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

resource "azurerm_container_app" "nextjs" {
  name                         = "ca-${local.workload}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  template {
    min_replicas = 0 # SCALE TO ZERO
    max_replicas = 5

    container {
      name = "web"
      # Default to the Microsoft public quickstart image so the lab runs without
      # requiring a Docker push. Replace with `ghcr.io/${var.github_user}/nextjs-saas:latest`
      # once you've built and pushed your own image (see EP 11 script).
      image  = var.container_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
    }

    http_scale_rule {
      name                = "http-rule"
      concurrent_requests = 50
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
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
