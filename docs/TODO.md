# Known Issues and Deferred Work

Items tracked here are deliberate deferrals, not oversights. Each entry notes
what the issue is, why it was deferred, and what the intended fix is.

---

## Ansible Plays

### ~~Canary file idempotency pattern~~ — resolved in ac8a7ba

### Bare `shell:` tasks
**Files:** `ansible/lnet_setup.yaml`
**Issue:** Several tasks use bare `shell:` rather than `ansible.builtin.command`
or dedicated modules. These will trigger `ansible-lint` warnings.
**Intended fix:** Audit and replace with appropriate modules or `command:` where
`shell:` features (pipes, redirection) are not actually needed.
**Deferred until:** ansible-lint is added to pre-commit (post refactor).

### `changed_when` / `failed_when` coverage
**Files:** `ansible/server_stg_setup.yaml`
**Issue:** Some tasks lack explicit `changed_when: false` for read-only commands,
causing spurious change reporting.
**Deferred until:** Ansible refactor pass.

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
