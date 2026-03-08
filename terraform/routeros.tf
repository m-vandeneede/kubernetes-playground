resource "routeros_ip_dhcp_server_lease" "kube-node-ip-lease" {
    for_each = {
        for k, v in local.cluster_vms : k => v
        if try(v.proxmox, false)
    }
    address     = each.value.ip_address
    mac_address = proxmox_vm_qemu.cluster_vm[each.key].network.0.macaddr
    comment     = each.key
    server      = local.cluster_dhcp_server
}
