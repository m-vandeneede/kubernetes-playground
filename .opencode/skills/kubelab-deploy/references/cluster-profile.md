# User cluster profile

- Canonical checkout:
  `/Users/mvandeneede/Git/Personal/Home LAB/kubernetes-playground`
- A task-specific worktree is equally valid for authoring/publishing. Discover
  its actual branch and dirty state; do not overwrite the canonical checkout.
- Git remote (local): `git@github-personal:m-vandeneede/kubernetes-playground.git`
- Argo's registered repo URL:
  `git@github.com:m-vandeneede/kubernetes-playground.git`
- Usual main branch: `master`. Only use it when the approved changes are there.
- Kubernetes context: `admin@KubeLab`
- Argo namespace: `argocd`
- Argo destination cluster name: `KubeLAB`
- In-cluster destination server: `https://kubernetes.default.svc`
- Workload source: `kubernetes/talos/deploy/<app>`
- Argo control manifests: `kubernetes/talos/argocd/{projects,applications}/<app>.yaml`
- Existing convention: one project per app (some related apps share a project),
  automatic sync enabled, pruning/self-heal disabled. Verify live policy.
- Discovered Argo version at skill authoring: v3.4.1; recheck rather than pinning
  behavior to this observation.
- Current ingress uses Traefik; internal-only apps use the `internal` class and
  existing default TLS certificate. Do not expose an app publicly by accident.
- TGTG storage uses Longhorn. Choose storage based on current cluster conventions.
- Existing repo `.gitignore` ignores `*secret*.yaml`; do not bypass this or assume
  ignore rules sanitize tracked manifests.

This is not a Talos/Helm/Argo installation guide. Existing operators, secret
systems, admission policies and cluster services must be discovered as needed.
Do not install a new controller or change shared infrastructure merely to deploy
an app. This workflow does not change the CNI.

## Skill source and installation

Versioned source: `.opencode/skills/kubelab-deploy/` in this repo.
Global installation: `~/.config/opencode/skills/kubelab-deploy/`.
When updating the skill, review and version the source, then copy the approved
files to the global installation, preserving unrelated skills. The repo version
has discovery precedence when working in this repo. `/reload` can refresh skill
discovery; no OpenCode service restart is required.

## References

- https://opencode.ai/docs/skills
- https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/
- https://argo-cd.readthedocs.io/en/stable/user-guide/projects/
