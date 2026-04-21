# Docs: https://developer.hashicorp.com/terraform/language/settings
# Constrains which Terraform CLI versions can use this configuration.
terraform {
  required_version = ">= 1.5"

  # Docs: https://developer.hashicorp.com/terraform/language/providers/requirements
  # Declares the providers this module depends on and pins their versions.
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
# Configures the Azure Resource Manager provider. The features block is required.
provider "azurerm" {
  features {}
}

# Docs: https://developer.hashicorp.com/terraform/language/values/locals
# Local values let you assign a name to an expression for reuse within the module.
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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
# Manages an App Service Plan — the compute layer (VM) that runs your web app.
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1" # Cheapest paid tier (~$13/mo). F1 is free but very limited.
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app
# Manages a Linux Web App (App Service) — the application itself.
resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  # Security baseline: force HTTPS, disable legacy FTP and basic-auth deploy paths.
  https_only                                     = true
  public_network_access_enabled                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app#identity
  # System-Assigned Managed Identity — Azure creates a service principal tied to this web app.
  # Required for Key Vault secret refs in EP 7.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    # Runtime stack: which language + version the platform container runs.
    application_stack {
      node_version = "20-lts"
    }
    app_command_line                  = "npm run start" # Startup command for Next.js
    always_on                         = true            # Keep the app loaded (prevents cold-start sleep)
    http2_enabled                     = true            # Enable HTTP/2 for faster multiplexed connections
    minimum_tls_version               = "1.2"           # Reject TLS 1.0/1.1 handshakes
    ftps_state                        = "Disabled"      # Disable FTP/FTPS entirely
    health_check_path                 = "/"             # Azure pings this path to confirm the app is alive
    health_check_eviction_time_in_min = 5               # Replace unhealthy instances after 5 min
  }

  # Docs: https://learn.microsoft.com/en-us/azure/app-service/configure-common#configure-app-settings
  # App settings = environment variables available to your running application.
  app_settings = {
    WEBSITE_NODE_DEFAULT_VERSION   = "~20"  # Belt-and-suspenders: ensure Node 20 across all subsystems
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true" # Run npm install + npm run build on Azure after code push
  }

  tags = local.common_tags
}

# Docs: https://developer.hashicorp.com/terraform/language/values/outputs
# Outputs are printed after `terraform apply` and queryable via `terraform output`.
output "app_url" {
  value = "https://${azurerm_linux_web_app.main.default_hostname}"
}
