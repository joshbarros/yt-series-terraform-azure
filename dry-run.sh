#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DRY RUN SCRIPT — Terraform + Azure SaaS Series
# ============================================================
# This walks through every episode's Terraform in sequence.
# Run it step-by-step (not all at once) to simulate recording.
#
# PREREQUISITES:
#   brew tap hashicorp/tap
#   brew install hashicorp/tap/terraform
#   brew install azure-cli
#   az login
#
# COST: ~$27/month if you forget to destroy. Destroy same day = pennies.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "==========================================="
echo "  TERRAFORM + AZURE SERIES — DRY RUN"
echo "==========================================="
echo ""
echo "This script is meant to be run STEP BY STEP."
echo "Copy-paste one section at a time."
echo "Press Ctrl+C to exit at any point."
echo ""

# ----------------------------------------------------------
# PRE-FLIGHT: Verify tools are installed
# ----------------------------------------------------------
echo "--- PRE-FLIGHT CHECKS ---"
echo ""

echo "Terraform:"
terraform version | head -1
echo ""

echo "Azure CLI:"
az version --query '"azure-cli"' -o tsv
echo ""

echo "Logged in as:"
az account show --query user.name -o tsv
echo ""

echo "Subscription:"
az account show --query name -o tsv
echo ""

echo "Subscription ID:"
az account show --query id -o tsv
echo ""

# Verify available Node runtimes (script says NODE|20-lts)
echo "Available Node.js runtimes on Azure Linux:"
az webapp list-runtimes --os linux 2>/dev/null | grep -i node || echo "(run 'az webapp list-runtimes --os linux' manually if this fails)"
echo ""

read -p "Pre-flight OK? Press Enter to continue to EP 1, or Ctrl+C to abort... "

# ----------------------------------------------------------
# EP 1: Resource Group
# ----------------------------------------------------------
echo ""
echo "==========================================="
echo "  EP 1 — YOUR FIRST IaC"
echo "==========================================="
echo ""

cd "$SCRIPT_DIR/01-resource-group"
echo "Working directory: $(pwd)"
echo ""

echo ">>> terraform init"
terraform init
echo ""

echo ">>> terraform plan"
terraform plan
echo ""

read -p "Apply? Press Enter to run 'terraform apply', or Ctrl+C to skip... "
terraform apply -auto-approve
echo ""

echo ">>> Verifying resource group exists..."
az group show --name rg-theitguy-demo --query name -o tsv
echo ""

read -p "Destroy EP 1 resources? Press Enter or Ctrl+C to skip... "
terraform destroy -auto-approve
echo ""

echo "EP 1 DONE."
echo ""

# ----------------------------------------------------------
# EP 2: App Service
# ----------------------------------------------------------
echo "==========================================="
echo "  EP 2 — DEPLOY NEXT.JS"
echo "==========================================="
echo ""

cd "$SCRIPT_DIR/02-app-service/infra"
echo "Working directory: $(pwd)"
echo ""

echo ">>> terraform init"
terraform init
echo ""

echo ">>> terraform plan"
terraform plan
echo ""

read -p "Apply? Press Enter to run 'terraform apply'... "
terraform apply -auto-approve
echo ""

echo ">>> App URL:"
terraform output app_url
echo ""

echo "NOTE: To deploy a real Next.js app, run from the app directory:"
echo "  npx create-next-app@latest my-saas-app --ts --app --tailwind --eslint"
echo "  cd my-saas-app && npm run build"
echo "  az webapp up --name app-theitguy-saas --resource-group rg-theitguy-saas --runtime \"NODE|20-lts\""
echo ""

read -p "Continue to EP 3? Press Enter... "

# ----------------------------------------------------------
# EP 3: PostgreSQL
# ----------------------------------------------------------
echo ""
echo "==========================================="
echo "  EP 3 — POSTGRESQL SETUP"
echo "==========================================="
echo ""

# Destroy EP 2 infra first (EP 3 has its own complete main.tf)
echo ">>> Destroying EP 2 infra (EP 3 includes everything)..."
cd "$SCRIPT_DIR/02-app-service/infra"
terraform destroy -auto-approve
echo ""

