terraform {
    required_providers {
        proxmox = {
            source  = "Telmate/proxmox"
            version = "3.0.2-rc07"
        }
        talos = {
            source  = "siderolabs/talos"
            version = "0.11.0-beta.1"
        }
        routeros = {
            source  = "terraform-routeros/routeros"
            version = "1.99.0"
        }
    }
    backend "local" {
        path = "terraform.tfstate"
    }
}

provider "proxmox" {
    pm_api_url = var.proxmox_api_url
    pm_api_token_id   = var.proxmox_token_id
    pm_api_token_secret = var.proxmox_token_secret
    pm_tls_insecure = true
}
provider "routeros" {
    hosturl        = var.routeros_url        # env ROS_HOSTURL or MIKROTIK_HOST
    username       = var.routeros_user             # env ROS_USERNAME or MIKROTIK_USER
    password       = var.routeros_pass             # env ROS_PASSWORD or MIKROTIK_PASSWORD
    insecure       = true                          # env ROS_INSECURE or MIKROTIK_INSECURE
}