locals {
  cluster_vlan = 70
  proxmox_nodes = {
    CREDIGREE = {
      node_name        = "CREDIGREE"
      iso_installation = "fast:iso/nocloud-amd64.iso"
    }
    SOUTHPARK = {
      node_name        = "SOUTHPARK"
      iso_installation = "local:iso/nocloud-amd64.iso"
    }
  }
  controlplane_vms = {
    KUBE-001 = {
      hostname    = "kube001.vandeneede.org"
      proxmox     = false
    }
    KUBE-002 = {
      hostname    = "kube002.vandeneede.org"
      proxmox     = true
      target_node = local.proxmox_nodes.CREDIGREE
      memory      = 2048
      cores       = 2
      disk_pool   = "fast"
      disk_size   = "10G"
    }
    KUBE-003 = {
      hostname    = "kube003.vandeneede.org"
      proxmox     = true
      target_node = local.proxmox_nodes.SOUTHPARK
      memory      = 2048
      cores       = 2
      disk_pool   = "fast"
      disk_size   = "10G"
    }
  }
}
