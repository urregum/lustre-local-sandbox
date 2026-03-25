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
- `ansible-galaxy collection install community.general` completed
- `ansible/hosts.ini` copied from example (management IPs filled in after Phase 1)
- `ansible/group_vars/all.yml` `ansible_user` set to your VM username

---

## Phase 1 — Provision Infrastructure (Terraform)

Initialize and apply the Terraform configuration. This will:

- Create the `lustre-demo` libvirt storage pool at `/var/lib/libvirt/lustre-demo/`
- Download the Rocky Linux 9.4 cloud image (first run only)
- Create the `lustre-mgmt` (NAT), `lustre-lnet0`, and `lustre-lnet1` networks
- Provision 8 VMs (1 client, 1 MGS, 2 MDS, 4 OSS) with cloud-init configuration

```bash
cd terraform/
terraform init
terraform apply
```

After `apply` completes, retrieve the management IPs:

```bash
terraform output
```

Update `ansible/hosts.ini` with the `ansible_host` value for each node.

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
# Example: single-process write/read test
mpirun -np 1 ior -w -r -b 1g -t 1m -F -o /mnt/lustre/ior_test
```

---

## Phase 4 — Teardown

See [teardown/README.md](../teardown/README.md) for L1 (graceful unmount),
L2 (reset block devices), and L3 (full infrastructure destroy) options.
