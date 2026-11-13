# TGTG deployment ownership

Workload path: `kubernetes/talos/deploy/tgtg`, namespace `tgtg`.
The explicit Kustomize resource list excludes all Secrets and Argo control
objects. Existing `tgtg`, `tgtg-proxy` and `regcred` Secrets stay external to this
Application. Never commit the populated local `secrets.yaml` in another checkout.

Workloads:
- `Deployment/tgtg-scanner`: controller/web UI and scanner child, one replica,
  Recreate strategy, persistent `/data` on `tgtg-data`.
- `Deployment/tgtg-vpn`: pinned Gluetun gateway, scaled zero/one by the controller.
  Argo must ignore **only** its `/spec/replicas` and use
  `RespectIgnoreDifferences=true` on every sync.
- `Service/vpn-proxy`: stable numeric proxy discovery; create before controller
  Pods because the app uses Kubernetes Service environment links.
- `Service/tgtg-control`, internal `Ingress/tgtg-control`:
  `https://tgtg.vandeneede.org`; unauthenticated LAN UI, not a public endpoint.
- `tgtg-controller` ServiceAccount and named gateway-only Role/RoleBinding.
- Existing namespace admission exception permits Gluetun NET_ADMIN/TUN only in
  this namespace; controller remains non-root/restricted. Do not broaden it.

Namespace/PVC are deletion-protected. Secrets are not Argo-managed, and the
default ServiceAccount and kube-root-ca ConfigMap must not be adopted.

The running app stores activation, schedules, INI and account-scoped tokens on
the PVC. Do not replace them with the seed ConfigMap, clear tokens or enable
scanning during adoption. Check activation before a disruptive image/template
change and ask before an active restart.

Use `/api/status` and `/api/vpn` for read-only health. Controller console output is
intentionally unredacted; never dump it while validating GitOps adoption.
Healthy control Pod != active scanning. Gateway replicas zero may be intentional.

New-installation gateway bootstrap is zero, but an existing live replica value
must survive every Argo sync. Do not run an opposing scale controller, raw apply
of the gateway bootstrap, the old disruption harness or independent live mock
owner during production reconciliation.

## GitOps handoff

Initial onboarding uses the authorized `onboard/tgtg-argocd` branch until explicitly
merged and the Application targetRevision is changed. Do not update the source
project's local `k8s/` as the only deployment source thereafter: commit the new
immutable image digest to this GitOps workload path and publish the approved
branch. The source project's historical apply/pull-secret scripts are not the
canonical GitOps release mechanism.

The Argo manifests are versioned outside the workload path, not automatically
managed by a root app. Apply reviewed Application/AppProject changes explicitly.
When moving to master, merge this branch first, verify manifests exist remotely,
then change targetRevision. Do not point Argo at a branch without these files.

## Rollback

Prefer a reviewed Git revert of the image/config change on the tracked branch
followed by Argo sync, preserving the replica ignore rule, Secrets and PVC.
Rolling back to a scanner image predating on-demand VPN control additionally
requires a manually maintained ready gateway; ask before changing that lifecycle.
Disabling/deleting the Argo app must not cascade-delete the Namespace/PVC.
