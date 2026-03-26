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

### ansible-lint pre-commit hook
**Issue:** ansible-lint not yet in `.pre-commit-config.yaml`.
**Intended fix:** Add after Ansible plays are refactored to a clean lint baseline.

### GitHub Actions
**Issue:** No CI pipeline exists yet.
**Intended fix:** Add after pre-commit configuration is stable. Will require a
self-hosted runner for integration tests against the live cluster.

---

## Terraform

### ~~VM cloud-init and post-provision Ansible integration~~ — resolved in 8673d8a

### ~~Inventory management~~ — resolved in scripts/gen_inventory.py
