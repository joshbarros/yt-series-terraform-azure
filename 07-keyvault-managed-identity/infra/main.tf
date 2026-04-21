// EP7 — Azure Key Vault + Managed Identity (kill all secrets)
//
// ⚠️  APPEND-PATTERN: This file is NOT standalone runnable.
//     These resources EXTEND the EP5 main.tf — copy them INTO your
//     existing infra/main.tf alongside the existing web app + RG.
//
// Replaces var.db_password being passed into app_settings as plaintext.
// Web app pulls DATABASE_URL from Key Vault using its System-Assigned Managed Identity.

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config
# Reads the current Azure CLI session — gives you tenant_id and object_id for role assignments.
data "azurerm_client_config" "current" {}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault
# Manages a Key Vault — a centralized, hardware-backed store for secrets, keys, and certificates.
# enable_rbac_authorization = true uses Azure RBAC (modern) instead of access policies (legacy).
resource "azurerm_key_vault" "main" {
  name                       = "kv-${local.workload}-${substr(md5(azurerm_resource_group.main.id), 0, 6)}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true  # Modern access control — integrates with Azure RBAC
  purge_protection_enabled   = false # Set to true in production to prevent permanent secret deletion
  soft_delete_retention_days = 7     # How many days a deleted vault/secret is recoverable
  tags                       = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
# Manages a Role Assignment — grants a principal a specific role on a scope.
# Grant YOU (the CLI/Terraform user) permission to write secrets into Key Vault.
resource "azurerm_role_assignment" "kv_admin_me" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret
# Manages a Key Vault Secret — stores a sensitive value (password, connection string, API key).
# depends_on ensures the RBAC role propagates (~30s) before Terraform tries to write the secret.
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

# Grant the web app's Managed Identity read-only access to secrets in Key Vault.
# "Key Vault Secrets User" can read secrets but cannot create, update, or delete them.
resource "azurerm_role_assignment" "kv_reader_app" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
