# Plans only, with mocked infrastructure providers. Never create live resources.
mock_provider "proxmox" {}
mock_provider "routeros" {}
mock_provider "adguard" {}
mock_provider "talos" {}

run "safe_defaults" {
  command = plan

  assert {
    condition     = proxmox_vm_qemu.cluster_vm["KUBE-004"].memory == 4096 && proxmox_vm_qemu.cluster_vm["KUBE-004"].cpu[0].cores == 2
    error_message = "The control plane must have 4 GiB RAM and 2 vCPUs."
  }
  assert {
    condition     = proxmox_vm_qemu.cluster_vm["KUBE-103"].memory == 40960 && proxmox_vm_qemu.cluster_vm["KUBE-103"].cpu[0].cores == 8
    error_message = "The worker must have 40 GiB RAM and 8 vCPUs."
  }
  assert {
    condition = (
      proxmox_vm_qemu.cluster_vm["KUBE-103"].pcis[0].pci0[0].mapping[0].mapping_id == "chonk-rtx3060" &&
      proxmox_vm_qemu.cluster_vm["KUBE-103"].pcis[0].pci0[0].mapping[0].pcie &&
      !proxmox_vm_qemu.cluster_vm["KUBE-103"].pcis[0].pci0[0].mapping[0].primary_gpu &&
      alltrue([for name, vm in proxmox_vm_qemu.cluster_vm : length(vm.pcis) == 0 if name != "KUBE-103"])
    )
    error_message = "Only KUBE-103 may receive the RTX 3060 and its audio function, with PCIe and the virtual console retained."
  }
  assert {
    condition     = proxmox_vm_qemu.cluster_vm["KUBE-103"].disks[0].scsi[0].scsi1[0].disk[0].size == "500G" && proxmox_vm_qemu.cluster_vm["KUBE-103"].disks[0].scsi[0].scsi1[0].disk[0].serial == "kube103-longhorn"
    error_message = "The worker needs a dedicated 500 GiB disk with the expected stable serial."
  }
  assert {
    condition     = alltrue([for name in ["KUBE-004", "KUBE-103"] : proxmox_vm_qemu.cluster_vm[name].vm_state == "stopped" && proxmox_vm_qemu.cluster_vm[name].balloon == 0])
    error_message = "Both VMs must start stopped, without ballooning."
  }
  assert {
    condition     = !contains(keys(adguard_rewrite.cluster_mappings), "KUBE-004")
    error_message = "Cluster-endpoint publication requires a separate opt-in."
  }
  assert {
    condition     = local.chonk_schematics.controlplane == "c23d16533980fd972f96a79cc22130404615c16de18f43da4a40d801d4fe8d6a" && local.chonk_schematics.worker == "179a44da7532036d61547766f0272bf27283fa431dbf38614191c9116311a17c"
    error_message = "Installer references must use the supplied role-specific schematic IDs."
  }
  assert {
    condition     = var.talos_version == "1.14.5" && var.kubernetes_version == "1.37.2"
    error_message = "New nodes must use the current cluster versions."
  }
  assert {
    condition = alltrue([for name, role in { KUBE-004 = "controlplane", KUBE-103 = "worker" } : (
      local.cluster_vms[name].talos_image == "factory.talos.dev/nocloud-installer-secureboot/${local.chonk_schematics[role]}:v${var.talos_version}" &&
      proxmox_vm_qemu.cluster_vm[name].disks[0].ide[0].ide1[0].cdrom[0].iso == "local:iso/${role}_secureboot.iso"
    )])
    error_message = "Each node must reference its matching role-specific boot ISO and installer."
  }
  assert {
    condition = alltrue([for name in ["KUBE-003", "KUBE-102"] : (
      length(proxmox_vm_qemu.cluster_vm[name].disks[0].scsi) == 0 &&
      length(proxmox_vm_qemu.cluster_vm[name].disks[0].ide[0].ide0) == 1 &&
      proxmox_vm_qemu.cluster_vm[name].vm_state == var.vm_state
    )])
    error_message = "Existing nodes must retain their IDE layout and legacy state default."
  }
  assert {
    condition = (
      proxmox_vm_qemu.cluster_vm["KUBE-103"].usbs[0].usb0[0].device[0].device_id == "10c4:ea60" &&
      proxmox_vm_qemu.cluster_vm["KUBE-103"].usbs[0].usb1[0].device[0].device_id == "1a86:7523" &&
      !proxmox_vm_qemu.cluster_vm["KUBE-103"].usbs[0].usb0[0].device[0].usb3 &&
      !proxmox_vm_qemu.cluster_vm["KUBE-103"].usbs[0].usb1[0].device[0].usb3 &&
      alltrue([for name, vm in proxmox_vm_qemu.cluster_vm : length(vm.usbs) == 0 if name != "KUBE-103"])
    )
    error_message = "Only KUBE-103 may receive the Sonoff and printer USB adapters, using USB 2."
  }
  assert {
    condition = alltrue([for name in ["KUBE-002", "KUBE-101"] : (
      !contains(keys(local.cluster_vms), name) &&
      !contains(keys(proxmox_vm_qemu.cluster_vm), name) &&
      !contains(keys(adguard_rewrite.node_mappings), name) &&
      !contains(keys(adguard_rewrite.cluster_mappings), name) &&
      !contains(keys(routeros_ip_dhcp_server_lease.kube-node-ip-lease), name)
    )])
    error_message = "Retired CREDIGREE nodes must not remain in active VM, DNS, DHCP, or API-endpoint inventory."
  }
  assert {
    condition = alltrue([for name in ["KUBE-004", "KUBE-103"] : (
      adguard_rewrite.node_mappings[name].answer == local.cluster_vms[name].ip_address &&
      routeros_ip_dhcp_server_lease.kube-node-ip-lease[name].address == local.cluster_vms[name].ip_address
    )])
    error_message = "New nodes must use the shared DHCP and DNS loops."
  }
}

run "publish_controlplane_endpoint" {
  command = plan

  variables {
    chonk_publish_controlplane_endpoint = true
  }

  assert {
    condition     = adguard_rewrite.cluster_mappings["KUBE-004"].answer == "10.70.0.104"
    error_message = "Opting in must publish the new control-plane API address."
  }
  assert {
    condition     = !contains(keys(adguard_rewrite.cluster_mappings), "KUBE-103")
    error_message = "The worker must never be published as a cluster API endpoint."
  }
}
