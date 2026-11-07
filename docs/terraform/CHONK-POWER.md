# CHONK power tuning

## CPU policy experiment — 2026-11-07

Host: CHONK, Proxmox, AMD Ryzen 7 3800X (8 cores / 16 logical CPUs).
Driver: `amd-pstate-epp`, with `/sys/devices/system/cpu/amd_pstate/status=active`.
All changes below were made on the **Proxmox host**, not inside either Talos VM.

### Exact changes

Applied to **every `policy*` directory** under
`/sys/devices/system/cpu/cpufreq/` (16 policies):

| File within each policy | Before | After |
| --- | --- | --- |
| `scaling_governor` | `performance` | `powersave` |
| `energy_performance_preference` | `performance` | `balance_performance` |

The governor was changed first. EPP remained `performance` after that change,
so the separately approved second step changed EPP to `balance_performance`.

Equivalent commands, run as root on CHONK (documentation only; not a boot hook):

```sh
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  printf 'powersave\n' > "$policy/scaling_governor"
done
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  printf 'balance_performance\n' > "$policy/energy_performance_preference"
done
```

At this experiment stage these were **temporary runtime settings**. No systemd service, boot argument,
Terraform provisioner, or persistent host configuration was added. Rebooting
or another policy-management service may change them. This file does not apply
the settings automatically. CPU-policy persistence was separately approved and
installed later; see the final section below.

### Deliberately unchanged

- Boost: `/sys/devices/system/cpu/cpufreq/boost=1`.
- Per-policy frequency limits: `scaling_min_freq=1758198` and
  `scaling_max_freq=4560324` (kHz); no frequency cap added.
- KSM/ksmtuned: still running; `/sys/kernel/mm/ksm/run=1`.
- CPU idle-state settings, BIOS settings, PCIe ASPM, GPU/runtime power settings,
  NVMe settings, VM configuration, and Talos configuration.
- Both VMs remained running; all five Kubernetes nodes remained Ready.

### Backups and rollback

Original per-policy settings were saved on CHONK with a restrictive umask:

- `/root/cpu-governor-before-20261107-222034.json`: original governor, EPP,
  minimum frequency, and maximum frequency for all policies.
- `/root/cpu-epp-before-20261107-222209.json`: EPP and frequency limits immediately
  before the second step (the governor was already `powersave`).

To restore the experiment's original policy, run as root on CHONK:

```sh
for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  printf 'performance\n' > "$policy/energy_performance_preference"
  printf 'performance\n' > "$policy/scaling_governor"
done
```

This rollback matches the verified baseline on all 16 policies. It does not
alter boost or frequency limits. Neither rollback nor persistence has been
applied as part of documenting the experiment.

### Wall-power result

- User-reported **whole-rack** baseline: approximately **210 W**.
- After both CPU changes, user reported a reduction of approximately **8 W**,
  implying roughly **202 W** under the observed conditions.
- This is not a direct CHONK power measurement or a controlled benchmark. Other
  rack workloads and meter averaging can affect the reading; the saving cannot
  be attributed separately to governor versus EPP from these observations.

## Original read-only audit

- CPU idle driver/governor: `acpi_idle` / `menu`. A five-second sample showed
  approximately 93.5% aggregate per-logical-CPU ACPI C2 residency. This is not a
  measurement of whole-package sleep residency.
- A 15-second sample showed KSM using approximately 14.6% of **one logical CPU**,
  while roughly 110 MiB was shared. KSM's `general_profit` estimate was negative.
- Approximately 9 GiB RAM was available, swap was unused, and sampled memory
  pressure was zero. Host RAM comprises four DIMMs totaling 56 GiB.
- Inspected PCIe links advertised ASPM support, but ASPM was disabled. No ASPM
  changes or forced enablement were attempted.
- RTX 3060's link was downshifted to 2.5 GT/s. The guest reported runtime D3
  disabled and video memory active. Current GPU watts were not measured; the
  earlier approximately 9 W NVIDIA reading predates this audit.
- One WD Blue SN570 NVMe; sampled disk busy time was approximately 0.43%.
- Kubernetes Metrics API was unavailable. No metrics server or diagnostic
  packages were installed to work around this.

## Follow-up read-only audit — after CPU tuning

A fresh 20-second sample confirmed all 16 policies still use `powersave` with
`balance_performance`. Boost is still enabled, frequency limits are unchanged,
and KSM remains enabled. No additional tuning was applied during this audit.