cd "$SCRIPT_DIR/03-postgresql/infra"
echo "Working directory: $(pwd)"
echo ""

echo ">>> terraform init"
terraform init
echo ""

echo ">>> terraform plan (will ask for db_password)"
echo "TIP: Use a test password like 'TestP@ssw0rd2026!'"
echo ""
terraform plan
echo ""

read -p "Apply? Press Enter to run 'terraform apply'... "
echo "NOTE: PostgreSQL provisioning takes 3-5 minutes."
terraform apply
echo ""

echo ">>> Testing database connection..."
echo "Run manually:"
echo "  psql \"postgresql://psqladmin@psql-theitguy-saas.postgres.database.azure.com:5432/saasdb?sslmode=require\""
echo ""

read -p "Continue to EP 4? Press Enter... "

# ----------------------------------------------------------
# EP 4: GitHub Actions (Terraform only — workflow is a file)
# ----------------------------------------------------------
echo ""
echo "==========================================="
echo "  EP 4 — CI/CD PIPELINE"
echo "==========================================="
echo ""

echo "EP 4 adds a GitHub Actions workflow file."
echo "The Terraform infra is identical to EP 3."
echo ""
echo "Workflow file location:"
echo "  $SCRIPT_DIR/04-github-actions/app/.github/workflows/deploy.yml"
echo ""
echo "To test the full CI/CD flow:"
echo "  1. Create a GitHub repo"
echo "  2. az ad sp create-for-rbac --name \"github-deploy-theitguy\" --role contributor --scopes /subscriptions/\$(az account show --query id -o tsv)/resourceGroups/rg-theitguy-saas --json-auth"
echo "  3. gh secret set AZURE_CREDENTIALS (paste the JSON)"
echo "  4. gh secret set AZURE_WEBAPP_NAME --body \"app-theitguy-saas\""
echo "  5. Push to main and watch Actions tab"
echo ""

read -p "Continue to EP 5? Press Enter... "

# ----------------------------------------------------------
# EP 5: Monitoring
# ----------------------------------------------------------
echo ""
echo "==========================================="
echo "  EP 5 — MONITOR & ALERTS"
echo "==========================================="
echo ""

# Destroy EP 3 infra (EP 5 has the complete superset)
echo ">>> Destroying EP 3 infra (EP 5 includes everything)..."
cd "$SCRIPT_DIR/03-postgresql/infra"
terraform destroy -auto-approve 2>/dev/null || true
echo ""

cd "$SCRIPT_DIR/05-monitoring/infra"
echo "Working directory: $(pwd)"
echo ""

echo ">>> terraform init"
terraform init
echo ""

echo ">>> terraform plan (will ask for db_password and alert_email)"
terraform plan
echo ""

read -p "Apply? Press Enter to run 'terraform apply'... "
echo "NOTE: This creates ALL resources (RG + App Service + PostgreSQL + Monitoring)."
echo "PostgreSQL takes 3-5 minutes."
terraform apply
echo ""

echo ">>> Outputs:"
terraform output app_url
echo ""

echo ">>> Check Azure Portal:"
echo "  Portal → Application Insights → ai-theitguy-saas"
echo ""

echo ">>> instrumentation.ts is at:"
echo "  $SCRIPT_DIR/05-monitoring/app/instrumentation.ts"
echo ""

# ----------------------------------------------------------
# CLEANUP
# ----------------------------------------------------------
echo ""
echo "==========================================="
echo "  CLEANUP — DESTROY EVERYTHING"
echo "==========================================="
echo ""

read -p "Destroy ALL Azure resources? Press Enter or Ctrl+C to keep them... "

cd "$SCRIPT_DIR/05-monitoring/infra"
terraform destroy -auto-approve

echo ""
echo "==========================================="
echo "  DRY RUN COMPLETE"
echo "==========================================="
echo "All resources destroyed. Azure bill: ~$0."
echo ""
