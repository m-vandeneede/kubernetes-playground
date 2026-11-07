# Documentation

Project documentation lives here; Terraform, scripts, and Kubernetes manifests
remain in their original source directories. Unless stated otherwise, run
repository commands from the repository root, not from `docs/`.

## Infrastructure and operations

- [CHONK deployment and operations](terraform/CHONK.md)
- [CREDIGREE retirement, quorum repair, and USB migration](terraform/RETIREMENT.md)
- [CHONK power tuning](terraform/CHONK-POWER.md)
- [SOUTHPARK power tuning](terraform/SOUTHPARK-POWER.md)
- [Shared host CPU power-policy service](terraform/host-power/README.md)
- [Longhorn deployment and upgrades](kubernetes/talos/cluster/longhorn/README.md)

## Inventory and historical context

These inventories include historical configurations; use the dated operations
notes above for the completed CHONK migration and CREDIGREE retirement.

- [Hardware overview](context/hardware.md)
- [VMs and container runtime](context/vm.md)
- [Archived Bazarr deployment note](kubernetes/archive/deploy/bazarr/readme.md)
