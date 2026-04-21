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

# Docs: https://developer.hashicorp.com/terraform/language/values/variables
# Input variable — Terraform prompts for this at plan/apply time.
# Marked sensitive so the value never appears in CLI output or state logs.
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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
# Manages an Azure Resource Group — a logical container for related Azure resources.
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}"
  location = local.location
  tags     = local.common_tags
}

# --- Compute ---

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
# Manages an App Service Plan — the compute layer (VM) that runs your web app.
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app
# Manages a Linux Web App (App Service) — the application itself.
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

  # DATABASE_URL wires the web app to the Postgres server created below.
  # The value is assembled from the server's FQDN + the sensitive password variable.
  app_settings = {
    WEBSITE_NODE_DEFAULT_VERSION   = "~20"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    DATABASE_URL                   = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
  }

  tags = local.common_tags
}

# --- PostgreSQL Flexible Server ---

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server
# Manages an Azure Database for PostgreSQL Flexible Server.
# Flexible Server is the current-generation managed PostgreSQL offering from Azure.
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version  = "16"              # PostgreSQL major version (16 is latest stable)
  sku_name = "B_Standard_B1ms" # Burstable tier: 1 vCore, 2GB RAM (~$12/mo)
  zone     = "1"               # Availability zone pin (prevents random zone assignment)

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  storage_mb            = 32768 # 32 GB — minimum for Burstable tier
  storage_tier          = "P4"  # Performance tier for storage IOPS
  auto_grow_enabled     = true  # Automatically expand storage when nearing capacity
  backup_retention_days = 7     # Point-in-time restore window (1–35 days)
  # Enable geo-redundant backups in production (~25% storage cost premium).
  geo_redundant_backup_enabled = false

  public_network_access_enabled = true # Required for App Service connectivity without VNet

  tags = local.common_tags

  # Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
  # Prevent zone changes that would force a full server recreate.
  lifecycle {
    ignore_changes = [zone]
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_configuration
# Manages a server-level configuration parameter on a PostgreSQL Flexible Server.
# Forces all client connections to use TLS — blocks plaintext connections.
resource "azurerm_postgresql_flexible_server_configuration" "require_secure_transport" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "ON"
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_firewall_rule
# Manages a firewall rule on a PostgreSQL Flexible Server.
# The special 0.0.0.0→0.0.0.0 range allows Azure-hosted services (like App Service) to connect.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server_database
# Manages a database within a PostgreSQL Flexible Server.
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = "saasdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}

# Marked sensitive — Terraform will not print this value in CLI output.
output "db_connection_string" {
  value     = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
  sensitive = true
}
