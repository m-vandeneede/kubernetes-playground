resource "adguard_rewrite" "node_mappings" {
  for_each = local.cluster_vms
  domain     = each.value.hostname
  answer     = each.value.ip_address
}
resource "adguard_rewrite" "cluster_mappings" {
  for_each = {
    for k, v in local.cluster_vms : k => v
    if try(v.controlplane, true)
  }
  domain     = local.cluster_hostname
  answer     = each.value.ip_address
}