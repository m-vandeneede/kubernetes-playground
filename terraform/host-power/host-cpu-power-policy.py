#!/usr/bin/python3
"""Apply the approved balanced CPU policy without changing boost or limits."""

from pathlib import Path
import sys
import time


GOVERNOR = "powersave"
PREFERENCE = "balance_performance"
SUPPORTED_DRIVERS = {"amd-pstate-epp", "intel_pstate"}


def read(policy, name):
    return (policy / name).read_text().strip()


def apply_policy(policies):
    if not policies:
        raise RuntimeError("No CPU frequency policies found")

    # Validate all policies before modifying any of them.
    before = {}
    for policy in policies:
        if read(policy, "scaling_driver") not in SUPPORTED_DRIVERS:
            raise RuntimeError(f"Unsupported CPU driver: {policy}")
        if GOVERNOR not in read(policy, "scaling_available_governors").split():
            raise RuntimeError(f"Governor unavailable: {policy}")
        if PREFERENCE not in read(policy, "energy_performance_available_preferences").split():
            # AMD can expose only 'performance' while that governor is selected.
            if read(policy, "scaling_governor") != "performance":
                raise RuntimeError(f"Energy preference unavailable: {policy}")
        before[policy] = {
            name: read(policy, name)
            for name in (
                "scaling_governor",
                "energy_performance_preference",
                "scaling_min_freq",
                "scaling_max_freq",
            )
        }

    changed = []
    try:
        for policy in policies:
            changed.append(policy)
            (policy / "scaling_governor").write_text(GOVERNOR + "\n")
            if PREFERENCE not in read(policy, "energy_performance_available_preferences").split():
                raise RuntimeError(f"Energy preference unavailable after governor change: {policy}")
            (policy / "energy_performance_preference").write_text(PREFERENCE + "\n")

        for policy in policies:
            if read(policy, "scaling_governor") != GOVERNOR:
                raise RuntimeError(f"Governor verification failed: {policy}")
            if read(policy, "energy_performance_preference") != PREFERENCE:
                raise RuntimeError(f"Energy preference verification failed: {policy}")
            for name in ("scaling_min_freq", "scaling_max_freq"):
                if read(policy, name) != before[policy][name]:
                    raise RuntimeError(f"Unexpected frequency-limit change: {policy}")
    except Exception:
        for policy in reversed(changed):
            try:
                (policy / "scaling_governor").write_text("powersave\n")
                (policy / "energy_performance_preference").write_text(
                    before[policy]["energy_performance_preference"] + "\n"
                )
                (policy / "scaling_governor").write_text(
                    before[policy]["scaling_governor"] + "\n"
                )
            except OSError as error:
                print(f"Rollback failed for {policy}: {error}", file=sys.stderr)
        raise

    print(f"Applied {GOVERNOR} + {PREFERENCE} to {len(policies)} CPU policies")
    print("Boost, frequency limits, KSM, and VM settings were not changed")


def main():
    root = Path("/sys/devices/system/cpu/cpufreq")
    # Allow the CPU driver a short initialization window during boot.
    for attempt in range(61):
        policies = sorted(root.glob("policy*"))
        if policies:
            apply_policy(policies)
            return
        if attempt < 60:
            time.sleep(0.25)
    raise RuntimeError("CPU frequency policies unavailable after 15 seconds")


if __name__ == "__main__":
    main()
