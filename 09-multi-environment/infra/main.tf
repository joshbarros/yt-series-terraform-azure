// EP9 — Multi-environment (dev/staging/prod) using Terraform Workspaces + tfvars.
//
// Workflow:
//   terraform workspace new dev      (or: terraform workspace select dev)
//   terraform apply -var-file=../envs/dev.tfvars
//
// Each workspace gets its own state file in the remote backend (saas.tfstate:env:dev).

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

# Docs: https://developer.hashicorp.com/terraform/language/values/variables
# Each variable below is supplied by a per-environment .tfvars file (envs/dev.tfvars, etc.).
variable "environment" { type = string }
variable "location" { type = string }
variable "app_sku" { type = string }       # e.g. "B1" for dev, "P1v3" for prod
variable "db_sku" { type = string }        # e.g. "B_Standard_B1ms" for dev
variable "db_storage_mb" { type = number } # e.g. 32768 for dev, 131072 for prod
variable "alert_email" { type = string }
variable "log_retention" { type = number } # e.g. 30 for dev, 90 for prod
variable "db_password" {
  type      = string
  sensitive = true
}

locals {
  workload = "theitguy-saas"
  suffix   = var.environment # Appended to every resource name for env isolation

  common_tags = {
    Environment = var.environment
    Owner       = "theitguy"
    Project     = local.workload
    ManagedBy   = "Terraform"
    # Docs: https://developer.hashicorp.com/terraform/language/state/workspaces
    # terraform.workspace is the name of the active workspace (e.g. "dev", "staging").
    Workspace = terraform.workspace
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
# Each environment gets its own resource group (rg-theitguy-saas-dev, rg-theitguy-saas-staging, etc.).
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-${local.suffix}"
  location = var.location
  tags     = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
# SKU is driven by var.app_sku — "B1" in dev, "P1v3" in prod. Same code, different sizing.
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.workload}-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_sku
  tags                = local.common_tags
}

# (Add: web app, postgres, monitoring resources — same as EP5 but parameterized
#  via var.db_sku, var.db_storage_mb, var.log_retention, etc.)

output "resource_group_name" {
  description = "Name of the Azure Resource Group for this environment"
  value       = azurerm_resource_group.main.name
}

output "environment" {
  description = "Current deployment environment (dev, staging, prod)"
  value       = var.environment
}

output "workspace" {
  description = "Active Terraform workspace name"
  value       = terraform.workspace
}

output "next_step" {
  description = "How to deploy another environment using this same codebase"
  value       = <<-EOT
    To deploy another environment, run:

      terraform workspace new staging
      terraform apply -var-file=../envs/staging.tfvars

    Available environments:
      terraform workspace new dev      && terraform apply -var-file=../envs/dev.tfvars
      terraform workspace new staging  && terraform apply -var-file=../envs/staging.tfvars
      terraform workspace new prod     && terraform apply -var-file=../envs/prod.tfvars

    To switch between existing environments:
      terraform workspace select dev
  EOT
}
