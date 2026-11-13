---
name: KubeLab Deployment
description: Deploy or onboard an application to the user's KubeLab Kubernetes cluster through the kubernetes-playground GitOps repo and Argo CD. Use for new Kubernetes applications, deployment manifests, image updates, migrations of manually deployed workloads, or creating Argo Applications/AppProjects. All deployable manifests must be versioned in the cluster repo, not left only in the app's source repo.
---

# KubeLab deployment contract

Read `references/cluster-profile.md` before making changes. It supplies this
user's repository, cluster, Argo destination and conventions. Discover actual
state each time; the profile is a default, not evidence that an app is healthy.

## 1. Scope and inspect

1. Confirm application name, namespace, source/image version, persistence,
   secret requirements and exposure. Reuse existing resources where appropriate.
2. Inspect repository instructions, `git status`, remotes, branch/worktrees,
   nearby manifests, live workload metadata and Argo Applications/AppProjects.
   Do not print Secret bodies, credentials, raw environment dumps or sensitive
   application logs. Query secret names/types or required-key presence only.
3. Preserve unrelated changes and untracked files. On a fork or with concurrent
   work, use a new named branch/worktree; do not reset, clean, overwrite or stage
   other work. Existing user files are input to review, not permission to discard.
4. Check current activation, schedules, replica ownership, PVCs, ingress/TLS,
   images and resource tracking. Ask before active restarts, disruptive syncs,
   credential changes, namespace-wide security exceptions or data migrations.
   Explicit deployment approval is not permission to activate a disabled app.

## 2. Put deployment state in the GitOps repository

- Put workload manifests in `kubernetes/talos/deploy/<app>/`, unless existing
  repository organization calls for a nested app directory.
- Do not leave the only deployment copy in the application's source project.
  Treat the GitOps path as the deployment source of truth. Source-repo examples
  may remain documentation; future image updates must update GitOps too.
- Prefer an explicit `kustomization.yaml` resource allowlist for plain manifests.
  Do not use a recursively scanned directory that can accidentally include local
  secret YAML, temporary exports or the app's own Argo configuration.
- Store the AppProject in `kubernetes/talos/argocd/projects/<app>.yaml` and
  Application in `kubernetes/talos/argocd/applications/<app>.yaml`, outside the
  workload source path. Reuse existing projects only when their scope fits.
- Keep credentials out of Git, including base64 Secret data, Docker auth and
  plaintext INI tokens. A gitignored secret file can still be read by local
  rendering: Git ignore is not a manifest allowlist or Argo exclusion.
  Reference existing Secrets, or use an approved ExternalSecret/SealedSecret
  workflow. Do not copy or rotate Secrets without explicit permission.
- Use immutable image digests for custom/private images. Preserve image-pull
  references, resource names, Service addresses/selectors, PVC identity and
  LAN-only ingress/TLS boundaries when adopting an existing deployment.
- Do not enable features requiring additional cluster components blindly.
  Load the relevant domain skill for CRDs, Helm, certificates or secret delivery.

## 3. Establish safe Argo ownership

1. Discover actual Argo repo URL, destination cluster name/server, namespace,
   version and project restrictions. Do not guess them from local SSH aliases.
2. Use a dedicated narrowly scoped AppProject: the approved repo, destination
   namespace and necessary resource kinds only. Never default to unrestricted
   cluster-wide resource permissions.
3. Before managing controller-owned fields, define exact-resource
   `ignoreDifferences` entries and `RespectIgnoreDifferences=true`.
   Diff-only suppression does **not** prevent sync from writing a field.
   Example: TGTG's controller, not Argo, owns `apps/Deployment tgtg/tgtg-vpn`
   `/spec/replicas`. Keep its new-installation bootstrap at zero while preserving
   live scale during sync. Ignore only this field on this named resource.
4. Respect existing resource ownership; use `FailOnSharedResource=true` to
   avoid silently adopting objects owned by a different Argo app.
5. Default here is automated sync enabled, **prune false and selfHeal false**.
   Confirm this for new tasks. Bootstrap an existing app with automation disabled
   until differences and side effects are reviewed, even if the final Git
   Application enables automation.
6. Protect Namespace/PVC deletion with resource-level
   `argocd.argoproj.io/sync-options: Prune=false,Delete=false`, preserving
   unrelated annotations. Do not add destructive cascade finalizers, force,
   replace, conflict takeover or pruning options without explicit approval.
7. Never solve drift with broad ignore rules or by copying an entire live export.
   Separate API-defaulted fields from actual intended changes.

## 4. Validate, publish and adopt

1. Render from the exact GitOps path, inspect resource identities and ensure no
   plaintext Secret is included. Run the supporting validator:

   ```sh
   python3 scripts/validate.py \
     --repo "<worktree>" --app "<app>" \
     --application "<worktree>/kubernetes/talos/argocd/applications/<app>.yaml" \
     --project "<worktree>/kubernetes/talos/argocd/projects/<app>.yaml"
   ```

   Here `scripts/validate.py` is relative to this skill's directory; use its full
   path when invoking from another working directory. It needs PyYAML and kubectl.
   It renders and validates; it does not apply, commit, push or sync anything.
2. Use server dry-run and inspect live-vs-desired changes. For controller-owned
   scale, preview with live replica values or use Argo's own diff; raw
   `kubectl apply` of a bootstrap value is not safe adoption.
3. Review the exact staged diff and verify it contains only intended nonsecret
   files. Ask before committing/pushing unless that is already authorized.
   Never use `git add .` in a dirty shared repository. Do not force-push.
4. Argo cannot deploy uncommitted/unpushed local files. Push the approved branch
   and commit, verify the remote revision, and point the Application at the
   agreed revision. Clearly document if a dedicated branch is the temporary
   deployment source; do not silently switch it to master.
5. Apply only the AppProject and the initially manual Application to bootstrap
   Argo. Prefer Argo sync over manually applying all workload manifests.
   Inspect comparison conditions and generated resources before the first sync.
6. If adoption would restart an active workload, change activation/scale, replace
   storage or alter exposure, stop and get permission. Do not assume metadata
   adoption requires a restart. When safe, sync the approved commit without prune,
   then apply the final approved automated-sync policy.
7. Verify Argo desired revision, Sync and Health, resource ownership, image,
   workload generation/Pod identities, actual controller-owned scale, storage
   and app health. Do not use real login/email/notification tests unless approved.
   An intentionally scaled-down gateway may be Healthy with no Pod; that does
   not prove a live tunnel exists.

## 5. Handoff

Report repo/branch/commit, manifest and Argo paths, app/project names, sync/health,
checks performed and anything pending. Make no claim of deployment from local
files alone. Keep original activation/settings/data intact and do not present
refreshed token contents as unchanged. Document rollback in Git, any special
controller-owned fields and how future app-image updates reach Argo.

Load `references/tgtg-adoption.md` when deploying or updating TGTG.
