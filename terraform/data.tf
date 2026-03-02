data "talos_machine_configuration" "controlplane" {
  cluster_endpoint   = var.talos_cluster_endpoint
  cluster_name       = var.talos_cluster_name
  machine_type       = "controlplane"
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  machine_secrets = {
    certs = {
      etcd = {
        cert = var.talos_etcd_cert
        key  = var.talos_etcd_key
      }
      k8s = {
        cert = var.talos_k8s_cert
        key  = var.talos_k8s_key
      }
      k8s_aggregator = {
        cert = var.talos_k8s_aggregator_cert
        key  = var.talos_k8s_aggregator_key
      }
      k8s_serviceaccount = {
        key = var.talos_k8s_serviceaccount_key
      }
      os = {
        cert = var.talos_os_cert
        key  = var.talos_os_key
      }
    }
    cluster = {
      id     = var.talos_cluster_id
      secret = var.talos_cluster_secret
    }
    secrets = {
      bootstrap_token             = var.talos_cluster_bootstrap_token
      secretbox_encryption_secret = var.talos_cluster_secretbox_encryptionsecret
    }
    trustdinfo = {
      token = var.talos_trustd_token
    }
  }
}
