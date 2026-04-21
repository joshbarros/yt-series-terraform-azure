// EP6 — Custom Domain + Free Managed SSL on App Service
//
// ⚠️  APPEND-PATTERN: This file is NOT standalone runnable.
//     These resources EXTEND the EP5 main.tf — copy them INTO your
//     existing infra/main.tf (or alongside it in the same directory).
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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_custom_hostname_binding
# Manages a Hostname Binding for an App Service — tells the web app to accept traffic for your domain.
# BEFORE applying: at your DNS provider, create:
#   CNAME app -> <web-app>.azurewebsites.net
#   TXT   asuid.app -> <Custom Domain Verification ID from azurerm_linux_web_app>
resource "azurerm_app_service_custom_hostname_binding" "main" {
  hostname            = var.custom_domain
  app_service_name    = azurerm_linux_web_app.main.name
  resource_group_name = azurerm_resource_group.main.name

  # The cert resource below will manage ssl_state — don't let Terraform fight over it.
  lifecycle {
    ignore_changes = [ssl_state, thumbprint]
  }
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_managed_certificate
# Manages an App Service Managed Certificate — Azure issues a free DigiCert cert and auto-renews it every 6 months.
# Requires the hostname binding to exist AND DNS to resolve before this resource can be created.
resource "azurerm_app_service_managed_certificate" "main" {
  custom_hostname_binding_id = azurerm_app_service_custom_hostname_binding.main.id
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_certificate_binding
# Manages an App Service Certificate Binding — attaches the cert to the hostname using SNI.
# SNI (Server Name Indication) lets one IP serve multiple SSL hostnames.
resource "azurerm_app_service_certificate_binding" "main" {
  hostname_binding_id = azurerm_app_service_custom_hostname_binding.main.id
  certificate_id      = azurerm_app_service_managed_certificate.main.id
  ssl_state           = "SniEnabled"
}

output "custom_domain_url" {
  value = "https://${var.custom_domain}"
}

# Print this BEFORE applying — you need to create a TXT record with this value at your DNS provider.
output "domain_verification_id" {
  value       = azurerm_linux_web_app.main.custom_domain_verification_id
  description = "Add this as a TXT record at asuid.<subdomain> before apply"
}
