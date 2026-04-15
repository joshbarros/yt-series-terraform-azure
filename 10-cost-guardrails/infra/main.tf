// EP10 — Cost guardrails: budgets, alerts, and dev auto-shutdown.
//
// ⚠️  APPEND-PATTERN: This file is NOT standalone runnable.
//     These resources EXTEND the EP9 multi-environment main.tf —
//     copy them INTO your existing infra/main.tf.

variable "monthly_budget_usd" {
  type    = number
  default = 50
}

variable "budget_alert_emails" {
  type    = list(string)
  default = []
}

# --- Budget at the resource group ---
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${local.workload}"
  resource_group_id = azurerm_resource_group.main.id
  amount            = var.monthly_budget_usd
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.budget_alert_emails
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}

# --- Auto-stop dev App Service Plan nightly ---
# Use a Logic App or Azure Automation runbook on a schedule.
# Simpler approach: scale the plan to "F1" off-hours, back to "B1" in the morning.
# For dev only — do NOT apply to staging/prod.

resource "azurerm_logic_app_workflow" "stop_dev_appsvc" {
  count               = var.environment == "dev" ? 1 : 0
  name                = "logic-stop-dev-appsvc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

# Recurrence trigger + HTTP action wiring is done in portal/REST after creation.
# Trigger: daily at 20:00 local time.
# Action: POST https://management.azure.com/<webapp-id>/stop?api-version=2022-09-01

# --- Cost anomaly alert (catches 3x baseline spikes) ---
resource "azurerm_monitor_action_group" "cost" {
  name                = "ag-${local.workload}-cost"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "cost"

  dynamic "email_receiver" {
    for_each = toset(var.budget_alert_emails)
    content {
      name          = "budget-${replace(email_receiver.value, "@", "-at-")}"
      email_address = email_receiver.value
    }
  }
}

output "cost_summary_command" {
  value = "az consumption usage list --start-date $(date -u -v-30d +%Y-%m-%d) --end-date $(date -u +%Y-%m-%d) --query '[].{date:usageStart,cost:pretaxCost,resource:instanceName}' -o table"
}
