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

### yamllint line-length exceptions
**Status:** Deferred to 1.0 — exceptions were added as a quick fix during
development. Using `# yamllint disable-line rule:line-length` is an anti-pattern
that suppresses the signal rather than fixing it.
**Intended fix:** Restructure the offending lines properly — use YAML block
scalars (`>-`) for long URLs in `lustre_rpm_setup.yaml`, split long inline
dicts in `lnet_setup.yaml` into multi-line form, and wrap long strings in
`client_setup.yaml`. Remove all `yamllint disable-line` comments once done.

### ~~GitHub Actions — lint workflow~~ — resolved in 0.5.0

### Integration testing
**Status:** Scaffolded but stale — requires several fixes before first run:
- `tests/integration/inventory/hosts.ini` still has `ip_lnet1`/`mgs_lnet1_ip`
  from before the single-rail simplification; subnet masks are `/16` (should
  be `/24`); `ansible_user=curleym` is hardcoded; `mgs_lnet0_ip` is quoted
  (will be treated as a string, not a value).
- `ci_run.sh` references `teardown/teardown_l2.yaml` — path is wrong, playbook
  lives at `ansible/teardown_l2.yaml`.
- Management `ansible_host` IPs (`192.168.122.x`) are static guesses against
  the libvirt default bridge; this environment uses `10.0.100.x` from Terraform.
  Investigate whether the static inventory can be replaced or seeded from
  `gen_inventory.py` output, or document the manual IP verification step more
  clearly.

**Intended fix:** Audit and update the static inventory and `ci_run.sh` path.
Consider whether the static inventory approach is viable long-term or whether
integration tests should run `gen_inventory.py` as part of setup.

---

## Repository workflow

### Branching and PR workflow
**Status:** Deferred to 1.0.
**Intended fix:** Enable main branch protection and require PRs for all merges
at 1.0. Direct push to main is acceptable for now.

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

### Cross-platform host validation — required before 1.0
**Status:** Deferred to pre-1.0 — currently only validated on Linux Mint 22
(noted in README.md). KVM/libvirt behavior, Python toolchain availability,
Terraform provider compatibility, and nmcli behavior may differ across host
distros and versions.
**Intended fix:** Validate a full L3 rebuild on at least one additional host
OS (e.g., Ubuntu 24.04 LTS or Fedora current) before cutting 1.0. Document
any host-side prerequisites or workarounds surfaced during the process.
Areas most likely to be fragile: libvirt/QEMU version differences affecting
Terraform provider behavior, Python version availability for the venv, and
package names in host prerequisites.

### L1 and L2 teardown — L1 validated, L2 pending
**Status:** L1 validated — teardown, remount, cluster_health, and IOR all
passed. Required fixes: `lnetctl lnet unconfigure` + `lustre_rmmod` to replace
manual modprobe (sub-modules mgs/obdclass/ptlrpc/mgc held lnet references).
Idempotency confirmed on re-run.
L2 (block device wipe followed by `server_stg_setup.yaml` reformat) not yet
tested as a standalone procedure.
**Intended fix:** Run a dedicated L2 cycle: teardown_l2.yaml followed by
`server_stg_setup.yaml` to confirm reformat and remount, then cluster_health.
