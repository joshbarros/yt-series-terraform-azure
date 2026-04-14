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

variable "alert_email" {
  type        = string
  description = "Email address for alert notifications"
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

# --- Observability foundation ---

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

resource "azurerm_application_insights" "main" {
  name                = "ai-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  retention_in_days   = 90
  tags                = local.common_tags
}

# --- Compute (with telemetry wiring) ---

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
    WEBSITE_NODE_DEFAULT_VERSION          = "~20"
    SCM_DO_BUILD_DURING_DEPLOYMENT        = "true"
    DATABASE_URL                          = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.main.connection_string
  }

  tags = local.common_tags
}

# Stream platform logs + metrics to Log Analytics for queryability and retention.
resource "azurerm_monitor_diagnostic_setting" "webapp" {
  name                       = "diag-app-${local.workload}"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# --- PostgreSQL ---

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version  = "16"
  sku_name = "B_Standard_B1ms"
  zone     = "1"

  administrator_login    = "psqladmin"
  administrator_password = var.db_password

  storage_mb                   = 32768
  storage_tier                 = "P4"
  auto_grow_enabled            = true
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  public_network_access_enabled = true

  tags = local.common_tags

  lifecycle {
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

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "diag-psql-${local.workload}"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# --- Alerting ---

resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-${local.workload}-critical"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "critical"
  enabled             = true

  email_receiver {
    name                    = "owner"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "high_error_rate" {
  name                = "alert-high-errors-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Failed request count exceeds 5 in 15-minute window"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true
  enabled             = true

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "slow_response" {
  name                = "alert-slow-response-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_application_insights.main.id]
  description         = "Average request duration exceeds 3 seconds over 15-minute window"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true
  enabled             = true

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/duration"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 3000
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  tags = local.common_tags
}

# --- Outputs ---

output "app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "db_connection_string" {
  value     = "postgresql://psqladmin:${var.db_password}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/saasdb?sslmode=require"
  sensitive = true
}

output "appinsights_connection_string" {
  value     = azurerm_application_insights.main.connection_string
  sensitive = true
}
