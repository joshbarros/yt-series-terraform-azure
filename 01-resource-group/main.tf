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

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-${local.environment}"
  location = local.location
  tags     = local.common_tags
}
