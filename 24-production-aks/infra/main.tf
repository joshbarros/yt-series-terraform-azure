# EP24 — Production AKS: The Full Picture.
#
# This is EP17's cluster with every production hardening applied.
# Combines lessons from EP17-23 into one deployable, production-ready config.

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
    Environment = "prod"
    Owner       = "theitguy"
    Workload    = local.workload
    ManagedBy   = "Terraform"
    Series      = "scale-up"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.workload}-aks-prod"
  location = local.location
  tags     = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network
# Production AKS needs its own VNet for network isolation + Azure CNI.
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.workload}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/8"]
  tags                = local.common_tags
}

# Subnet for AKS nodes — sized for Azure CNI (each pod gets a real IP).
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.240.0.0/16"]   # ~65K pod IPs
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.workload}-aks-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 90  # Production = longer retention
  tags                = local.common_tags
}

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
# Production AKS — every hardening from the series applied.
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.workload}-prod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "aks-${local.workload}-prod"
  kubernetes_version  = "1.30"   # Pin the version — don't let Azure auto-upgrade mid-sprint

  # System node pool — runs Kubernetes system pods (CoreDNS, metrics-server, etc.)
  default_node_pool {
    name                 = "system"
    node_count           = 2
    vm_size              = "Standard_D4s_v5"  # Production: 4 vCPU, 16GB RAM
    auto_scaling_enabled = true
    min_count            = 2
    max_count            = 5
    os_disk_size_gb      = 128
    vnet_subnet_id       = azurerm_subnet.aks.id   # Azure CNI — pods get real VNet IPs
    zones                = ["1", "2", "3"]          # Multi-AZ — survives zone failures
    tags                 = local.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure CNI — every pod gets a real IP from the VNet subnet.
  # Required for: Network Policies, VNet peering, private endpoints.
  network_profile {
    network_plugin     = "azure"   # Azure CNI (not kubenet)
    network_policy     = "calico"  # Calico enables NetworkPolicy enforcement
    dns_service_ip     = "10.0.0.10"
    service_cidr       = "10.0.0.0/16"
    load_balancer_sku  = "standard"
  }

  # Container Insights — pod/node metrics to Log Analytics.
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Azure Policy for AKS — enforces Pod Security Standards.
  azure_policy_enabled = true

  # Key Vault CSI driver — mount secrets into pods (from EP21).
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = local.common_tags
}

# User node pool — runs YOUR application pods (separated from system pods).
# Separation ensures your app can't starve Kubernetes system components.
resource "azurerm_kubernetes_cluster_node_pool" "app" {
  name                  = "app"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D4s_v5"
  auto_scaling_enabled  = true
  min_count             = 2
  max_count             = 20        # Scale up to 20 nodes under heavy load
  os_disk_size_gb       = 128
  vnet_subnet_id        = azurerm_subnet.aks.id
  zones                 = ["1", "2", "3"]

  # Taint: only schedule app pods here (system pods stay on the system pool).
  node_taints = ["workload=app:NoSchedule"]
  node_labels = { "workload" = "app" }

  tags = local.common_tags
}

# Resource quota — prevents any single namespace from consuming all cluster resources.
# Apply via kubectl after cluster is up.
output "resource_quota_yaml" {
  value = <<EOT
apiVersion: v1
kind: ResourceQuota
metadata:
  name: saas-quota
  namespace: production
spec:
  hard:
    requests.cpu: "8"         # Max 8 vCPU requested across all pods
    requests.memory: "16Gi"   # Max 16GB memory requested
    limits.cpu: "16"          # Max 16 vCPU limit
    limits.memory: "32Gi"     # Max 32GB memory limit
    pods: "50"                # Max 50 pods in this namespace
EOT
}

output "kube_config_command" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "cluster_summary" {
  value = <<EOT
Production AKS cluster deployed:
  - Azure CNI + Calico network policies
  - Multi-AZ (zones 1, 2, 3)
  - System pool (2-5 nodes) + App pool (2-20 nodes)
  - Key Vault CSI driver enabled
  - Azure Policy enforcing Pod Security Standards
  - Container Insights → Log Analytics (90-day retention)
  - Kubernetes version pinned to 1.30
EOT
}
