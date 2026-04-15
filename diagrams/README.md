# Architecture Diagrams

One `.excalidraw` per episode. Open at https://excalidraw.com → File → Open.

| File | Episode | What it shows |
|---|---|---|
| `ep01-resource-group.excalidraw` | EP 1 | Resource Group + standard tag set |
| `ep02-app-service.excalidraw` | EP 2 | Service Plan → Linux Web App → public URL |
| `ep03-postgresql.excalidraw` | EP 3 | PG Flex Server + firewall + DB, wired into web app |
| `ep04-cicd-github-actions.excalidraw` | EP 4 | Developer → GitHub Actions → SP → App Service |
| `ep05-monitoring.excalidraw` | EP 5 | Telemetry pipeline + 2 alert rules + action group |
| `ep06-custom-domain-ssl.excalidraw` | EP 6 | DNS provider → hostname binding → managed cert |
| `ep07-keyvault-managed-identity.excalidraw` | EP 7 | Web App MI → Key Vault → secret reference syntax |
| `ep08-remote-state.excalidraw` | EP 8 | Bootstrap → Storage Account → backend → blob lease lock |
| `ep09-multi-environment.excalidraw` | EP 9 | One main.tf + 3 tfvars → 3 workspaces → 3 RGs |
| `ep10-cost-guardrails.excalidraw` | EP 10 | Budget thresholds + Logic App auto-shutdown |
| `ep11-container-apps.excalidraw` | EP 11 | Image → ACA Environment → Container App (scale-to-zero) |
| `ep12-multi-region-frontdoor.excalidraw` | EP 12 | Front Door → 2 origins with health probes |

## Color legend

- **Gray (dim):** Resources from earlier episodes (context)
- **Blue:** New resources added in THIS episode
- **Red:** The "moment" element — the resource viewers should focus on

## Recording usage

Show the diagram as a brief overlay (or B-roll) at the start of each episode — typically the 30-second "what we're building" beat. Then back to terminal/VS Code for the implementation.
