#!/usr/bin/env bash
# preflight_check.sh — validates KVM host readiness before and after terraform apply.
#
# Run before terraform apply to confirm the host can satisfy cluster reservations.
# Run after terraform apply to confirm all VMs and disks provisioned correctly.
#
# Usage:
#   ./scripts/preflight_check.sh pre [pool-parent-path]
#   ./scripts/preflight_check.sh post

set -uo pipefail

PASS="[PASS]"
FAIL="[FAIL]"

errors=0

pass() { echo "$PASS $1"; }
fail() { echo "$FAIL $1"; errors=$((errors + 1)); }

# ── Pre-apply checks ──────────────────────────────────────────────────────────
# Validates host-side prerequisites before provisioning VMs.
#
# Memory reservation (from terraform/variables.tf defaults):
#   MGS:      1 ×  2 GiB =  2 GiB
#   MDS:      2 ×  4 GiB =  8 GiB
#   OSS:      4 ×  2 GiB =  8 GiB
#   Client:   1 ×  4 GiB =  4 GiB
#   Total:                  22 GiB (22528 MiB)
#
# Disk reservation (pool parent dir):
#   Boot disks: 8 VMs × 20 GiB = 160 GiB
#   Data disks: 7 servers × 5 GiB = 35 GiB
#   Total:                         ~195 GiB (210 GiB checked, with headroom)

check_pre() {
    local pool_parent="${1:-/var/lib/libvirt}"
    echo "=== Pre-apply checks (pool parent: $pool_parent) ==="

    # libvirt daemon reachable
    if virsh uri &>/dev/null; then
        pass "libvirt daemon reachable"
    else
        fail "libvirt daemon not reachable — is libvirtd running and user in libvirt group?"
    fi

    # Host free memory vs cluster reservation
    local required_mib=22528
    local avail_mib
    avail_mib=$(awk '/MemAvailable/ { print int($2 / 1024) }' /proc/meminfo)
    if [ "$avail_mib" -ge "$required_mib" ]; then
        pass "Available memory: ${avail_mib} MiB (need ${required_mib} MiB)"
    else
        fail "Insufficient memory: ${avail_mib} MiB available, ${required_mib} MiB required"
    fi

    # Disk space in pool parent directory
    local required_gb=210
    local avail_gb
    avail_gb=$(df --output=avail -BG "$pool_parent" 2>/dev/null | tail -1 | tr -d 'G ')
    if [ "$avail_gb" -ge "$required_gb" ]; then
        pass "Disk space on ${pool_parent}: ${avail_gb} GiB available (need ${required_gb} GiB)"
    else
        fail "Insufficient disk: ${avail_gb} GiB on ${pool_parent}, need ${required_gb} GiB"
    fi

    # SSH public key exists
    local key_path="${HOME}/.ssh/id_ed25519.pub"
    if [ -f "$key_path" ]; then
        pass "SSH public key found: $key_path"
    else
        fail "SSH public key not found at $key_path (required for cloud-init VM provisioning)"
    fi
}

# ── Post-apply checks ─────────────────────────────────────────────────────────
# Validates terraform provisioned the expected VMs and disks before running Ansible.

check_post() {
    echo "=== Post-apply checks ==="

    local all_vms=(mgs mds1 mds2 oss1 oss2 oss3 oss4 client1)
    local server_vms=(mgs mds1 mds2 oss1 oss2 oss3 oss4)

    # All VMs in running state
    for vm in "${all_vms[@]}"; do
        local state
        state=$(virsh domstate "$vm" 2>/dev/null || echo "not found")
        if [ "$state" = "running" ]; then
            pass "VM ${vm}: running"
        else
            fail "VM ${vm}: ${state}"
        fi
    done

    # Data disk (vdb) attached to each server VM
    for vm in "${server_vms[@]}"; do
        if virsh domblklist "$vm" 2>/dev/null | grep -q "vdb"; then
            pass "VM ${vm}: data disk (vdb) attached"
        else
            fail "VM ${vm}: data disk (vdb) not found in domblklist"
        fi
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────

case "${1:-}" in
    pre)
        check_pre "${2:-/var/lib/libvirt}"
        ;;
    post)
        check_post
        ;;
    *)
        echo "Usage: $0 {pre [pool-parent-path] | post}"
        exit 1
        ;;
esac

echo ""
if [ "$errors" -gt 0 ]; then
    echo "${errors} check(s) failed."
    exit 1
else
    echo "All checks passed."
fi
