# Proxmox
variable "proxmox_token_id" {
	description = "Proxmox API token ID"
	type        = string
}
variable "proxmox_token_secret" {
	description = "Proxmox API token"
	type        = string
	sensitive   = true
}
variable "proxmox_api_url" {
    description = "Proxmox API URL"
    type        = string
    default     = "https://node.southpark.vandeneede.org:8006/api2/json"
}

# Talos
variable "talos_version" {
	description = "Talos version to use for the cluster"
	type        = string
	default     = "1.12.4"
}
variable "kubernetes_version" {
	description = "Kubernetes version to use for the cluster"
	type        = string
	default     = "1.35.0"
}
variable "talos_cluster_endpoint" {
	description = "Talos cluster endpoint"
	type        = string
}
variable "talos_cluster_name" {
	description = "Talos cluster name"
	type        = string
}
variable "talos_cluster_id" {
	description = "Talos cluster ID"
	type        = string
}
variable "talos_cluster_secret" {
	description = "Talos cluster secret"
	type        = string
	sensitive   = true
}
variable "talos_cluster_bootstrap_token" {
	description = "Talos cluster bootstrap token"
	type        = string
	sensitive   = true
}
variable "talos_cluster_secretbox_encryptionsecret" {
	description = "Talos cluster secretbox encryption secret"
	type        = string
	sensitive   = true
}
variable "talos_trustd_token" {
	description = "Talos trustd token"
	type        = string
	sensitive   = true
}
variable "talos_os_cert" {
	description = "Talos OS certificate"
	type        = string
}
variable "talos_os_key" {
	description = "Talos OS key"
	type        = string
	sensitive   = true
}
variable "talos_k8s_aggregator_cert" {
	description = "Talos Kubernetes aggregator certificate"
	type        = string
}
variable "talos_k8s_aggregator_key" {
	description = "Talos Kubernetes aggregator key"
	type        = string
	sensitive   = true
}
variable "talos_k8s_serviceaccount_key" {
	description = "Talos Kubernetes service account key"
	type        = string
	sensitive   = true
}
variable "talos_k8s_cert" {
	description = "Talos Kubernetes certificate"
	type        = string
}
variable "talos_k8s_key" {
	description = "Talos Kubernetes key"
	type        = string
	sensitive   = true
}
variable "talos_etcd_cert" {
	description = "Talos etcd certificate"
	type        = string
}
variable "talos_etcd_key" {
	description = "Talos etcd key"
	type        = string
	sensitive   = true
}