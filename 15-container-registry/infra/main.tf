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
  name     = "rg-${local.workload}-containers"
  location = local.location
  tags     = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry
# Manages an Azure Container Registry — a private Docker registry in Azure.
# Basic SKU is cheapest (~$5/mo). Standard adds webhooks + geo-replication.
resource "azurerm_container_registry" "main" {
  name                = "acr${replace(local.workload, "-", "")}" # Must be globally unique, alphanumeric only
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"       # Basic = 10GB storage, 2 webhooks. Standard = 100GB + geo-replication.
  admin_enabled       = false         # Use RBAC, not admin credentials. Admin is a shared password — avoid.
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
# Grant your CLI user permission to push images to ACR.
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush" # Can push + pull images. AcrPull = read-only.
  principal_id         = data.azurerm_client_config.current.object_id
}

output "acr_login_server" {
  value       = azurerm_container_registry.main.login_server
  description = "Use this as your image registry: docker tag <image> <login_server>/<image>"
}

output "acr_push_command" {
  value = "az acr login --name ${azurerm_container_registry.main.name} && docker push ${azurerm_container_registry.main.login_server}/nextjs-saas:latest"
}
