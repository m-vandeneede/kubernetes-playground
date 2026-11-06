# CHONK expansion (preparation only)

No infrastructure has been applied. Keep CREDIGREE's nodes until the new nodes,
storage replicas, and workloads have been verified and migration is approved.

## Proposed VMs

| VM | Cluster address | vCPU | RAM | OS disk | Longhorn disk |
| --- | --- | --- | --- | --- | --- |
| KUBE-004 / kube004 | 10.70.0.104 | 2 | 4 GiB | 32 GiB | None |
| KUBE-103 / kube103 | 10.70.0.113 | 8 | 40 GiB | 32 GiB | 500 GiB |

Both use Q35, OVMF, host CPU passthrough, and no memory ballooning. Separate
entries in `local.cluster_vms` use the shared `proxmox_vm_qemu.cluster_vm`
resource, along with the existing DHCP and DNS loops. Existing resource
addresses remain intact; CHONK has no separate VM/DHCP/DNS resource copies.
VM IDs are assigned by Proxmox; node names do not imply VM IDs.

## Confirmed host prerequisites

Read-only inventory found approximately 54.8 GiB host RAM and a 1 TB SN570 NVMe.
The existing `pve/data` thin pool is approximately 794 GiB and unused, but is not
registered in Proxmox's storage configuration. The default `chonk_disk_pool`
(`local-lvm`) is the **proposed registration name**, not an existing storage ID.
Register the existing thin pool for CHONK after separate approval, or override
the variable with its eventual storage ID. Do not recreate/format the pool.

`fast` and `local` both currently use the approximately 94 GiB root filesystem.
Do not place the 500 GiB data disk there. The boot ISOs have already been uploaded
to CHONK's `local` storage and are referenced directly from `local.cluster_vms`:

- Control plane: `local:iso/controlplane_secureboot.iso`
- Worker: `local:iso/worker_secureboot.iso`

Terraform does not download, upload, replace, or own these ISOs. The pinned Telmate
provider does not manage registration of LVM-thin storage; that remains an
explicit external prerequisite.

The VM disks share one physical NVMe: the separate Longhorn disk is isolation,
not additional hardware redundancy. Longhorn replication to other hosts remains
necessary.

Verify VLAN 70/71/72 connectivity on CHONK's switch uplink and vmbr0, DHCP
reservations, address availability, and DNS before installing Talos. Configure
the guest VLANs and restrict kubelet node IPs to 10.70.0.0/24 separately, following
the existing node patches. Terraform does not generate CHONK-specific patches or
apply Talos configurations. The boot ISO initially uses maintenance-mode
networking; identify its reachable address when configuring each VM manually.

## Images, storage, and GPU placeholders

Defaults match the upgraded cluster: Talos 1.14.5 and Kubernetes 1.37.2.
The externally created schematics are pinned in `local.chonk_schematics`:

- Control plane: `c23d16533980fd972f96a79cc22130404615c16de18f43da4a40d801d4fe8d6a`
- Worker: `179a44da7532036d61547766f0272bf27283fa431dbf38614191c9116311a17c`

Both include QEMU Guest Agent, iSCSI tools, util-linux tools, and the existing
NFS compatibility extension. The worker additionally includes NVIDIA production
open kernel modules and the matching container toolkit. Neither includes CPU
microcode, AMD GPU firmware, or Intel drivers. Maintain CPU microcode on Proxmox.
Terraform only references these IDs; it does not create or modify Image Factory
schematics. Installer references use the same schematic ID and Talos version as
each role's ISO. The role-named ISO files are externally managed: keep their
contents aligned with those schematic/version references when replacing them.

Use the Secure Boot NoCloud ISO and installer together. The empty OVMF key store
(`pre_enrolled_keys = false`) allows Talos to enroll its own keys in the VM;
Microsoft pre-enrolled keys alone do not establish trust for the Talos image.
Verify Secure Boot state after installation; do not assume that selecting OVMF
alone enables it. Host Secure Boot state is separate from guest Secure Boot.

