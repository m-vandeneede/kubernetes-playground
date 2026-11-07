# CREDIGREE Talos node retirement

KUBE-002 (VM 101, `10.70.0.102`) and KUBE-101 (VM 104, `10.70.0.111`)
were removed from etcd/Kubernetes/Longhorn on 2026-11-07. They are no longer
in `local.cluster_vms`; their node DNS rewrites, KUBE-002 API-endpoint rewrite,
and DHCP reservations should be deleted when an explicitly reviewed plan is applied.

## Preserve the VMs and disks

The old VMs must remain powered off. Reset/reprovision them before future reuse.
No VM or disk destruction is part of this retirement.

Terraform's `removed` block does not accept individual `for_each` instance keys.
Before planning/applying this inventory cleanup against existing state:

1. Securely back up `terraform.tfstate` outside Git (it contains secrets).
2. Review the exact instances to forget:

   ```sh
   terraform state rm -dry-run \
     'proxmox_vm_qemu.cluster_vm["KUBE-002"]' \
     'proxmox_vm_qemu.cluster_vm["KUBE-101"]'
   ```

3. With approval, run the same command without `-dry-run`. This relinquishes
   Terraform ownership only; it does not contact Proxmox or delete VMs/disks.
4. Inspect a fresh plan. Retired networking records should be destroyed, but
   neither retired VM should have a destroy action. The shared VM resource's
   `prevent_destroy` is retained as a safeguard until the instances are forgotten.

Applied on 2026-11-07: securely backed up state, forgot exactly the two retired
VM instances, and deleted their five DNS/DHCP records with a scoped plan.
Neither VM nor its disks were deleted. Evidence and state backups are under
`~/.talos/backups/usb-retirement-20261107-210934/`.

Do not apply an unrestricted plan: existing RAM/power drift remains, and
`chonk_vm_state` still defaults to `stopped` although CHONK VMs are running.

## USB migration to KUBE-103

The shared VM resource now optionally forwards these devices to KUBE-103 (VM 108):

| Slot | Device | Vendor/product ID |
| --- | --- | --- |
| usb0 | Sonoff Zigbee 3.0 USB Dongle Plus | `10c4:ea60` |
| usb1 | Ender 3 CH340 serial adapter | `1a86:7523` |

Both were detected on CHONK, and their host `/dev/serial/by-id/` names match
`kubernetes/talos/cluster/serial-devices/daemonset.yaml`. Keep that manifest's
existing paths unless guest verification shows a difference. The device plugin
already runs on KUBE-103; workload device requests provide automatic placement.
Vendor/product selection assumes only one matching adapter of each kind on CHONK.

Before applying USB passthrough, explicitly stop Zigbee2MQTT: it currently has
one Pending replica and can start automatically when `devic.es/zigbee` becomes
available. Preserve GitOps intent when stopping it. Printer workloads are scaled
to zero. Do not start applications as part of passthrough verification.

Review a narrowly scoped plan with `chonk_vm_state=running` for the USB change;
it must preserve GPU assignment, disks, memory, Secure Boot, and startup settings.
If USB hotplug is insufficient, obtain approval for a separate maintenance reboot
rather than forcing a drain or bypassing PDBs. Afterward verify Talos serial paths
and `devic.es/zigbee=1` / `devic.es/printer=1` on KUBE-103 before starting workloads.

### Applied status

The Terraform token was denied direct USB assignment (`only root can set ...
config for real devices`). The user added both adapters manually in Proxmox;
Terraform state was then reconciled using a scoped refresh-only apply. The
subsequent KUBE-103 plan with `chonk_vm_state=running` reported no changes.
Future direct USB assignment/removal may still require root or named USB
mappings with scoped mapping permissions; no USB mappings or ACLs were created.

Verified both expected serial paths in Talos and both device resources allocatable
as `1` on KUBE-103. The existing generic-device-plugin required no changes.
All 13 attached Longhorn volumes remained healthy; five others remained detached.

Zigbee2MQTT was explicitly scaled to zero and its Argo CD Application's
`spec.syncPolicy.automated.enabled` set to `false` to prevent automatic startup.
Both printer workloads remain scaled to zero. Application startup and restoration
of Zigbee2MQTT auto-sync require a separate decision; the original Application
and Deployment are backed up in the evidence directory above.
