#!/usr/bin/env python3
"""
integration_test.py — Unattended integration test for lustre-local-sandbox.

Wraps the runbook phases (Terraform → gen_inventory.py → Ansible) into a
single run. Pass/fail is derived from subprocess exit codes — any failure
stops the run immediately and reports the failing phase.

Assumes VMs provisioned with default terraform/variables.tf values.
Destroys any existing cluster before provisioning. Requires --yes to proceed.

Usage:
    python3 tests/integration/integration_test.py --yes [options]

Options:
    --yes             Required. Confirms that the existing cluster will be
                      destroyed before provisioning. Without this flag the
                      script prints a dry-run summary and exits.
    --clean-slate     Remove the base OS image from the libvirt pool after
                      terraform destroy, forcing a fresh image download.
    --teardown-l1     After provision, run an L1 teardown and remount cycle.
    --teardown-l2     After provision, run an L2 teardown and remount cycle.

Prerequisites:
    - .venv present at repo root with requirements.txt installed
    - ansible-galaxy collections installed (community.general, ansible.posix)
    - KVM/libvirt available and user in the libvirt group
    - terraform in PATH
"""

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
VENV_BIN = REPO_ROOT / ".venv" / "bin"
ANSIBLE_DIR = REPO_ROOT / "ansible"
TERRAFORM_DIR = REPO_ROOT / "terraform"
SCRIPTS_DIR = REPO_ROOT / "scripts"


def phase(name):
    """Print a phase header to stdout."""
    print(f"\n{'=' * 60}")
    print(f"=== {name}")
    print(f"{'=' * 60}\n")


def run(cmd, cwd=None):
    """Run a command, streaming output to the terminal. Exit on failure."""
    try:
        result = subprocess.run([str(c) for c in cmd], cwd=cwd)
    except FileNotFoundError:
        print(f"\n[FAIL] Command not found: {cmd[0]}")
        sys.exit(1)
    if result.returncode != 0:
        print(
            f"\n[FAIL] Command exited {result.returncode}: "
            f"{' '.join(str(c) for c in cmd)}"
        )
        sys.exit(result.returncode)


def check_venv():
    """Exit with a clear message if the repo .venv is not present."""
    if not VENV_BIN.is_dir():
        print(
            "ERROR: .venv not found at repo root.\n"
            "Set up the environment first:\n"
            "  python3 -m venv .venv\n"
            "  .venv/bin/pip install -r requirements.txt\n"
            "  .venv/bin/ansible-galaxy collection install "
            "community.general ansible.posix"
        )
        sys.exit(1)


def ansible_playbook(playbook):
    """Run an Ansible playbook from the ansible/ directory with the generated inventory."""
    run([VENV_BIN / "ansible-playbook", "-i", "hosts.ini", playbook], cwd=ANSIBLE_DIR)


def provision():
    """Run the full provision flow: Terraform → preflight → inventory → Ansible."""
    phase("Phase 1: Provision infrastructure (Terraform)")
    run(["terraform", "init"], cwd=TERRAFORM_DIR)
    run(["terraform", "apply", "-auto-approve"], cwd=TERRAFORM_DIR)
    run([SCRIPTS_DIR / "preflight_check.sh", "post"])

    phase("Phase 1.5: Generate inventory")
    run([VENV_BIN / "python3", SCRIPTS_DIR / "gen_inventory.py"])

    phase("Phase 2: Configure cluster (Ansible)")
    ansible_playbook("lustre_ansible_setup.yaml")


def print_dry_run(args):
    """Print what the script would do without --yes and exit cleanly."""
    teardown_label = "l1" if args.teardown_l1 else "l2" if args.teardown_l2 else "none"
    print("Dry run — pass --yes to execute.\n")
    print(f"  repo:        {REPO_ROOT}")
    print(f"  clean-slate: {args.clean_slate}")
    print(f"  teardown:    {teardown_label}")
    print()
    print("Actions that would run:")
    print("  Phase 0: terraform destroy -auto-approve")
    if args.clean_slate:
        print("           virsh vol-delete rocky-9-base.qcow2 (clean-slate)")
    print("  Phase 1: terraform init + apply")
    print("  Phase 1.5: scripts/gen_inventory.py")
    print("  Phase 2: ansible-playbook lustre_ansible_setup.yaml")
    if args.teardown_l1:
        print("  Phase 3: teardown_l1.yaml + re-provision (L1 cycle)")
    if args.teardown_l2:
        print("  Phase 3: teardown_l2.yaml + re-provision (L2 cycle)")


def main():
    """Parse arguments, guard against accidental destruction, and run the test."""
    parser = argparse.ArgumentParser(
        description="Integration test for lustre-local-sandbox.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Required. Confirms destruction of any existing cluster.",
    )
    teardown_group = parser.add_mutually_exclusive_group()
    teardown_group.add_argument(
        "--teardown-l1",
        action="store_true",
        help="Run L1 teardown and remount cycle after provision.",
    )
    teardown_group.add_argument(
        "--teardown-l2",
        action="store_true",
        help="Run L2 teardown and remount cycle after provision.",
    )
    parser.add_argument(
        "--clean-slate",
        action="store_true",
        help="Remove base OS image from pool after destroy (forces re-download).",
    )
    args = parser.parse_args()

    check_venv()

    if not args.yes:
        print_dry_run(args)
        sys.exit(0)

    start = datetime.now()
    teardown_label = "l1" if args.teardown_l1 else "l2" if args.teardown_l2 else "none"
    print(f"=== Integration test started: {start.strftime('%Y-%m-%d %H:%M:%S')} ===")
    print(f"    repo:        {REPO_ROOT}")
    print(f"    clean-slate: {args.clean_slate}")
    print(f"    teardown:    {teardown_label}")

    phase("Phase 0: Teardown existing cluster")
    run(["terraform", "destroy", "-auto-approve"], cwd=TERRAFORM_DIR)
    if args.clean_slate:
        result = subprocess.run(
            ["virsh", "vol-delete", "--pool", "lustre-demo", "rocky-9-base.qcow2"]
        )
        if result.returncode != 0:
            print("    (base image not found in pool — skipping)")

    provision()

    if args.teardown_l1:
        phase("Phase 3: L1 teardown and remount cycle")
        ansible_playbook("teardown_l1.yaml")
        provision()

    if args.teardown_l2:
        phase("Phase 3: L2 teardown and remount cycle")
        ansible_playbook("teardown_l2.yaml")
        provision()

    elapsed = datetime.now() - start
    print(f"\n=== Integration test PASSED — elapsed: {elapsed} ===")


if __name__ == "__main__":
    main()
