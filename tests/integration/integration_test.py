#!/usr/bin/env python3
"""
integration_test.py — Unattended integration test for lustre-local-sandbox.

Wraps the runbook phases (Terraform → gen_inventory.py → Ansible) into a
single run. Pass/fail is derived from subprocess exit codes — any failure
stops the run immediately and reports the failing phase.

Assumes VMs provisioned with default terraform/variables.tf values.
Destroys any existing cluster before provisioning.

Usage:
    python3 tests/integration/integration_test.py [options]

Options:
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
    print(f"\n{'=' * 60}")
    print(f"=== {name}")
    print(f"{'=' * 60}\n")


def run(cmd, cwd=None):
    """Run a command, streaming output to the terminal. Exit on failure."""
    result = subprocess.run([str(c) for c in cmd], cwd=cwd)
    if result.returncode != 0:
        print(
            f"\n[FAIL] Command exited {result.returncode}: {' '.join(str(c) for c in cmd)}"
        )
        sys.exit(result.returncode)


def check_venv():
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
    run([VENV_BIN / "ansible-playbook", "-i", "hosts.ini", playbook], cwd=ANSIBLE_DIR)


def provision():
    phase("Phase 1: Provision infrastructure (Terraform)")
    run(["terraform", "init"], cwd=TERRAFORM_DIR)
    run(["terraform", "apply", "-auto-approve"], cwd=TERRAFORM_DIR)
    run([SCRIPTS_DIR / "preflight_check.sh", "post"])

    phase("Phase 1.5: Generate inventory")
    run([VENV_BIN / "python3", SCRIPTS_DIR / "gen_inventory.py"])

    phase("Phase 2: Configure cluster (Ansible)")
    ansible_playbook("lustre_ansible_setup.yaml")


def main():
    parser = argparse.ArgumentParser(
        description="Integration test for lustre-local-sandbox.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
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
