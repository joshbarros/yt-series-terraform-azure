// EP9 — Multi-environment (dev/staging/prod) using Terraform Workspaces + tfvars.
//
// Workflow:
//   terraform workspace new dev      (or: terraform workspace select dev)
//   terraform apply -var-file=../envs/dev.tfvars
//
// Each workspace gets its own state file in the remote backend (saas.tfstate:env:dev).

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

variable "environment" { type = string }
variable "location" { type = string }
variable "app_sku" { type = string }
variable "db_sku" { type = string }
variable "db_storage_mb" { type = number }
variable "alert_email" { type = string }
variable "log_retention" { type = number }
variable "db_password" {
  type      = string
  sensitive = true
}

locals {
  project = "theitguy-saas"
  suffix  = var.environment

  common_tags = {
    Environment = var.environment
    Owner       = "theitguy"
    Project     = local.project
    ManagedBy   = "Terraform"
    Workspace   = terraform.workspace
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project}-${local.suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_service_plan" "main" {
  name                = "asp-${local.project}-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_sku
  tags                = local.common_tags
}

# (Add: web app, postgres, monitoring resources — same as EP5 but parameterized
#  via var.db_sku, var.db_storage_mb, var.log_retention, etc.)
