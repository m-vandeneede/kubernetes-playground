# SOUTHPARK CPU power-policy experiment

## Applied temporarily — 2026-11-07

Host: SOUTHPARK, Proxmox, Intel Core i3-10100 (4 cores / 8 threads).
CPU driver: `intel_pstate`, active. Applied on the Proxmox host, not in a VM.

All eight `/sys/devices/system/cpu/cpufreq/policy*` policies changed:

| Setting | Before | After |
| --- | --- | --- |
| `scaling_governor` | `performance` | `powersave` |
| `energy_performance_preference` | `performance` | `balance_performance` |

Equivalent commands as root on SOUTHPARK:

```sh
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  printf 'powersave\n' > "$policy/scaling_governor"
  printf 'balance_performance\n' > "$policy/energy_performance_preference"
done
```

Verified unchanged:

- Frequency limits: 800000–4300000 kHz (800 MHz–4.3 GHz).
- Turbo enabled: `/sys/devices/system/cpu/intel_pstate/no_turbo=0`.
- KSM enabled: `/sys/kernel/mm/ksm/run=1`; ksmtuned was not changed.
- VM power states unchanged; all five Kubernetes nodes remained Ready.

At this initial experiment stage, no persistent service, boot parameter,
frequency cap, or BIOS change was added.
Settings may revert after reboot or a policy-management service changes them.
No post-change wall-power reduction has yet been measured. Immediate reported
clock readings were still around 4.1–4.2 GHz; those readings alone are not a
measurement of power savings or time spent in idle states.

Original per-policy settings and turbo/KSM state were saved on SOUTHPARK at:
`/root/cpu-policy-before-20261107-224344.json`.

To restore the verified original CPU policy as root on SOUTHPARK:

```sh
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  printf 'performance\n' > "$policy/energy_performance_preference"
  printf 'performance\n' > "$policy/scaling_governor"
done
```

## Why KSM was left enabled

The preceding audit found approximately 1.5 GiB available RAM, 1.3 GiB swap
usage, and approximately 2 GiB saved through shared pages before overhead.
KSM's net-profit estimate was positive (approximately 1.48 GiB). This differs
from CHONK's low-sharing, negative-net-profit situation; do not copy CHONK's
KSM-disable setting without a separate memory-capacity review.

## CPU policy persisted — 2026-11-07

Separately approved after the user reported no observable power decrease but
chose to retain the balanced settings. Installed the shared files from
[`host-power/`](host-power/README.md):

- `/usr/local/sbin/host-cpu-power-policy.py` (root, 0755).
- `/etc/systemd/system/host-cpu-power-policy.service` (root, 0644).

Ran `systemctl daemon-reload` and
`systemctl enable --now host-cpu-power-policy.service`. Verified `enabled`,
`active (exited)`, and `ExecMainStatus=0`, with all eight policies set to
`powersave` + `balance_performance` and unchanged frequency limits. The script
does not change turbo or KSM. ksmtuned remains enabled and active with `run=1`.

The oneshot runs at boot before `pve-guests.service`; it is not continuous policy
enforcement. Pre-install state is saved on SOUTHPARK at
`/root/cpu-policy-persistence-before-20261107-224807.json`.
No host reboot or guest restart was performed; next-boot execution is not yet
tested. To roll back persistence, disable the service before restoring runtime
`performance` settings; see the shared README.
