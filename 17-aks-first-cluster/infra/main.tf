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
  location = "westus2"

  common_tags = {
    Environment = "dev"
    Owner       = "theitguy"
    Workload    = local.workload
    ManagedBy   = "Terraform"
    Series      = "scale-up"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-aks"
  location = local.location
  tags     = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace
# Required for AKS container insights (monitoring pods + nodes).
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.workload}-aks"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
# Manages an Azure Kubernetes Service (AKS) cluster.
# AKS control plane is FREE — you only pay for the worker nodes (VMs).
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "aks-${local.workload}"

  # The default node pool — the VMs that run your containers.
  # Standard_B2s = 2 vCPU, 4GB RAM (~$30/mo per node). Good for dev.
  # For production: Standard_D4s_v5 or Standard_D8s_v5.
  default_node_pool {
    name                = "system"
    node_count          = 2               # Minimum 2 for high availability
    vm_size             = "Standard_B2s"  # Burstable — cheapest useful size
    auto_scaling_enabled = true
    min_count           = 1               # Scale down to 1 off-peak
    max_count           = 3               # Scale up to 3 under load
    os_disk_size_gb     = 30
    tags                = local.common_tags
  }

  # System-Assigned Managed Identity — no service principal management needed.
  identity {
    type = "SystemAssigned"
  }

  # Container Insights — sends pod/node metrics + logs to Log Analytics.
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Network profile — kubenet is simpler, Azure CNI is more performant.
  # Kubenet for dev, Azure CNI for prod with VNet integration.
  network_profile {
    network_plugin = "kubenet"
    dns_service_ip = "10.0.0.10"
    service_cidr   = "10.0.0.0/16"
  }

  tags = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
# Grant AKS cluster permission to pull images from your ACR (from EP15).
# Without this, pods fail with ImagePullBackOff.
resource "azurerm_role_assignment" "aks_acr_pull" {
  count                = var.acr_id != "" ? 1 : 0
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID from EP15. Leave empty if ACR not yet created."
  default     = ""
}

# Docs: https://developer.hashicorp.com/terraform/language/values/outputs
output "kube_config_command" {
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
  description = "Run this to configure kubectl to talk to your cluster"
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  value = azurerm_kubernetes_cluster.main.fqdn
}
