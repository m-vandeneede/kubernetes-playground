locals {
  cluster_vlan        = 70
  cluster_dhcp_server = "CLUSTER-DHCP"
  cluster_dns         = "192.168.210.2"
  cluster_hostname    = "kubelab"
  cluster_domain      = "vandeneede.org"
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
      hostname          = "kube001.vandeneede.org"
      ip_address        = "10.70.0.101"
      controlplane      = true
      proxmox           = false
      disk_device       = "/dev/sda"
      network_interface = "end0"
      talos_image       = "factory.talos.dev/metal-installer/cc30f2743c6787dce64130ff08f73ed4b23382389a57cbb92196c666df493598:v${var.talos_version}"
    }
    KUBE-002 = {
      hostname          = "kube002.vandeneede.org"
      ip_address        = "10.70.0.102"
      controlplane      = true
      proxmox           = true
      target_node       = local.proxmox_nodes.CREDIGREE
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/3abf06e1d81e509d779dc256f9feae6cd6d82c69337c661cbfc383a92594faf5:v${var.talos_version}"
    }
    KUBE-003 = {
      hostname          = "kube003.vandeneede.org"
      ip_address        = "10.70.0.103"
      controlplane      = true
      proxmox           = true
      target_node       = local.proxmox_nodes.SOUTHPARK
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/3abf06e1d81e509d779dc256f9feae6cd6d82c69337c661cbfc383a92594faf5:v${var.talos_version}"
    }
    KUBE-101 = {
      hostname          = "kube101.vandeneede.org"
      ip_address        = "10.70.0.111"
      controlplane      = false
      proxmox           = true
      target_node       = local.proxmox_nodes.CREDIGREE
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/3abf06e1d81e509d779dc256f9feae6cd6d82c69337c661cbfc383a92594faf5:v${var.talos_version}"
    }
    KUBE-102 = {
      hostname          = "kube102.vandeneede.org"
      ip_address        = "10.70.0.112"
      controlplane      = false
      proxmox           = true
      target_node       = local.proxmox_nodes.SOUTHPARK
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/3abf06e1d81e509d779dc256f9feae6cd6d82c69337c661cbfc383a92594faf5:v${var.talos_version}"
    }
  }
}
