// EP6 — Custom Domain + Free Managed SSL on App Service
//
// Prerequisites:
//   - You own a domain (Cloudflare/Namecheap/etc.)
//   - An EP5 deployment is live (web app + RG already exist)
//
// Add this AFTER your existing 05-monitoring resources.

variable "custom_domain" {
  type        = string
  description = "Apex or subdomain to bind, e.g. app.theitguy.io"
}

# Step 1 — Bind the hostname.
# BEFORE applying: at your DNS provider, create:
#   CNAME app -> <web-app>.azurewebsites.net
#   TXT   asuid.app -> <Custom Domain Verification ID from azurerm_linux_web_app>
resource "azurerm_app_service_custom_hostname_binding" "main" {
  hostname            = var.custom_domain
  app_service_name    = azurerm_linux_web_app.main.name
  resource_group_name = azurerm_resource_group.main.name

  # Don't let Terraform manage SSL state — the cert resource does that.
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

# Step 2 — Free App Service Managed Certificate (auto-renews every 6 months).
resource "azurerm_app_service_managed_certificate" "main" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.main.id
}

# Step 3 — Bind the cert to the hostname (SNI).
resource "azurerm_app_service_certificate_binding" "main" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.main.id
  certificate_id      = azurerm_app_service_managed_certificate.main.id
  ssl_state           = "SniEnabled"
}

output "custom_domain_url" {
  value = "https://${var.custom_domain}"
}

output "domain_verification_id" {
  value       = azurerm_linux_web_app.main.custom_domain_verification_id
  description = "Add this as a TXT record at asuid.<subdomain> before apply"
}
