// EP12 — Multi-region SaaS with Azure Front Door (global edge + failover).
//
// Architecture:
//   Front Door (global anycast)
//     ├─ origin: app-westus2.azurewebsites.net  (primary)
//     └─ origin: app-eastus2.azurewebsites.net  (secondary)
//   Health probes auto-failover when primary returns non-2xx.

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

locals {
  workload = "theitguy-saas"

  regions = {
    primary = {
      name     = "westus2"
      priority = 1
      weight   = 1000
    }
    secondary = {
      name     = "eastus2"
      priority = 2
      weight   = 500
    }
  }

  common_tags = {
    Environment = "prod"
    Owner       = "theitguy"
    Project     = local.workload
    ManagedBy   = "Terraform"
    Topology    = "multi-region"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-global"
  location = local.regions.primary.name
  tags     = local.common_tags
}

# Per-region web app (loop with for_each)
resource "azurerm_service_plan" "regional" {
  for_each            = local.regions
  name                = "asp-${local.workload}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = each.value.name
  os_type             = "Linux"
  sku_name            = "P1v3"
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "regional" {
  for_each            = local.regions
  name                = "app-${local.workload}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = each.value.name
  service_plan_id     = azurerm_service_plan.regional[each.key].id
  https_only          = true

  site_config {
    application_stack {
      node_version = "20-lts"
    }
    always_on                         = true
    health_check_path                 = "/api/health"
    health_check_eviction_time_in_min = 5
  }

  tags = local.common_tags
}

# --- Front Door ---
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "fd-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.common_tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "fde-${local.workload}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "og-saas"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = "/api/health"
    protocol            = "Https"
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_origin" "regional" {
  for_each                       = local.regions
  name                           = "origin-${each.key}"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.main.id
  enabled                        = true
  certificate_name_check_enabled = true
  host_name                      = azurerm_linux_web_app.regional[each.key].default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.regional[each.key].default_hostname
  priority                       = each.value.priority
  weight                         = each.value.weight
}

resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "route-saas"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids      = [for o in azurerm_cdn_frontdoor_origin.regional : o.id]
  enabled                       = true
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  patterns_to_match             = ["/*"]
  supported_protocols           = ["Http", "Https"]
}

output "frontdoor_url" {
  value = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}
