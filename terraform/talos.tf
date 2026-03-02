resource "talos_machine_configuration_apply" "talos" {
    for_each = local.controlplane_vms
    machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
    node = each.value.hostname
}