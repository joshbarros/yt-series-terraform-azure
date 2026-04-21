# Docs: https://developer.hashicorp.com/terraform/language/settings
# Constrains which Terraform CLI versions can use this configuration.
terraform {
  required_version = ">= 1.5"

  # Docs: https://developer.hashicorp.com/terraform/language/providers/requirements
  # Declares the providers this module depends on and pins their versions.
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
# Configures the Azure Resource Manager provider. The features block is required.
provider "azurerm" {
  features {}
}

# Docs: https://developer.hashicorp.com/terraform/language/values/locals
# Local values let you assign a name to an expression for reuse within the module.
locals {
  workload    = "theitguy"
  environment = "demo"
  location    = "westus2"

  # Standard tag set — every resource carries these.
  common_tags = {
    Environment = local.environment
    Workload    = local.workload
    Owner       = "Josue"
    CostCenter  = "youtube-series"
    ManagedBy   = "Terraform"
    Repository  = "yt-series-terraform-azure"
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
# Manages an Azure Resource Group — a logical container for related Azure resources.
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-${local.environment}"
  location = local.location
  tags     = local.common_tags
}
