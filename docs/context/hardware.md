# Hardware overview

## Compute

### Southpark

A custom built mini-pc with an Intel Core i3-10100, 32GB memory and a 500GB NVMe SSD drive.
This node runs Proxmox VE.

### Credigree

A HP EliteDesk 705 G4 SFF with an AMD Ryzen 3 PRO 2200G, 32GB memory and a 250GB Sata SSD drive.
This node runs Proxmox VE.

### Kube001

A Raspberry Pi 4, with 4GB memory and a 500GB NVMe drive through an USB3 enclosure.
This node runs Talos.

## Network

### Router

MikroTik RB5009UG+S+IN

### Switch

Netgear GC728X

## Storage

### Vault

A Synology DS1515+, with its firmware spoofed to DS1517+ to be able to run DSM7.2.
3x 10TB HDD in a Synology Hybrid Raid
2x 1TB SSD in a Synology Hybrid Raid

### Backupvault

A Synology DS218play.
2x 4TB HDD in raid1
