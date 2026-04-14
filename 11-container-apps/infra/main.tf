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
  project  = "theitguy-saas"
  location = "westus2"

  common_tags = {
    Environment = "dev"
    Owner       = "theitguy"
    Project     = local.project
    ManagedBy   = "Terraform"
    Compute     = "container-apps"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project}-aca"
  location = local.location
  tags     = local.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.project}-aca"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.project}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

resource "azurerm_container_app" "nextjs" {
  name                         = "ca-${local.project}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"
  tags                         = local.common_tags

  template {
    min_replicas = 0 # SCALE TO ZERO
    max_replicas = 5

    container {
      name   = "web"
      image  = "ghcr.io/${var.github_user}/nextjs-saas:latest"
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
  type = string
}

output "app_url" {
  value = "https://${azurerm_container_app.nextjs.latest_revision_fqdn}"
}
