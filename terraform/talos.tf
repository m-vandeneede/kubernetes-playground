resource "talos_machine_configuration_apply" "talos" {
  for_each                       = local.cluster_vms
  depends_on                     = [proxmox_vm_qemu.cluster_vm, adguard_rewrite.cluster_mappings, adguard_rewrite.node_mappings]
  machine_configuration_input_wo = ephemeral.talos_machine_configuration.talos_conf[each.key].machine_configuration
  client_configuration_wo        = ephemeral.talos_client_configuration.talos_client_conf.client_configuration
  node                           = each.value.hostname

  config_patches = [
    yamlencode(
      {
        machine = {
          kubelet = {
            extraMounts = [
              {
                destination = "/var/lib/longhorn"
                type        = "bind"
                source      = "/var/lib/longhorn"
                options = [
                  "bind",
                  "rw",
                  "rshared"
                ]
              }
            ]
          }
          sysctls = {
            "vm.nr_hugepages" = "1024"
          }
          kernel = {
             modules = [
              {name = "nvme_tcp"},
              {name = "vfio_pci"}
            ]
          }
          install = {
            disk  = each.value.disk_device
            image = each.value.talos_image
          }
          network = {
            interfaces = [
              {
                interface = each.value.network_interface
                dhcp      = true
              }
            ]
          }
        }
      }
    ),
    yamlencode(
      {
        apiVersion = "v1alpha1",
        kind       = "HostnameConfig",
        auto       = "off",
        hostname   = each.value.hostname
      }
    ),
    yamlencode(
      {
        apiVersion = "v1alpha1",
        kind       = "ResolverConfig",
        nameservers = [
          {
            address = local.cluster_dns
          }
        ],
        searchDomains = {
          domains = [
            local.cluster_domain
          ]
          disableDefault = false
        }
      }
    )
  ]
}
