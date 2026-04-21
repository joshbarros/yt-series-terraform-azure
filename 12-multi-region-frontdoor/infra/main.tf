// EP12 — Multi-region SaaS with Azure Front Door (global edge + failover).
//
// Architecture:
//   Front Door (global anycast)
//     ├─ origin: app-westus2.azurewebsites.net  (primary)
//     └─ origin: app-centralus.azurewebsites.net (secondary)
//   Health probes auto-failover when primary returns non-2xx.

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

locals {
  workload = "theitguy-saas"

  # Docs: https://developer.hashicorp.com/terraform/language/expressions/for
  # A map of regions with priority + weight — used with for_each to avoid duplicating resources.
  regions = {
    primary = {
      name     = "westus2"
      priority = 1    # Lower = preferred. All traffic goes here when healthy.
      weight   = 1000 # Relative weight within the same priority group.
    }
    secondary = {
      name     = "eastus2"
      priority = 2 # Failover — only receives traffic when primary is unhealthy.
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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-global"
  location = local.regions.primary.name
  tags     = local.common_tags
}

# Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/for_each
# for_each creates one Service Plan + Web App PER region from the same block of code.
# Adding a third region is one line in the locals map — no code duplication.

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan
resource "azurerm_service_plan" "regional" {
  for_each            = local.regions
  name                = "asp-${local.workload}-${each.key}"
  resource_group_name = azurerm_resource_group.main.name
  location            = each.value.name
  os_type             = "Linux"
  sku_name            = "P1v3" # Production tier — dedicated compute, no shared tenancy
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_web_app
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
    health_check_path                 = "/api/health" # Front Door probes this path
    health_check_eviction_time_in_min = 5
  }

  tags = local.common_tags
}

# --- Front Door ---

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_profile
# Manages an Azure Front Door Profile — the top-level resource for global load balancing + CDN.
# Standard tier includes global anycast routing, health probes, and basic WAF capabilities.
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "fd-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_endpoint
# Manages a Front Door Endpoint — the public hostname (e.g. fde-xxx.azurefd.net) that clients hit.
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "fde-${local.workload}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_origin_group
# Manages an Origin Group — a set of backends that Front Door load-balances across.
# Health probes check each origin every 30 seconds. If 3 of 4 samples fail, the origin is marked unhealthy.
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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_origin
# Manages an Origin — a single backend server. Front Door routes traffic here based on priority + weight.
# for_each creates one origin per region with different priorities for automatic failover.
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
  priority                       = each.value.priority # 1 = primary, 2 = failover
  weight                         = each.value.weight
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_route
# Manages a Route — maps incoming requests (by pattern) to an origin group.
# This route sends all traffic (/*) to our origin group, with HTTPS redirect enabled.
resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "route-saas"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids      = [for o in azurerm_cdn_frontdoor_origin.regional : o.id]
  enabled                       = true
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true # HTTP requests auto-redirect to HTTPS at the edge
  patterns_to_match             = ["/*"]
  supported_protocols           = ["Http", "Https"]
}

output "frontdoor_url" {
  value = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}
