locals {
  cluster_vlan = 70
  cluster_dhcp_server = "CLUSTER-DHCP"
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
  cluster_vms = {
    KUBE-001 = {
      hostname    = "kube001.vandeneede.org"
      ip_address  = "10.70.0.101"
      controlplane = true
      proxmox     = false
    }
    KUBE-002 = {
      hostname    = "kube002.vandeneede.org"
      ip_address  = "10.70.0.102"
      controlplane = true
      proxmox     = true
      target_node = local.proxmox_nodes.CREDIGREE
      memory      = 2048
      cores       = 2
      disk_pool   = "fast"
      disk_size   = "10G"
    }
    KUBE-003 = {
      hostname    = "kube003.vandeneede.org"
      ip_address  = "10.70.0.103"
      controlplane = true
      proxmox     = true
      target_node = local.proxmox_nodes.SOUTHPARK
      memory      = 2048
      cores       = 2
      disk_pool   = "fast"
      disk_size   = "10G"
    }
    KUBE-101 = {
      hostname    = "kube101.vandeneede.org"
      ip_address  = "10.70.0.111"
      controlplane = false
      proxmox     = true
      target_node = local.proxmox_nodes.CREDIGREE
      memory      = 2048
      cores       = 2
      disk_pool   = "fast"
      disk_size   = "10G"
    }
    KUBE-102 = {
      hostname    = "kube102.vandeneede.org"
      ip_address  = "10.70.0.112"
      controlplane = false
      proxmox     = true
      target_node = local.proxmox_nodes.SOUTHPARK
      memory      = 2048
      cores       = 2
      disk_pool   = "fast"
      disk_size   = "10G"
    }
  }
}
