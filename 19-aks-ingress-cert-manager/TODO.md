# EP19 — TODO before recording

## NGINX Ingress is End-of-Life

Reddit user `Allaman` flagged: NGINX Ingress Controller is EoL.

**Options:**
1. Replace with **Gateway API** (the Kubernetes-native successor) — more future-proof
2. Keep NGINX Ingress for teaching (simpler, more tutorials reference it) but add a disclaimer
3. Show both: NGINX for the demo, mention Gateway API as the production recommendation

**Recommendation:** Option 3. Teach NGINX (viewers will encounter it at work), but add a 30-second segment:
> "Quick note — NGINX Ingress is being replaced by the Gateway API, which is now the recommended approach for new clusters. I'm using NGINX here because you'll still see it everywhere, but for a new production setup, look into Gateway API. We cover it in the GCP series."

**Also applies to:**
- AWS EP19 (ALB Ingress Controller — different, but mention Gateway API)
- GCP EP19 (already uses Gateway API — no change needed)
