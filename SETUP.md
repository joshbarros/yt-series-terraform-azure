# Pre-Recording Setup Checklist

Complete this ONCE before your dry run. Takes ~15 min.

## Tools

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
brew install azure-cli
brew install postgresql   # for psql (EP 3)
brew install gh           # for GitHub CLI (EP 4)

az login
gh auth login
terraform version         # verify
az account show           # verify
```

## Next.js app (required for EP 2-5)

The lab only contains the snippets you'll showcase (instrumentation.ts, deploy.yml). The Next.js app itself you scaffold once:

```bash
cd ~/LABS
npx create-next-app@latest my-saas-app --ts --app --tailwind --eslint
cd my-saas-app
git init && git add -A && git commit -m "initial commit"

# Copy in the infra folders as you progress through episodes:
cp -r ~/LABS/yt-series-terraform-azure/02-app-service/infra ./infra

# For EP 5, install App Insights SDK and copy instrumentation.ts:
npm install applicationinsights
cp ~/LABS/yt-series-terraform-azure/05-monitoring/app/instrumentation.ts ./instrumentation.ts

# For EP 4, copy the workflow:
mkdir -p .github/workflows
cp ~/LABS/yt-series-terraform-azure/04-github-actions/app/.github/workflows/deploy.yml .github/workflows/

# Push to GitHub (EP 4 needs this):
gh repo create my-saas-app --private --source=. --push
```

## Runtime string verification

Azure updates supported runtimes. Verify `NODE|20-lts` is still listed:

```bash
az webapp list-runtimes --os linux | grep -i node
```

If 20-lts isn't there, substitute the latest available (likely 22-lts).

## Test the dry run

```bash
~/LABS/yt-series-terraform-azure/dry-run.sh
```

Walks through every episode with pauses. Complete it end-to-end, note any surprises, fix them, then record.

## Cleanup

```bash
# From whichever episode folder is currently applied:
terraform destroy
```