| Observation | Follow-up sample |
| --- | --- |
| Total host CPU busy | 2.57% across all logical CPUs |
| Worker VM process CPU | 18.54% of one logical CPU |
| Control-plane VM process CPU | 13.44% of one logical CPU |
| KSM scanner CPU | 11.94% of one logical CPU |
| Aggregate ACPI C2 residency | 94.72% per logical CPU |
| Reported frequency range at sampling | approximately 1.76–4.05 GHz |
| CPU Tctl / CCD temperature | 33.8 / 37.0 degrees C |
| NVMe temperature / disk busy | 38.9 degrees C / 0.48% |
| Available RAM | approximately 9.0 GiB |
| Swap usage / sampled memory pressure | zero / zero |

KSM still shares only approximately 109 MiB (`pages_sharing=27836` at 4 KiB per
page), scans 1250 pages per batch with a 29 ms sleep, and reports
`general_profit=-601089984` bytes. Pausing its scanning, while retaining existing
merged pages, was the next candidate experiment at this point; see the separately
approved experiment below for the subsequent change.
The global ASPM policy remains `default`.

All five Kubernetes nodes were Ready. At this follow-up, 16 Longhorn volumes
were attached and healthy and two were detached with unknown robustness; the
audit did not attach volumes or start applications.

These short samples differ in length and workload timing. Clock, temperature,
CPU-utilization, and idle-residency differences are observations, not controlled
proof of savings caused by the policy changes. No new wall-power reading beyond
the user's approximately 8 W improvement was taken by the agent.

## Temporary KSM pause — 2026-11-07

Separately approved after the CPU experiment. Applied on CHONK as root:

```sh
systemctl stop ksmtuned.service
printf '0\n' > /sys/kernel/mm/ksm/run
```

Exact changes:

| Setting | Before | After |
| --- | --- | --- |
| `ksmtuned.service` runtime state | `active` | `inactive` |
| `/sys/kernel/mm/ksm/run` | `1` (scan) | `0` (stop scanning) |

Stopping ksmtuned prevents its periodic adjustment from restarting KSM. Its unit
has no custom `ExecStop` action that unmerges pages. **`run=2` was not used**:
existing shared pages were retained, and no VM was stopped or restarted.

This is a runtime experiment only. `ksmtuned.service` remains **enabled at boot**;
no service mask, disable operation, or persistent configuration was added.
Its prior state and KSM settings are saved on CHONK at:
`/root/ksm-before-pause-20261107-223235.json`.

Verification immediately after the change:

- `ksmtuned` inactive; KSM `run=0`.
- `ksmd` consumed **zero CPU ticks over a 10-second sample**.
- Shared-page counters stayed unchanged across the operation:
  `pages_shared=12608`, `pages_sharing=27502`.
- Approximately 9.0 GiB RAM available; no swap usage.
- CPU policies remained `powersave` + `balance_performance`.

To resume the previous runtime policy as root on CHONK:

```sh
printf '1\n' > /sys/kernel/mm/ksm/run
systemctl start ksmtuned.service
```

The tuner then resumes its normal threshold-based adjustments. Its boot-enabled
state does not need changing. Existing sharing can decrease over time while
scanning is paused, so monitor available RAM and swap before making this
permanent. Additional wall-power savings from this experiment are not yet known;
compare against the approximately 202 W rack reading after CPU tuning, not the
original 210 W baseline.

## KSM disabled at boot — 2026-11-07

The user reported little observable wall-power reduction from pausing KSM but
chose to keep it off, then separately approved disabling it at boot. Applied on
CHONK:

```sh
systemctl disable --now ksmtuned.service
```

This supersedes the earlier experiment's boot-enabled state. Verified:
`ksmtuned.service` is **disabled** and **inactive**, and
`/sys/kernel/mm/ksm/run=0`. With the installed configuration, ksmtuned was the
only KSM systemd unit; disabling it prevents the tuner from starting scanning at
boot. It is not masked, so an explicit manual start can still re-enable it.
No reboot was performed to test boot behavior.

Prior state saved on CHONK:
`/root/ksm-before-disable-boot-20261107-223721.json`.
Existing shared pages were not unmerged. CPU governor/EPP persistence remains
unchanged at that time; CPU policy was subsequently persisted as recorded below.

To restore boot enablement and resume scanning:

```sh
systemctl enable --now ksmtuned.service
printf '1\n' > /sys/kernel/mm/ksm/run
```

The tuner will subsequently apply its normal memory-threshold policy. Monitor
available RAM and swap while KSM remains disabled; no specific watt saving has
been established for this change.

## GPU telemetry audit — 2026-11-07

A temporary pod on kube103, using the existing NVIDIA runtime, queried
`nvidia-smi` four times at five-second intervals. It ran no encoding/compute
workload and made no GPU configuration changes. The pod, namespace, and
temporary RuntimeClass were removed afterward.

