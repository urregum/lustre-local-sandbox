# Deployment Runbook

End-to-end walkthrough for bringing up the Lustre dev cluster from scratch.
Complete each phase in order. See [teardown/README.md](../teardown/README.md)
for teardown options at any point.

---

## Phase 0 — Prerequisites

Ensure all items in the main [README](../README.md) prerequisites and setup
sections are complete before proceeding:

- libvirt / KVM running on the host
- Terraform >= 1.6 installed
- Python venv activated with `requirements.txt` installed
- `ansible-galaxy collection install community.general ansible.posix` completed
- `ansible/group_vars/all.yml` `ansible_user` set to your VM username
- `ansible/hosts.ini` is generated automatically after Phase 1 — do not create or edit it by hand
- SSH key present at `~/.ssh/id_ed25519.pub` (Terraform injects this into VMs via cloud-init)

If you do not have an ed25519 key:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

If you prefer a different key type or path, override `ssh_public_key_path` in
`terraform.tfvars` before Phase 1.

If the default management network (`10.0.100.0/24`) conflicts with your host:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars: override mgmt_network_cidr, mgmt_gateway, and mgmt_ips
```

---

## Phase 1 — Provision Infrastructure (Terraform)

Initialize and apply the Terraform configuration. This will:

- Create the `lustre-demo` libvirt storage pool at `/var/lib/libvirt/lustre-demo/`
- Download the Rocky Linux 9.4 cloud image (first run only)
- Create the `lustre-mgmt` (NAT) and `lustre-lnet0` networks
- Provision 8 VMs (1 client, 1 MGS, 2 MDS, 4 OSS) with cloud-init configuration

```bash
cd terraform/
terraform init
terraform apply
```

After `apply` completes, generate the Ansible inventory from Terraform output:

```bash
cd ..
python3 scripts/gen_inventory.py
```

This writes `ansible/hosts.ini` from the `management_ips` Terraform output.
The file is gitignored and owned by the script — do not edit it by hand.

---

## Phase 2 — Configure Cluster (Ansible)

Run the main playbook from the `ansible/` directory. This handles:

- Whamcloud RPM installation (Lustre kernel on servers, client + DKMS on client)
- LNet network interface configuration
- Lustre filesystem formatting and mounting (MGS → MDS → OSS, in order)
- MPI and IOR installation on the client

```bash
cd ansible/
ansible-playbook -i hosts.ini lustre_ansible_setup.yaml
```

---

## Phase 3 — Validate

Verify cluster health from any server node:

```bash
# All devices should show 'UP'
lctl dl

# Should return 'healthy'
lctl get_param -n health_check

# From client: verify filesystem is mounted and accessible
df -h /mnt/lustre
lfs df
```

Run a basic IOR benchmark from the client:

```bash
# Write then read using direct I/O (bypasses kernel page cache for accurate results).
# Adjust -np to match available client vCPUs (see mpi_slots_per_client in group_vars/all.yml).
mpirun -np 2 ior -w -r -b 1g -t 1m -F -O useO_DIRECT=1 -o /mnt/lustre/ansible/ior_test
```

> **Note:** Without `-O useO_DIRECT=1`, a combined write+read (`-w -r`) will serve
> reads from the Lustre client extent cache rather than disk, producing inflated read
> numbers (~1.5 GB/s vs actual OSS throughput). For a true cold read, run write and
> read as separate passes or unmount and remount the client between them.

---

## Phase 4 — Teardown

See [teardown/README.md](../teardown/README.md) for L1 (graceful unmount),
L2 (reset block devices), and L3 (full infrastructure destroy) options.
