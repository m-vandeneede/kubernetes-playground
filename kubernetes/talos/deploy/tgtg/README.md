# TGTG — GitOps source of truth

These nonsecret manifests are adopted from the existing deployment without
replacing the live namespace, storage or credentials. Argo control manifests live
in `kubernetes/talos/argocd/{projects,applications}/tgtg.yaml`, outside this
Kustomize source. The Application tracks `onboard/tgtg-argocd` until explicitly
merged and changed to master. No root app currently reconciles its control files.

## Ownership and safety

- Argo project/app: `argocd/tgtg`, destination `KubeLAB`, namespace `tgtg`.
- Automatic sync enabled; pruning and self-heal disabled.
- The scanner controller owns **only the VPN Deployment's live replica count**.
  App-level exact-resource `ignoreDifferences` plus
  `RespectIgnoreDifferences=true` preserve that count during every sync.
  Bootstrap replicas zero is for creation, not a command to stop a running VPN.
- Namespace/PVC are protected with `Prune=false,Delete=false`. The Application
  deliberately has no cascading-delete finalizer.
- The `vpn-proxy` Service is an earlier sync wave than the controller Deployment
  so a new Pod can discover its numeric Service address.
- Existing Secrets `tgtg`, `tgtg-proxy`, `regcred` stay externally managed and are
  not rendered. Never add plaintext credential files to this Kustomization.
- Longhorn PVC `tgtg-data` retains scanner settings, schedules and tokens.
- UI stays LAN-only at `https://tgtg.vandeneede.org` on internal Traefik.

## Validate

```sh
python3 .opencode/skills/kubelab-deploy/scripts/validate.py \
  --repo . --app tgtg \
  --application kubernetes/talos/argocd/applications/tgtg.yaml \
  --project kubernetes/talos/argocd/projects/tgtg.yaml
python3 .opencode/skills/kubelab-deploy/scripts/test_validate.py
kubectl kustomize kubernetes/talos/deploy/tgtg
```

The last command renders only reviewed nonsecret resources. Do not run a raw
recursive `kubectl apply` over a directory with local secret files, or raw-apply
the VPN bootstrap over a live gateway.

## Updating

Load the globally installed `kubelab-deploy` skill. Update the immutable scanner
image **here**, review/publish the tracked branch, then let Argo reconcile.
An image/template change restarts the controller and may affect the scanner/VPN;
check activation and obtain permission before a disruptive sync.
Do not treat a changed `k8s/` directory in the scanner source checkout as a release.

For initial adoption, create the Application with automation temporarily disabled,
review Argo differences, perform a reviewed non-pruning sync and enable the final
policy afterward. Do not take over another Argo app's resources.

For rollback, revert the reviewed Git change on the tracked branch. Keep the
replica ignore rule, existing Secrets and PVC. Before using images predating
on-demand VPN control, obtain permission for the additional manual gateway setup.

## Adoption evidence — 2026-11-13

- Initial reviewed source commit: `4e5b6e1` on `onboard/tgtg-argocd`.
- Global `kubelab-deploy` skill installed; versioned source and validator included.
- Validator and six regression tests passed. Kustomize renders exactly twelve
  nonsecret resources. Server dry-runs confirmed metadata-only adoption,
  including unchanged ConfigMap data, RBAC rules, workload templates and PVC spec.
- The Argo Application was created manual, reviewed, synced without pruning,
  and only then switched to automatic sync with prune/self-heal disabled.
- Initial operation succeeded and the app became **Synced / Healthy**.
- Existing Pod UIDs, Deployment UIDs/templates/replicas, bound PVC identity/spec,
  external Secret UIDs/resource versions and canonical config/control hashes
  remained unchanged. No scanner restart or login/notification test was needed.
- Scanner activation was **disabled** before adoption and remained disabled.
  The VPN stayed at **zero** replicas. These are preserved user state, not an
  instruction that GitOps should force the VPN off when scanning is activated.

This records the adoption check, not a promise that future Git changes cannot
restart workloads. Review each image/template change and preserve replica ownership.
