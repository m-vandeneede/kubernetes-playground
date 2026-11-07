# Proxmox CPU power-policy persistence

Shared by CHONK (`amd-pstate-epp`) and SOUTHPARK (`intel_pstate`). The oneshot
service sets all currently exposed CPU policies to `powersave` with
`balance_performance` before Proxmox's guest autostart service. It verifies the
result and unchanged frequency limits; it does not change boost, KSM, or VMs.
It validates drivers and rolls back partially applied CPU settings on failure.

Files on each host:

| Repo source | Host destination |
| --- | --- |
| [`terraform/host-power/host-cpu-power-policy.py`](../../../terraform/host-power/host-cpu-power-policy.py) | `/usr/local/sbin/host-cpu-power-policy.py` (root, 0755) |
| [`terraform/host-power/host-cpu-power-policy.service`](../../../terraform/host-power/host-cpu-power-policy.service) | `/etc/systemd/system/host-cpu-power-policy.service` (root, 0644) |

After copying the reviewed files, enable and run as root:

```sh
systemctl daemon-reload
systemctl enable --now host-cpu-power-policy.service
systemctl status host-cpu-power-policy.service
```

Expected service state: `enabled`, `active (exited)`. No reboot is required.
This is a boot-time application, not a continuous policy-enforcement daemon;
another tool can override the settings later. CPU hotplug or driver reload may
require `systemctl restart host-cpu-power-policy.service`.

To stop applying the policy at future boots:

```sh
systemctl disable --now host-cpu-power-policy.service
```

Stopping the service does **not** change the currently applied settings. To also
restore the verified original runtime policy on these hosts:

```sh
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  printf 'performance\n' > "$policy/energy_performance_preference"
  printf 'performance\n' > "$policy/scaling_governor"
done
```

KSM remains separately managed: disabled at boot on CHONK, enabled on SOUTHPARK.
See [CHONK-POWER.md](../CHONK-POWER.md) and
[SOUTHPARK-POWER.md](../SOUTHPARK-POWER.md) for measurements and host-specific
backups. These files are not automatically deployed by Terraform.
