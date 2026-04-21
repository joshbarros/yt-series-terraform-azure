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

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/consumption_budget_resource_group
# Manages a Consumption Budget scoped to a Resource Group.
# Tracks actual and forecasted spend against a monthly dollar amount.
resource "azurerm_consumption_budget_resource_group" "main" {
  name              = "budget-${local.workload}"
  resource_group_id = azurerm_resource_group.main.id
  amount            = var.monthly_budget_usd
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  # Threshold at 50% — "heads up, you're halfway through your budget."
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  # Threshold at 80% — "investigate now, you're going to blow this."
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = var.budget_alert_emails
  }

  # Threshold at 100% FORECASTED — fires BEFORE you spend the money.
  # This is the most important alert — it's proactive, not retroactive.
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = var.budget_alert_emails
  }

  # Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
  # time_period.start_date is set once at creation — don't let Terraform drift it on every apply.
  lifecycle {
    ignore_changes = [time_period]
  }
}

# --- Auto-stop dev App Service Plan nightly ---

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/logic_app_workflow
# Manages a Logic App Workflow — a serverless automation that runs on a schedule or trigger.
# This one stops the dev App Service Plan every night at 20:00 to avoid overnight billing.
# count = 0 in staging/prod — auto-shutdown is dev-only.
resource "azurerm_logic_app_workflow" "stop_dev_appsvc" {
  count               = var.environment == "dev" ? 1 : 0
  name                = "logic-stop-dev-appsvc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.common_tags
}

# NOTE: The recurrence trigger + HTTP stop action is wired in the Azure portal
# after creation. Terraform creates the workflow shell; the schedule is JSON
# that's easier to manage in the Logic App Designer UI.
# Trigger: daily at 20:00 local time.
# Action: POST https://management.azure.com/<webapp-id>/stop?api-version=2022-09-01

# --- Cost anomaly alert ---

# Docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group
# A separate action group for cost alerts — keeps cost notifications distinct from app health alerts.
resource "azurerm_monitor_action_group" "cost" {
  name                = "ag-${local.workload}-cost"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "cost"

  # Docs: https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks
  # dynamic block iterates over the email list — one receiver per address.
  dynamic "email_receiver" {
    for_each = toset(var.budget_alert_emails)
    content {
      name          = "budget-${replace(email_receiver.value, "@", "-at-")}"
      email_address = email_receiver.value
    }
  }
}

# A handy CLI one-liner to check last 30 days of spend. Alias it in your shell.
output "cost_summary_command" {
  value = "az consumption usage list --start-date $(date -u -v-30d +%Y-%m-%d) --end-date $(date -u +%Y-%m-%d) --query '[].{date:usageStart,cost:pretaxCost,resource:instanceName}' -o table"
}
