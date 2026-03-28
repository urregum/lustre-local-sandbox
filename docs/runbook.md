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
# Confirm host is ready before provisioning
./scripts/preflight_check.sh pre

cd terraform/
terraform init
terraform apply
```

## Phase 1.5 — Glue Script (Python)

After `apply` completes, confirm all VMs and disks are present, then generate
the Ansible inventory:

```bash
# Confirm all 8 VMs are running and data disks attached
./scripts/preflight_check.sh post

python3 scripts/gen_inventory.py
```

This writes `ansible/hosts.ini` from the `management_ips` Terraform output.
The file is gitignored and owned by the script — do not edit it by hand. The
script will also clear up any known_hosts entries from prior clusters.

While the glue script run could be automated, this is a good point to check
terraform resources are as expected before time is spent on playbooks.

---

## Phase 2 — Configure Cluster (Ansible)

Run the main playbook from the `ansible/` directory. This handles:

- Validating the VMs are ready to proceed.
- Whamcloud RPM installation (Lustre kernel on servers, client + DKMS on client)
- LNet network interface configuration
- Lustre filesystem formatting and mounting (MGS → MDS → OSS, in order)
- MPI and IOR installation on the client

```bash
cd ansible/
ansible-playbook -i hosts.ini lustre_ansible_setup.yaml
```

The default for playbooks is to fail on any error.

---

## Phase 3 — Validate

Your host user ssh-key is made available for the 'ansible' user on all VMs.

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

Run basic IOR and mdtest benchmarks from a client. The default Lustre mount has a
/mnt/lustre/ansible subdirectory set up for testing:

```bash
# Write then read using direct I/O (bypasses kernel page cache for accurate results).
# Adjust -np to match available client vCPUs (see mpi_slots_per_client in group_vars/all.yml).
mpirun --hostfile mpi_hostfile -np 2 ior -w -r -a POSIX -b 64m -t 1m -s 4 -F -C -e -O useO_DIRECT=1 -o /mnt/lustre/ansible/ior_test

# Test metadata servers
mpirun --hostfile mpi_hostfile -np 2 mdtest -n 1000 -i 3 -u -d /mnt/lustre/ansible/testdir
```

At this point, the system is ready for sandbox experimentation!

> **Note:** Without `-O useO_DIRECT=1`, writes fill the page cache and the subsequent
> read pass serves from it, producing wildly inflated read numbers (18,000+ MiB/s in
> this environment — far beyond what the virtual OSS disks can deliver). With
> `useO_DIRECT=1`, both passes bypass the cache and reflect actual throughput
> (~130 MiB/s write, ~1,500 MiB/s read in the default topology due to Lustre
> read-ahead across 4 OSTs).

---

## Scaling the Client Pool

The default topology provisions one client. Adding a second client (`client2`)
requires changes to four files:

**1. `terraform/variables.tf`** — extend the `mgmt_ips` object type and default:
```hcl
# In the type block:
client2 = string
# In the default block:
client2 = "10.0.100.21"
```

**2. `terraform/vms.tf`** — copy all three `client1` resource blocks
(`libvirt_volume`, `libvirt_cloudinit_disk`, `libvirt_domain`), rename each
to `client2`, and update internal references to `client1` → `client2`.

**3. `terraform/outputs.tf`** — add to the `management_ips` output:
```hcl
client2 = var.mgmt_ips.client2
```

**4. `scripts/gen_inventory.py`** — add a `client2` line to the `[clients]`
section in `render_inventory()`, following the `client1` pattern.

Then re-provision and configure:
```bash
cd terraform/ && terraform apply
cd .. && python3 scripts/gen_inventory.py
cd ansible/ && ansible-playbook -i hosts.ini client_setup.yaml
```

The MPI hosts file (`~/mpi_hostfile`) is generated from the `[clients]` inventory
group and will include `client2` automatically after re-running `client_setup.yaml`.

> **Note:** Running IOR across multiple clients with `mpirun` requires passwordless
> SSH between client nodes. This is not configured by the current playbooks — only
> the KVM host key is injected via cloud-init. Distribute a shared SSH keypair
> among clients before attempting multi-node MPI runs.

---

## Phase 4 — Teardown

See [teardown/README.md](../teardown/README.md) for L1 (graceful unmount),
L2 (reset block devices), and L3 (full infrastructure destroy) options.
