#!/usr/bin/env bash
# ci_run.sh — unattended integration test entrypoint for local KVM environment.
#
# Usage:
#   bash tests/integration/ci_run.sh [--skip-teardown]
#
# Assumptions:
#   - KVM VMs are reachable at the IPs in tests/integration/inventory/hosts.ini
#   - SSH key auth is configured for ansible_user on all VMs
#   - /dev/vdb is present on all server VMs for Lustre formatting
#
# --skip-teardown  Skip L2 teardown (block device wipe). Useful when iterating
#                  on a specific phase without resetting the full cluster state.

set -euo pipefail

SKIP_TEARDOWN=false
for arg in "$@"; do
  case $arg in
    --skip-teardown) SKIP_TEARDOWN=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV_DIR="$REPO_ROOT/.venv-ci"
INVENTORY="$REPO_ROOT/tests/integration/inventory/hosts.ini"

echo "=== Integration run started: $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "    repo:     $REPO_ROOT"
echo "    venv:     $VENV_DIR"
echo "    teardown: $( [[ $SKIP_TEARDOWN == true ]] && echo skipped || echo L2 )"
echo ""

# Fresh Python venv
echo "--- Creating fresh venv ---"
python3 -m venv --clear "$VENV_DIR"
"$VENV_DIR/bin/pip" install --quiet -r "$REPO_ROOT/requirements.txt"

# Ansible collections (installed to user default path; independent of venv)
echo "--- Installing Ansible collections ---"
"$VENV_DIR/bin/ansible-galaxy" collection install community.general ansible.posix

# Teardown
if [[ $SKIP_TEARDOWN == false ]]; then
  echo "--- Running L2 teardown ---"
  "$VENV_DIR/bin/ansible-playbook" \
    -i "$INVENTORY" \
    "$REPO_ROOT/teardown/teardown_l2.yaml"
fi

# Full provision
echo "--- Running full provision ---"
"$VENV_DIR/bin/ansible-playbook" \
  -i "$INVENTORY" \
  "$REPO_ROOT/ansible/lustre_ansible_setup.yaml"

echo ""
echo "=== Integration run complete: $(date '+%Y-%m-%d %H:%M:%S') ==="