| Metric | Observed |
| --- | --- |
| GPU / driver | RTX 3060 / 595.91.07 |
| Reported GPU power | 9.12, 8.94, 8.98, 8.99 W (approximately 9.01 W average) |
| Performance state | P8 throughout |
| GPU / memory utilization | 0% / 0% |
| Allocated GPU memory | 1 MiB |
| Graphics / memory clocks | 210 / 405 MHz |
| GPU temperature | 32 degrees C |
| Current / maximum PCIe generation | Gen 1 / Gen 4 |
| Display attached / active | no / disabled |
| Compute-client query | no entries |
| Persistence mode | enabled |
| Power limit | 170 W; unchanged |

Evidence: `~/.talos/backups/gpu-power-audit-20261107223740/nvidia-smi.log`.
These are NVIDIA-reported device watts while querying telemetry, not a direct
wall-power measurement. The GPU is already in a low-power idle state. Lowering
its 170 W power limit would primarily affect loaded operation, not necessarily
this approximately 9 W idle draw. No persistence-mode, runtime-D3, clock, or
power-limit tuning was applied. Runtime-D3 support and PCIe ASPM compatibility
would require separate investigation before any changes to this passthrough
configuration.

## CPU policy persisted — 2026-11-07

Following separate approval, installed the shared files from
[`host-power/`](host-power/README.md) on CHONK:

- `/usr/local/sbin/host-cpu-power-policy.py` (root, 0755).
- `/etc/systemd/system/host-cpu-power-policy.service` (root, 0644).

Ran `systemctl daemon-reload` and
`systemctl enable --now host-cpu-power-policy.service`. Verified `enabled`,
`active (exited)`, and `ExecMainStatus=0`. All 16 policies are `powersave` with
`balance_performance`; frequency limits were verified unchanged. The script
does not alter boost. The oneshot applies at boot before `pve-guests.service`;
it does not continuously enforce the policy or handle subsequent CPU hotplug.

KSM remains separately disabled at boot (`ksmtuned` disabled/inactive, `run=0`).
Pre-install state: `/root/cpu-policy-persistence-before-20261107-224807.json`
on CHONK. No host reboot or guest restart was performed; next-boot execution has
not yet been observed.

Rollback now requires disabling `host-cpu-power-policy.service` before restoring
the original runtime policy; see the shared README. Simply writing `performance`
to sysfs no longer prevents the balanced policy from being reapplied next boot.

## GPU-link ASPM experiment — 2026-11-07 (not enabled)

Reviewed AutoASPM at commit `11e921446423582836fb5b290e053fc7c6643efe`:
<https://git.notthebe.ee/notthebee/AutoASPM>. The script scans all supported
devices and directly writes PCI configuration registers. It was **not run** on
CHONK. Its device-by-device selection is not a substitute for checking the
common capabilities of both ends of a link.

Both GPU `0000:0a:00.0` and upstream port `0000:00:03.1` advertise plain L1;
the root port does not advertise L0s. A separately approved runtime test wrote
`1` to `/sys/bus/pci/devices/0000:0a:00.0/link/l1_aspm`. The control still read
`0`, so the test did not enable L1. The error handler wrote `0` back. No raw PCI
register writes, global policy change, L1 substate tuning, or persistent ASPM
service were used.

Verified PCIe Link Control words before and after the attempted test:

| Device | Before | After cleanup |
| --- | --- | --- |
| Upstream port `0000:00:03.1` | `0c40` | `0c40` |
| GPU `0000:0a:00.0` | `0140` | `0140` |
| GPU audio `0000:0a:00.1` | `0140` | `0140` |

Global ASPM policy remains `default`; both GPU-function `l1_aspm` controls read
`0`. Linux's ASPM implementation clears a per-link disable mask when `1` is
written, but then reapplies the selected global policy; `default` selects the
firmware-initialized link state. Thus the per-link interface is not an
independent force-enable override of a firmware-disabled default. This was
checked against upstream `drivers/pci/pcie/aspm.c` (`policy_to_aspm_state` and
`aspm_attr_store_common`), not a claim of exact source equivalence to the custom
Proxmox kernel.

Pre-test link/register inventory on CHONK:
`/root/gpu-aspm-before-20261107-225357.json`.
No recent PCIe error messages were found after the test. Both CHONK VMs remained
running, and all five Kubernetes nodes remained Ready. No power saving from ASPM
was measured or established. Firmware changes, direct-register tests, or global
policy changes require separate approval and risk review.
