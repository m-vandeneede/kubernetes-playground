# VMs & container runtime

## VMs

### KUBE-001.vandeneede.org

Hardware: Kube001  
OS: Talos  
Purpose: Kubernetes control plane node  

### KUBE-002.vandeneede.org
Hardware: Credigree  
OS: Talos  
Purpose: Kubernetes control plane node  
Disks:
- 1x 10GB Boot drive

### KUBE-003.vandeneede.org
Hardware: Southpark  
OS: Talos  
Purpose: Kubernetes control plane node  
Disks:
- 1x 10GB Boot drive

### KUBE-101.vandeneede.org
Hardware: Credigree  
OS: Talos  
Purpose: Kubernetes worker node  
Disks:
- 1x 50GB Boot drive
- 1x 150GB Longhorn volume drive

### KUBE-102.vandeneede.org
Hardware: Southpark  
OS: Talos  
Purpose: Kubernetes worker node  
Disks:
- 1x 50GB Boot drive
- 1x 150GB Longhorn volume drive

### Blub.vandeneede.org
Hardware: Southpark  
OS: Ubuntu Server  
Purpose: Jellyfin media server  
Disks:
- 1x 20GB Boot drive
- 1x 20GB Docker volumes drive
- 1x 100GB Jellyfin transcode cache drive

## Container runtime

Kubernetes is running on Talos, which uses containerd as the container runtime.

The kubernetes cluster consists of 3 control plane nodes (KUBE-001, KUBE-002, KUBE-003) and 2 worker nodes (KUBE-101, KUBE-102).

## Storage

Longhorn is used as the storage solution for Kubernetes, providing persistent storage for pods and applications.

Longhorn runs on the worker nodes (KUBE-101 and KUBE-102) and manages the attached storage drives to provide reliable and scalable storage for the Kubernetes cluster.

## Networking

MetalLB is used as the load balancer for the Kubernetes cluster, providing external access to services running within the cluster.

Following pools are configured in MetalLB:
- ingress-pool - 10.71.0.10-10.71.0.254 (for services not exposed to the internet)
- dmz-pool - 10.72.0.10-10.72.0.254 (for services exposed to the internet)

Traefik is used as the ingress controller for the Kubernetes cluster, managing incoming traffic and routing it to the appropriate services within the cluster.

Following ingress classes are configured in Traefik:
- internal - 10.71.0.10 (for services not exposed to the internet)
- external - 10.72.0.10 (for services exposed to the internet)

## Databases

Postgres and Mongodb are deployed in the cluster. Other workloads that require a database can use these databases as a service.
