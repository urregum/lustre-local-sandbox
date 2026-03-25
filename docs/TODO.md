# Known Issues and Deferred Work

Items tracked here are deliberate deferrals, not oversights. Each entry notes
what the issue is, why it was deferred, and what the intended fix is.

---

## Ansible Plays

### Canary file idempotency pattern
**Files:** `ansible/server_stg_setup.yaml`
**Issue:** `mkfs.lustre` idempotency is currently gated on the existence of
`/etc/lustre_vdb_formatted` rather than actual device state.
**Intended fix:** Replace with `blkid /dev/vdb` detection — skip `mkfs.lustre`
if a Lustre superblock is already present. This survives VM reboots cleanly and
is reset naturally by L2 teardown (`wipefs -a`). Also remove `--reformat` from
OSS plays; the detection gate makes it redundant.
**Deferred until:** Ansible refactor pass (post initial environment stabilization).

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

### VM cloud-init and post-provision Ansible integration
**Issue:** Terraform skeleton exists but VM resources are not yet defined.
**Intended fix:** Implement `libvirt_cloudinit_disk`, `libvirt_domain` resources
per role, and wire Terraform outputs to feed `ansible_host` into inventory.

### Inventory management
**Issue:** `ansible/hosts.ini` is manually updated with Terraform output IPs.
**Intended fix:** Consider a Python glue script or Terraform local-exec to
auto-populate management IPs into a generated inventory file.