The worker's SCSI data disk has serial `kube103-longhorn`. Configure its Talos
UserVolumeConfig separately to select that serial AND exclude the system disk,
then mount at `/var/mnt/longhorn`. Confirm the reported serial first, configure
the kubelet bind mount, and register the mounted filesystem with Longhorn.
Terraform only creates the virtual disk; it does not format/mount it or register
it with Longhorn. No existing Longhorn settings or disks are changed by this code.

### RTX 3060 passthrough

Proxmox API inventory confirms the following devices, alone in IOMMU group 16:

- `0000:0a:00.0`: RTX 3060 (GA106), `10de:2503`
- `0000:0a:00.1`: HDMI audio, `10de:228e`

`local.cluster_vms.KUBE-103.gpu_pci_mapping = "chonk-rtx3060"` passes all functions
through the shared resource's `pcis.pci0.mapping` block. The externally managed
Proxmox mapping selects `0000:0a:00` on CHONK, with vendor/device `10de:2503`,
subsystem `10de:1522`, and IOMMU group 16. The Terraform user has
`PVEMappingUser` scoped to `/mapping/pci/chonk-rtx3060`; raw PCI assignment was
rejected by Proxmox's root-only restriction. PCIe is enabled; the card
is not the primary display, preserving the virtual Talos console. Q35, OVMF,
host CPU and disabled ballooning are already configured.

Host VFIO configuration and initramfs rebuild are complete. After the approved
reboot both functions use `vfio-pci` and cluster quorum recovered. The scoped
Terraform apply succeeded: VM 108 now has
`hostpci0: mapping=chonk-rtx3060,pcie=1`. Both CHONK VMs remain stopped pending
separate startup approval. The steps below retain the host setup procedure.

The worker schematic includes `nvidia-open-gpu-kernel-modules-production` and
`nvidia-container-toolkit-production`, suitable for the Ampere RTX 3060.
The worker patch now requests `nvidia`, `nvidia_uvm`, `nvidia_modeset`, and
`nvidia_drm`. This updated patch has not been sent to the live node.

Before applying:

1. Inspect CHONK over SSH: `lspci -nnk -s 0a:00`, `/proc/cmdline`,
   `/sys/kernel/iommu_groups/16/devices`, and the GPU's `boot_vga`/driver links.
   SSH: `ssh -i ~/.ssh/credigree -o IdentitiesOnly=yes root@192.168.3.4`.
   Inspection confirmed AMD IOMMU and interrupt remapping enabled. GPU driver
   is `nouveau`; audio driver is `snd_hda_intel`. No persistent VFIO setup exists.
   The RTX 3060 is the only display adapter and has `boot_vga=1`; dedicating it
   to the VM removes it from host use. No active framebuffer or DRM user was
   reported at inspection time.
2. Ensure both functions are available to `vfio-pci` and not required by the host.
   If persistent binding is needed, use the verified IDs `10de:2503,10de:228e`
   in the host VFIO configuration, rebuild initramfs and arrange a host reboot.
   Check existing bootloader configuration before changing kernel parameters.
   IOMMU groups already exist; do not add ACS override or disable Secure Boot.
   A CHONK reboot also affects kube004 and must be coordinated separately.
   Suggested persistent host setup (not yet executed):

   - `/etc/modprobe.d/vfio.conf`: `options vfio-pci ids=10de:2503,10de:228e`
   - `/etc/modprobe.d/blacklist-nouveau.conf`: `blacklist nouveau`
   - Append `vfio`, `vfio_iommu_type1`, and `vfio_pci` to
     `/etc/initramfs-tools/modules`, preserving existing content.
   - Run `update-initramfs -u -k all`, then reboot in the agreed maintenance window.
   - Verify both functions report `Kernel driver in use: vfio-pci` before VM start.

   Do not blacklist `snd_hda_intel` globally: binding the specific GPU audio ID
   avoids affecting unrelated host audio devices. No IOMMU boot argument is
   currently necessary. `proxmox-boot-tool status` reports no configured ESP UUID
   file; do not assume a managed systemd-boot installation.
3. Review a fresh plan targeted **only** at
   `proxmox_vm_qemu.cluster_vm["KUBE-103"]`, with `-var=chonk_vm_state=running`
   to avoid the creation-time stopped default. Confirm only the expected PCI
   change; do not use an unrestricted apply while legacy drift remains.
