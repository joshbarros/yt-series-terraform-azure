// EP8 — Bootstrap remote state backend.
// Run this ONCE, in its own folder, with LOCAL state.
// Then the main project uses this storage account as its backend.

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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
# Dedicated resource group for the Terraform state backend — isolated from application resources.
resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = "westus2"

  tags = {
    Purpose   = "Terraform remote state"
    ManagedBy = "Terraform"
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
# Manages an Azure Storage Account — the container for blob, file, queue, and table storage.
# This account stores Terraform state files as blobs.
resource "azurerm_storage_account" "tfstate" {
  name                            = "sttfstate${substr(md5(azurerm_resource_group.tfstate.id), 0, 8)}"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS" # Geo-redundant — state survives a regional Azure outage
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false # No anonymous access to blobs

  blob_properties {
    versioning_enabled = true # Every state write creates a new blob version — you can roll back
    delete_retention_policy {
      days = 30 # Soft-delete window — accidentally deleted state is recoverable for 30 days
    }
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container
# Manages a Container (folder) within the Storage Account.
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private" # No anonymous read — authenticated access only
}

# Docs: https://developer.hashicorp.com/terraform/language/values/outputs
# Prints the exact backend configuration block to paste into your main project.
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
