# Integration Tests

The integration test wraps the full runbook flow into a single unattended run.
It is intended for contributors validating changes to Terraform, Ansible, or
provisioning scripts — not for first-time cluster setup.

Complete the [README.md](../../README.md) prerequisites and setup sections
before running. The `.venv` at the repo root must be present and populated.

---

## Usage

```bash
# Dry run — prints what would execute without making any changes
python3 tests/integration/integration_test.py

# Full provision cycle (destroys any existing cluster)
python3 tests/integration/integration_test.py --yes

# Full provision + L1 teardown and remount cycle
python3 tests/integration/integration_test.py --yes --teardown-l1

# Full provision + L2 teardown and remount cycle
python3 tests/integration/integration_test.py --yes --teardown-l2

# Force fresh base image download (slow — use after image corruption or --clean-slate)
python3 tests/integration/integration_test.py --yes --clean-slate
```

`--teardown-l1` and `--teardown-l2` are mutually exclusive.

---

## What it does

| Phase | Action |
|-------|--------|
| 0 | `terraform destroy` any existing cluster |
| 1 | `terraform apply` to provision 8 VMs; `preflight_check.sh post` to validate |
| 1.5 | `scripts/gen_inventory.py` to generate `ansible/hosts.ini` |
| 2 | `ansible-playbook lustre_ansible_setup.yaml` (includes cluster health check) |
| 3 (optional) | teardown cycle followed by full re-provision |

Pass/fail is derived from subprocess exit codes. Any failure stops the run
immediately and reports the failing phase and command.

---

## Recovery after a failed apply

If `terraform apply` fails mid-run, libvirt may have domains registered that
are not tracked in Terraform state. Clean them up before retrying:

```bash
for vm in mgs mds1 mds2 oss1 oss2 oss3 oss4 client1; do
  virsh destroy $vm 2>/dev/null
  virsh undefine $vm 2>/dev/null
done
terraform -chdir=terraform destroy -auto-approve
```
