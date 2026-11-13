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
