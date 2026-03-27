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
**Status:** Unblocked — Ansible refactor complete, clean lint baseline established.
**Intended fix:** Add `ansible-lint` stanza to `.pre-commit-config.yaml` and
remove the deferred comment.

### yamllint line-length exceptions
**Status:** Deferred to 1.0 — exceptions were added as a quick fix during
development. Using `# yamllint disable-line rule:line-length` is an anti-pattern
that suppresses the signal rather than fixing it.
**Intended fix:** Restructure the offending lines properly — use YAML block
scalars (`>-`) for long URLs in `lustre_rpm_setup.yaml`, split long inline
dicts in `lnet_setup.yaml` into multi-line form, and wrap long strings in
`client_setup.yaml`. Remove all `yamllint disable-line` comments once done.

### GitHub Actions — lint workflow
**Status:** Unblocked — no runner or cluster required.
**Intended fix:** Add `.github/workflows/lint.yml` triggered on push to main.
Runs ansible-lint, yamllint, and `black --check` on GitHub-hosted runners.

### Integration testing
**Status:** Scaffolded — `tests/integration/ci_run.sh` + static KVM inventory.
Runs L2 teardown → full provision unattended against local KVM VMs.
`make integration` / `make integration-noclean` (skip teardown).
Verify `ansible_host` IPs in `tests/integration/inventory/hosts.ini` match
actual libvirt DHCP leases before first run (`virsh net-dhcp-leases default`).

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

### /etc/hosts population on KVM host
**Status:** Deferred — manual workaround in place.
**Intended fix:** Add a post-`terraform apply` step (script or Ansible local task)
that writes cluster hostnames and management IPs to `/etc/hosts` on the KVM host,
making `ssh ansible@mgs` etc. work without looking up IPs.

### Client pool scaling documentation
**Status:** Deferred — current topology is fixed at one client.
**Intended fix:** Document in runbook how to add client VMs: bump `client.count`
(or add `client2`/`client3` entries to `mgmt_ips`), re-run `terraform apply`, and
re-run `gen_inventory.py` + the client Ansible plays against the new hosts.
