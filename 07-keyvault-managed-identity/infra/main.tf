// EP7 — Azure Key Vault + Managed Identity (kill all secrets)
//
// Replaces var.db_password being passed into app_settings as plaintext.
// Web app pulls DATABASE_URL from Key Vault using its System-Assigned Managed Identity.

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                       = "kv-${local.project}-${substr(md5(azurerm_resource_group.main.id), 0, 6)}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = local.common_tags
}

# Grant YOU permission to write secrets (CLI/Terraform user)
resource "azurerm_role_assignment" "kv_admin_me" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store the DB connection string as a secret
resource "azurerm_key_vault_secret" "database_url" {
  name         = "DATABASE-URL"
  value        = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_admin_me]
}

# --- Web app modifications ---
//
// In your existing azurerm_linux_web_app.main resource, ADD:
//
//   identity {
//     type = "SystemAssigned"
//   }
//
// And REPLACE the DATABASE_URL line in app_settings with a Key Vault reference:
//
//   DATABASE_URL = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.database_url.id})"

# Grant the web app's Managed Identity read access to secrets
resource "azurerm_role_assignment" "kv_reader_app" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
