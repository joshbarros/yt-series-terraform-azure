# Docs: https://developer.hashicorp.com/terraform/language/backend/azurerm
# Configures the azurerm backend — stores terraform.tfstate in Azure Blob Storage.
# State is now shared, versioned, and protected by blob lease locking.
# After adding this block, run: terraform init -migrate-state

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateXXXXXXXX" # Replace with the value from bootstrap output
    container_name       = "tfstate"
    key                  = "saas.tfstate"
    use_azuread_auth     = true # Authenticate via az login — never use storage account access keys
  }
}
