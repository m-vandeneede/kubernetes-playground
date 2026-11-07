# CHONK deployment and operations

For the separately applied host CPU power-policy experiment, exact settings,
rollback, and measurements, see [CHONK-POWER.md](CHONK-POWER.md).

Both CHONK VMs are deployed and running. kube004 is a healthy voting control
plane; kube103 provides Longhorn storage, GPU passthrough, and serial devices.
CREDIGREE's Kubernetes/etcd/Longhorn and Proxmox memberships have been removed.
Its VM definitions are archived and disks preserved; see [RETIREMENT.md](RETIREMENT.md).

## Deployed VMs

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
The existing `pve/data` thin pool is approximately 794 GiB and is registered as
`local-lvm`, matching `chonk_disk_pool`. Both VM disks and the 500 GiB Longhorn
disk use it. Do not recreate or format the pool.

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

## Images, storage, and GPU

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
`hostpci0: mapping=chonk-rtx3060,pcie=1`. Both CHONK VMs are running.
The steps below retain the historical host setup procedure, not pending work.

The worker schematic includes `nvidia-open-gpu-kernel-modules-production` and
`nvidia-container-toolkit-production`, suitable for the Ampere RTX 3060.
The worker patch now requests `nvidia`, `nvidia_uvm`, `nvidia_modeset`, and
`nvidia_drm`. The patch is applied; GPU access and H.264 NVENC encoding have been
verified in a temporary container with Secure Boot retained. Permanent NVIDIA
device-plugin allocation versus time-slicing remains a separate decision.

Historical passthrough setup (completed except permanent workload allocation):

1. Inspect CHONK over SSH: `lspci -nnk -s 0a:00`, `/proc/cmdline`,
   `/sys/kernel/iommu_groups/16/devices`, and the GPU's `boot_vga`/driver links.
   SSH: `ssh -i ~/.ssh/credigree -o IdentitiesOnly=yes root@192.168.3.4`.
   Inspection confirmed AMD IOMMU and interrupt remapping enabled. GPU driver
   was initially `nouveau`; audio used `snd_hda_intel` before VFIO binding.
   The RTX 3060 is the only display adapter and has `boot_vga=1`; dedicating it
   to the VM removes it from host use. No active framebuffer or DRM user was
   reported at inspection time.
2. Ensure both functions are available to `vfio-pci` and not required by the host.
   If persistent binding is needed, use the verified IDs `10de:2503,10de:228e`
   in the host VFIO configuration, rebuild initramfs and arrange a host reboot.
   Check existing bootloader configuration before changing kernel parameters.
   IOMMU groups already exist; do not add ACS override or disable Secure Boot.
   A CHONK reboot also affects kube004 and must be coordinated separately.
   Persistent host setup applied:

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
   (now also the default). Confirm only the expected PCI change and review the
   complete plan before applying.
4. Drain kube103 normally, respecting PDBs, and shut it down before assigning
   the device. Plan again after shutdown and review power-state changes before
   applying. Start it and verify the PCI device is visible inside Talos.
5. Dry-run and approve the updated Talos configuration before applying it.
   Verify NVIDIA modules and extension services, Secure Boot, and node readiness.
6. Configure the NVIDIA container runtime/RuntimeClass and device plugin to
   advertise `nvidia.com/gpu` for workloads; do not install another host driver
   through GPU Operator. Kubernetes GPU allocation is a separate follow-up.

Longhorn's management plane is upgraded to v1.13.0 and kube103 persistence was
verified across detach/reattach. All 18 volumes have replicas on kube102/kube103.
Existing volume engines still use historical `master-head`; controlled engine
upgrades are separate work. Do not remove their active instance managers.

## Deployment gates

- `vm_state = "running"` and `chonk_vm_state = "running"` preserve deployed VMs.
  For new provisioning, explicitly use `chonk_vm_state = "stopped"` until ready.
- Talos configuration is applied outside Terraform. No active machine-configuration
  application or bootstrap resource is defined, and no new cluster secrets are
  created. Reuse the existing cluster secrets when preparing configurations.
- API endpoint DNS follows `controlplane = true` in the active inventory;
  kube004 no longer needs a separate publication gate.
- The generic VM resource has `prevent_destroy` lifecycle protection.

The remaining etcd voters are kube001, kube003, and kube004 (two votes required).
Proxmox consists of SOUTHPARK and CHONK plus the external qdevice: three votes,
quorum two. Both qdevice clients are connected and enabled at boot. This does
not replace application/storage health checks or a PDB-respecting drain before
any separately approved host maintenance.

## Validation and dry runs

Run from the repository root:

```sh
mise install
mise exec -- terraform -chdir=terraform init -input=false -lockfile=readonly
mise exec -- terraform -chdir=terraform validate
mise exec -- terraform -chdir=terraform test
```

The tests use mocked providers and **plan**, never apply. They cover memory/CPU,
the 500 GiB disk and serial, running VMs, endpoint publication, versions, fixed
ISO paths, verified SOUTHPARK sizing and IDE layout, and provisioning overrides.

Review a complete live plan before applying:

```sh
mise exec -- terraform -chdir=terraform plan -input=false
```

Sizing was reconciled with live Proxmox configuration on 2026-11-07: KUBE-003
has 4 GiB RAM, 2 vCPUs and a 10 GiB OS disk; KUBE-102 has 16 GiB RAM, 3 vCPUs,
a 50 GiB OS disk and a 150 GiB Longhorn disk. Power defaults now preserve all
running VMs. State may still contain older values until refreshed; do not hide
drift with `ignore_changes`. API DNS records follow active control-plane
membership without a separate publication variable. Reject unexpected VM updates, disk
changes, replacements or deletions, and investigate before applying.

The full refreshed review plan on 2026-11-07 passed with **one addition**:
`adguard_rewrite.cluster_mappings["KUBE-004"]` (`kubelab.vandeneede.org` to
`10.70.0.104`), and **no VM updates or deletions**. Existing startup/shutdown
defaults are explicitly preserved by the shared VM resource. The DNS addition
was subsequently applied from a fresh verified saved plan; the post-apply full
plan reported **no changes**. The temporary endpoint-publication variable was
removed. Private pre-apply state backup, plan and apply evidence are in
`~/.talos/backups/terraform-controlplane-dns-20261107-230945/`.

Historical macOS provider LAN connectivity failures and guest-agent refresh
timeouts were observed. If they recur, report the blocked validation rather
than bypassing refresh or applying a diagnostic plan with temporary endpoints.

Keep tfvars, state, generated configs, and saved plans private: they can contain
credentials. The Talos provider is pinned to stable 0.11.0 for the existing
ephemeral role-configuration generation; CHONK configuration application and its
unused credential/patch plumbing have been removed.
