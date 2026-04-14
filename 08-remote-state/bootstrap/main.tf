// EP8 — Bootstrap remote state backend.
// Run this ONCE, in its own folder, with LOCAL state.
// Then the main project uses this storage account as its backend.

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

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = "westus2"

  tags = {
    Purpose   = "Terraform remote state"
    ManagedBy = "Terraform"
  }
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "sttfstate${substr(md5(azurerm_resource_group.tfstate.id), 0, 8)}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}

output "backend_config" {
  value = <<EOT
# Add this to your project's terraform block:

terraform {
  backend "azurerm" {
    resource_group_name  = "${azurerm_resource_group.tfstate.name}"
    storage_account_name = "${azurerm_storage_account.tfstate.name}"
    container_name       = "${azurerm_storage_container.tfstate.name}"
    key                  = "saas.tfstate"
    use_azuread_auth     = true
  }
}

# Then run: terraform init -migrate-state
EOT
}
