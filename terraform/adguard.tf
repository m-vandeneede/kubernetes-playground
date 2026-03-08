resource "adguard_rewrite" "node_mappings" {
  for_each = local.cluster_vms
  domain     = each.value.hostname
  answer     = each.value.ip_address
}