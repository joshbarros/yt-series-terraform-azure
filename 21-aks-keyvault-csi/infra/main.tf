# EP21 — Azure Key Vault CSI Driver for AKS.
#
# ⚠️  APPEND-PATTERN: Extends EP17 AKS cluster + EP7 Key Vault.
#
# The CSI (Container Storage Interface) driver mounts Key Vault secrets
# as files inside your pods. Your app reads them from disk — no SDK needed.
#
# Docs: https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Enable the Key Vault CSI addon on the existing AKS cluster.
# This installs the Secrets Store CSI Driver + Azure Key Vault provider as a DaemonSet.
resource "azurerm_kubernetes_cluster_extension" "keyvault_csi" {
  name           = "azurekeyvaultsecretsprovider"
  cluster_id     = var.aks_cluster_id
  extension_type = "Microsoft.AzureKeyVaultSecretsProvider"
}

# SecretProviderClass — tells the CSI driver WHICH secrets to mount and WHERE from.
resource "kubernetes_manifest" "secret_provider" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "azure-kv-secrets"
      namespace = "default"
    }
    spec = {
      provider = "azure"
      parameters = {
        usePodIdentity = "false"
        useVMManagedIdentity = "true"                          # Use AKS managed identity
        userAssignedIdentityID = var.aks_kubelet_identity_id   # Kubelet MI from EP17
        keyvaultName           = var.key_vault_name            # From EP7
        tenantId               = var.tenant_id
        objects = yamlencode([{
          objectName = "DATABASE-URL"
          objectType = "secret"
        }])
      }
    }
  }

  depends_on = [azurerm_kubernetes_cluster_extension.keyvault_csi]
}

variable "aks_cluster_id" {
  type        = string
  description = "AKS cluster resource ID from EP17"
}

variable "aks_kubelet_identity_id" {
  type        = string
  description = "AKS kubelet managed identity client ID from EP17"
}

variable "key_vault_name" {
  type        = string
  description = "Key Vault name from EP7"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant ID"
}

output "mount_instruction" {
  value = <<EOT
Add this volume + volumeMount to your Deployment spec:

volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "azure-kv-secrets"

containers:
  - name: web
    volumeMounts:
      - name: secrets-store
        mountPath: "/mnt/secrets"
        readOnly: true

Your app reads: cat /mnt/secrets/DATABASE-URL
EOT
}
