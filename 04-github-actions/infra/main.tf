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

variable "db_password" {
  type        = string
  description = "Admin password for PostgreSQL Flexible Server"
  sensitive   = true
}

locals {
  workload    = "theitguy-saas"
  environment = "dev"
  location    = "westus2"

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
  name     = "rg-${local.workload}"
  location = local.location
  tags     = local.common_tags
}

# --- Compute ---

resource "azurerm_service_plan" "main" {
  name                = "asp-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  https_only                                     = true
  public_network_access_enabled                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      node_version = "20-lts"
    }
    app_command_line                  = "npm run start"
    always_on                         = true
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    ftps_state                        = "Disabled"
    health_check_path                 = "/"
    health_check_eviction_time_in_min = 5
  }

  app_settings = {
    WEBSITE_NODE_DEFAULT_VERSION   = "~20"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    DATABASE_URL                   = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
  }

  tags = local.common_tags
}

# --- PostgreSQL Flexible Server ---

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version  = "16"
  sku_name = "B_Standard_B1ms"
  zone     = "1"

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  storage_mb            = 32768
  storage_tier          = "P4"
  auto_grow_enabled     = true
  backup_retention_days = 7
  # Geo-redundant backups: enable in prod (~25% storage cost premium).
  geo_redundant_backup_enabled = false

  public_network_access_enabled = true

  tags = local.common_tags

  lifecycle {
    # Prevent zone changes that would force a server recreate.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "ON"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "saasdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "db_connection_string" {
  value     = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
  sensitive = true
}
