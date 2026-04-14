// EP8 — After running bootstrap/, add this backend block to your main project.
// State now lives in Azure Storage with blob lease locking + versioning.

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateXXXXXXXX" # replace with bootstrap output
    container_name       = "tfstate"
    key                  = "saas.tfstate"
    use_azuread_auth     = true
  }
}
