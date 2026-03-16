ephemeral "talos_machine_configuration" "talos_conf" {
  for_each           = local.cluster_vms
  cluster_endpoint   = var.talos_cluster_endpoint
  cluster_name       = var.talos_cluster_name
  machine_type       = (each.value.controlplane ? "controlplane" : "worker")
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

ephemeral "talos_client_configuration" "talos_client_conf" {
  cluster_name = var.talos_cluster_name

  client_configuration = {
    ca_certificate     = var.talos_client_ca
    client_certificate = var.talos_client_cert
    client_key         = var.talos_client_key
  }
}

data "talos_image_factory_extensions_versions" "rpi_extensions_info" {
  talos_version = var.talos_version
  filters = {
    names = [
      "siderolabs/iscsi-tools",
      "siderolabs/nfs-utils",
      "siderolabs/util-linux-tools"
    ]
  }
}

data "talos_image_factory_extensions_versions" "amd_extensions_info" {
  talos_version = var.talos_version
  filters = {
    names = [
      "siderolabs/amd-ucode",
      "siderolabs/amdgpu",
      "siderolabs/iscsi-tools",
      "siderolabs/nfs-utils",
      "siderolabs/util-linux-tools"
    ]
  }
}

data "talos_image_factory_extensions_versions" "intel_extensions_info" {
  talos_version = var.talos_version
  filters = {
    names = [
      "siderolabs/i915",
      "siderolabs/intel-ucode",
      "siderolabs/iscsi-tools",
      "siderolabs/nfs-utils",
      "siderolabs/util-linux-tools"
    ]
  }
}

resource "talos_image_factory_schematic" "talos_rpi" {
  schematic = yamlencode(
    {
      overlay = {
        image = "siderolabs/sbc-raspberrypi"
        name  = "rpi_generic"
        options = {
          overlay = {
            options = {
              configTxt = <<-EOT
                dtoverlay=gpio-fan,gpiopin=14
                gpu_mem=8
              EOT
            }
          }
        }
      }
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.rpi_extensions_info.extensions_info.*.name
        }
      }
    }
  )
}

resource "talos_image_factory_schematic" "talos_amd" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.amd_extensions_info.extensions_info.*.name
        }
      }
    }
  )
}

resource "talos_image_factory_schematic" "talos_intel" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.intel_extensions_info.extensions_info.*.name
        }
      }
    }
  )
}