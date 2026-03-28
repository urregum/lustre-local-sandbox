# Known Issues and Deferred Work

Items tracked here are deliberate deferrals, not oversights. Each entry notes
what the issue is, why it was deferred, and what the intended fix is.

---

## Ansible Plays

### ~~Canary file idempotency pattern~~ — resolved in ac8a7ba

### ~~Bare `shell:` tasks~~ — resolved in ansible refactor pass
Note: two `ansible.builtin.shell:` tasks remain in `lnet_setup.yaml` — both
use pipes and legitimately require shell.

### ~~`changed_when` / `failed_when` coverage~~ — resolved in ansible refactor pass
Note: `lustre_rpm_setup.yaml:67` entry was stale — that task is a conditional
write under a `when:` guard and correctly reports changed when it runs.

### ~~Incorrect `ansible.builtin.mount` FQCN~~ — resolved in ansible refactor pass

### ~~`ansible.posix` collection missing from install instructions~~ — resolved in README.md and docs/runbook.md

---

## CI / Toolchain

### ansible.posix collection deprecation warnings
**Status:** Deferred — warnings come from inside the `ansible.posix.mount`
module, not from our playbooks. The module imports `to_bytes`/`to_native` from
`ansible.module_utils._text` and passes `warnings` to `exit_json`, both
deprecated in ansible-core 2.23/2.24.
**Intended fix:** Upgrade the `ansible.posix` collection when a version that
uses `ansible.module_utils.common.text.converters` is available. No change to
our playbooks required.

### ~~ansible-lint pre-commit hook~~ — resolved, runs as local hook using venv install

### ~~yamllint line-length exceptions~~ — resolved in 5f9ff4a
All `# yamllint disable-line rule:line-length` comments replaced with `>-`
block scalars in `lustre_rpm_setup.yaml`. No remaining suppressions.

### ~~GitHub Actions — lint workflow~~ — resolved in 0.5.0

### ~~Integration testing~~ — validated on Ubuntu 24.04
`integration_test.py` end-to-end: `--teardown-l2` cycle (full provision →
teardown → reformat → remount → cluster_health) passed on Ubuntu 24.04 LTS.
`--teardown-l1` cycle also validated on Linux Mint 22.

---

## Repository workflow

### ~~Branching and PR workflow~~ — resolved at 1.0
Branch protection enabled on `main`; PRs required for all merges going forward.
Direct-push access removed.

---

## Terraform

### ~~VM cloud-init and post-provision Ansible integration~~ — resolved in 8673d8a

### ~~Inventory management~~ — resolved in scripts/gen_inventory.py

### ~~Provision gate~~ — resolved
Single-rail LNET (lnet1 removed) eliminated the post-boot instability root
cause. `lustre_ansible_setup.yaml` runs end-to-end with `lctl ping` retry
gates in both `lnet_setup.yaml` (all nodes ping MGS) and `client_setup.yaml`
(pre-mount MGS reachability check). No further gate work needed for
single-rail topology.

### /etc/hosts population on KVM host
**Status:** Deferred — manual workaround in place.
**Intended fix:** Add a post-`terraform apply` step (script or Ansible local task)
that writes cluster hostnames and management IPs to `/etc/hosts` on the KVM host,
making `ssh ansible@mgs` etc. work without looking up IPs.

### ~~IOR benchmark — drop_caches and direct I/O notes~~ — resolved, see runbook Phase 3

### ~~Client pool scaling documentation~~ — resolved, see runbook "Scaling the Client Pool"

### ~~Terraform libvirt provider version~~ — resolved, upgraded to ~> 0.8.0 (v0.8.3)

### ~~Runbook health checks — consider moving to playbook~~ — resolved in cluster_health.yaml
Note: server checks, client mount, OST count, and write/read smoke test are
all automated. IOR and mdtest intentionally left user-driven.

### ~~Post-terraform VM readiness validation~~ — resolved in scripts/preflight_check.sh
Note: `preflight_check.sh pre` also validates host-side prerequisites (libvirt
reachability, available memory vs cluster reservation, disk space, SSH key).
LNET interface validation deferred — covered at runtime by lnet_setup.yaml's
lctl ping retry gate.

### ~~Cross-platform host validation~~ — validated on Ubuntu 24.04
Full L3 rebuild validated on Ubuntu 24.04 LTS. Prerequisites surfaced and
documented in README.md: `python3-venv`, `genisoimage`, libvirt group
membership, and AppArmor override for the custom pool path. RHEL/Fedora
remains untested and unsupported.

### ~~L1 and L2 teardown — needs focused testing~~ — both validated
L1: teardown, remount via lustre_ansible_setup.yaml, cluster_health, and IOR
all passed. Required fixes: `lnetctl lnet unconfigure` (best-effort, EBUSY
tolerated) + `lustre_rmmod` replacing manual modprobe.
L2: teardown_l2.yaml + full lustre_ansible_setup.yaml reformat and remount
passed. PLAY RECAP showed expected changed counts across all 8 nodes.