4. Drain kube103 normally, respecting PDBs, and shut it down before assigning
   the device. Plan again after shutdown and review power-state changes before
   applying. Start it and verify the PCI device is visible inside Talos.
5. Dry-run and approve the updated Talos configuration before applying it.
   Verify NVIDIA modules and extension services, Secure Boot, and node readiness.
6. Configure the NVIDIA container runtime/RuntimeClass and device plugin to
   advertise `nvidia.com/gpu` for workloads; do not install another host driver
   through GPU Operator. Kubernetes GPU allocation is a separate follow-up.

Longhorn's `master-head` image/CRD mismatch is independent of GPU passthrough and
still needs resolution before relying on this worker for persistent workloads.

## Deployment gates

- `chonk_vm_state = "stopped"`: create networking and boot assets first.
- Talos configuration is applied outside Terraform. No active machine-configuration
  application or bootstrap resource is defined, and no new cluster secrets are
  created. Reuse the existing cluster secrets when preparing configurations.
- `chonk_publish_controlplane_endpoint = false`: do not advertise kube004's API
  address before its API server and etcd membership are healthy.
- The generic VM resource has `prevent_destroy` lifecycle protection.

After the worker joins, verify its disk mount, Longhorn readiness and replicas
before moving workloads. Adding a fourth control plane temporarily requires
three votes and does not improve the failure tolerance of the existing
three-member etcd cluster. Remove the old control plane only in a separately
reviewed migration that restores three members and failure-domain separation.

## Validation and dry runs

Run from the repository root:

```sh
mise install
mise exec -- terraform -chdir=terraform init -input=false -lockfile=readonly
mise exec -- terraform -chdir=terraform validate
mise exec -- terraform -chdir=terraform test
```

The tests use mocked providers and **plan**, never apply. They cover memory/CPU,
the 500 GiB disk and serial, stopped VMs, endpoint publication, versions, fixed
ISO paths, and unchanged legacy VM layout.

**Do not apply a normal full-project plan yet.** Existing `cluster_vms` definitions
and state are stale relative to manually resized/running VMs. The attempted
full plan showed control planes shrinking from 4 to 2 GiB and changing from
running to stopped, then timed out during legacy VM guest-agent refresh. No
refresh-only apply or state mutation was performed. Audit legacy drift before
any full-project apply; it is deliberately not hidden with ignore_changes.

For an exceptional, review-only plan of the additive CHONK resources:

```sh
mise exec -- terraform -chdir=terraform plan -input=false \
  '-target=proxmox_vm_qemu.cluster_vm["KUBE-004"]' \
  '-target=proxmox_vm_qemu.cluster_vm["KUBE-103"]' \
  '-target=routeros_ip_dhcp_server_lease.kube-node-ip-lease["KUBE-004"]' \
  '-target=routeros_ip_dhcp_server_lease.kube-node-ip-lease["KUBE-103"]' \
  '-target=adguard_rewrite.node_mappings["KUBE-004"]' \
  '-target=adguard_rewrite.node_mappings["KUBE-103"]'
```

The expected scoped plan is **6 additions, no updates, no deletions**: two VMs,
two DHCP leases, and two DNS records. Image Factory schematics and ISO downloads
are not Terraform resources. The last live plan, before this simplification, was
blocked by a RouterOS timeout connecting to 192.168.3.1:8729. The mocked tests
cover the shared DHCP/DNS mappings. Rerun a complete live plan once connectivity
is restored. Targeting is not a substitute for resolving full-project drift,
nor does a plan establish that the unregistered storage exists or that a node
can successfully boot/join.

On this Mac, direct provider/Python LAN access failed while curl succeeded. The
scoped plan was inspected using a temporary loopback GET-only curl relay; it
was shut down afterward and the stored API URL was not changed. Fix local-network
permissions/connectivity for the actual Terraform provider executables before
deployment. Do not apply the diagnostic plan containing that temporary URL.

Keep tfvars, state, generated configs, and saved plans private: they can contain
credentials. The Talos provider is pinned to stable 0.11.0 for the existing
ephemeral role-configuration generation; CHONK configuration application and its
unused credential/patch plumbing have been removed.
