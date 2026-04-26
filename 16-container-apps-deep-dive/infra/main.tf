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
    Workload    = local.workload
    ManagedBy   = "Terraform"
    Series      = "scale-up"
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-aca-v2"
  location = local.location
  tags     = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.workload}-aca-v2"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app_environment
# Manages a Container App Environment — shared networking + logging for all Container Apps.
resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.workload}-v2"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app
# Web container — the Next.js frontend. Public ingress, scales on HTTP.
resource "azurerm_container_app" "web" {
  name                         = "ca-${local.workload}-web"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Multiple" # Multiple revisions = traffic splitting for canary deploys

  tags = local.common_tags

  template {
    min_replicas = 1
    max_replicas = 10

    container {
      name   = "web"
      image  = var.web_image
      cpu    = 0.5
      memory = "1Gi"

      # Docs: https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets
      # Secrets are stored encrypted in the ACA environment, referenced by name.
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = 50 # Add a replica per 50 concurrent requests
    }
  }

  # Docs: https://learn.microsoft.com/en-us/azure/container-apps/manage-secrets
  # Secrets are ACA's built-in secret management (alternative to Key Vault for simple cases).
  secret {
    name  = "database-url"
    value = var.database_url
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

# Worker container — processes background jobs (email, webhooks, etc.).
# No ingress — this container is internal only. Scales on KEDA triggers.
resource "azurerm_container_app" "worker" {
  name                         = "ca-${local.workload}-worker"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  tags = local.common_tags

  template {
    min_replicas = 0 # Scale to zero when no jobs to process
    max_replicas = 5

    container {
      name   = "worker"
      image  = var.worker_image
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "WORKER_MODE"
        value = "true"
      }
    }
  }

  secret {
    name  = "database-url"
    value = var.database_url
  }

  # No ingress block — worker is internal only.
  # It processes jobs from a queue, not HTTP requests.
}

variable "web_image" {
  type        = string
  description = "Container image for the web frontend"
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "worker_image" {
  type        = string
  description = "Container image for the background worker"
  default     = "mcr.microsoft.com/k8se/quickstart:latest"
}

variable "database_url" {
  type        = string
  description = "PostgreSQL connection string"
  sensitive   = true
  default     = "postgresql://user:pass@host:5432/db"
}

output "web_url" {
  value = "https://${azurerm_container_app.web.latest_revision_fqdn}"
}

output "web_revision" {
  value = azurerm_container_app.web.latest_revision_name
}
