# Longhorn

## Stable deployment

Use the Kustomize entry point in
[`kubernetes/talos/cluster/longhorn/`](../../../../../kubernetes/talos/cluster/longhorn/).
Run the commands below from the repository root. The entry point references upstream Longhorn
**v1.13.0**, pinned to commit `c3d88832bd8cec4f38dec65e79436984871dc313`.
Component images use upstream release tags, not mutable `master-head` tags.

```sh
kubectl kustomize kubernetes/talos/cluster/longhorn
kubectl --context admin@KubeLab diff -k kubernetes/talos/cluster/longhorn
# Apply only after backup, compatibility, and diff review, with approval:
kubectl --context admin@KubeLab apply -k kubernetes/talos/cluster/longhorn
```

Use `apply -k`, not `apply -f` on the manifest directory: the settings patch is not a
standalone deployment. The historical development manifests were removed;
Git retains their history. `ingress.yaml` is separate and is not changed by
this upgrade.

## Preserved configuration

- `settings-patch.yaml` retains the original explicit defaults: the
  `/var/mnt/longhorn/` data path, `longhorn-critical` priority, and disabled V1
  revision counter. Other live Setting resources are not reset to defaults.
- The existing StorageClass configuration remains unchanged: two replicas,
  ext4, V1 data engine, disabled data locality, and the existing backup target.
  The global default replica count is distinct and is not changed.
- `backup-configuration.yaml` records the existing NFS backup target and daily
  backup job (04:00, retain 14, concurrency 1), previously absent from the repo.
- Existing node disk paths, reservations, scheduling flags, volumes, and replicas
  are not declared here and must not be deleted or recreated during the upgrade.

## Upgrade checkpoints

1. Preserve the current deployment and all live Longhorn configuration; verify
   fresh off-cluster volume backups before making live changes.
2. Check the manager and engine upgrade paths with version checks enabled.
   The existing cluster reports `v1.12.0-dev`; kube103 accidentally pulled
   `v1.14.0-dev` from the same `master-head` tag. Never use that tag for upgrades.
3. Apply the reviewed full release manifests (CRDs, RBAC, settings, and workloads),
   not just newer images or individual missing permissions.
   If the existing BackupTarget/RecurringJob apply fails while the managers
   restart (admission webhook connection refused), wait for the manager rollout
   to recover and reapply `backup-configuration.yaml`. Do not disable admission
   webhooks or restart data engines to work around that temporary interruption.
4. Verify all managers, CSI components, and the backup target. Confirm kube103's
   500 GiB filesystem disk at `/var/mnt/longhorn/` is ready and schedulable.
5. Validate with a disposable PVC write/read test and compare all existing
   workload/volume health and settings against the pre-upgrade inventory.

Volume engine upgrades are a separate approved operation. Keep automatic engine
upgrades disabled (`concurrent-automatic-engine-upgrade-per-node-limit=0`). Do
not enable V2, change replica counts, rebalance existing replicas, remove old
nodes, or delete old instance managers/engine images as part of preparation.

The release adds internal NetworkPolicies and sharding CRDs. Review policy
compatibility before applying; policies only take effect with an enforcing CNI.
The upstream manager DaemonSet uses `maxUnavailable: 100%` during its upgrade;
expect a management-plane interruption even while existing data engines run.
Do not treat Kubernetes manifest rollback as a guaranteed data/schema rollback.

## v1.12.1 checkpoint (2026-11-07)

The reviewed v1.12.1 manifest was applied successfully. All three managers report
v1.12.1; CSI components and the UI are ready. All three Longhorn nodes and disks
are ready and schedulable, including kube103's approximately 499.75 GiB usable
filesystem. The existing 14 attached volumes remain healthy; four detached
volumes retain their prior unknown robustness. Custom defaults, StorageClass
parameters, the backup target, and recurring backup job were preserved.

Existing volumes still reference the historical `master-head` engine and retain
their old instance managers; automatic engine upgrades remain disabled. Those
mutable legacy image references are not safe for fresh pulls and need a separate
controlled volume-engine upgrade. Old data-plane pods were not deleted. A
disposable PVC write/read test on kube103 passed: a 1 GiB strict-local V1 volume
using the v1.12.1 engine had its single replica on kube103, stored 32 MiB of random
data, fully detached, and reattached to an independent reader pod. File size and
SHA256 verification passed after reattachment. All temporary test resources were
removed; the existing 14 attached volumes remained healthy. Test evidence is at
`~/.talos/backups/longhorn-smoke-20261107164153/`.

## v1.13.0 upgrade

The target is upstream stable v1.13.0, from the validated v1.12.1 checkpoint.
Kubernetes v1.34+ is required; KubeLab runs v1.37.2. Existing volumes use V1, so
the V2 live-upgrade restriction requiring v1.12.2 does not apply. V2 remains
disabled. Manager version checks and automatic engine-upgrade settings are not
bypassed or changed.

The upstream release adds the three-replica `longhorn-global-manager` Deployment,
dedicated CSI service account/RBAC, and instance-manager-upgrade/snapshot-group
CRDs. Review the full manifest rather than changing only image tags. Preserve
the settings and backup patches across releases. Apply BackupTarget/RecurringJob
resources after manager/webhook readiness to avoid the interruption observed
during the preceding upgrade.

The v1.13.0 upgrade was applied on 2026-11-07. All three managers report v1.13.0;
the three-replica global manager, UI, driver deployer, and CSI components are
ready. All three disks are ready and schedulable. The existing 14 attached
volumes remain healthy; their engines have not been upgraded. The custom
settings, two-replica StorageClass, backup target, and daily backup job remain
unchanged. V2 and automatic volume-engine upgrades remain disabled.

Pre-upgrade configuration inventory:
`~/.talos/backups/longhorn-pre-1.13.0-20261107-164442/`.
A disposable kube103 persistence test using the v1.13.0 engine passed: the
single replica was on kube103, 32 MiB of random data survived a full detach and
reattach to an independent reader, and file size/SHA256 verification succeeded.
Test resources were removed and the existing 14 attached volumes remained
healthy. Evidence: `~/.talos/backups/longhorn-smoke-20261107164731/`.
