# Teardown

Three teardown levels are available, each a superset of the previous.
Choose the lowest level that meets your need to preserve as much state as possible.

---

## L1 — Graceful Cluster Shutdown

**Use when:** You want to stop the Lustre cluster for debugging or reconfiguration
without losing filesystem data or needing to reformat. VMs remain running.
Re-running the Ansible setup plays will bring the cluster back up.

**What it does:**
- Unmounts all Lustre filesystems in safe order: clients → OSS → MDS → MGS
- Stops the `lustre-modules` systemd service on all nodes
- Unloads `lustre` and `lnet` kernel modules

```bash
cd ansible/
ansible-playbook -i hosts.ini teardown_l1.yaml
```

---

## L2 — Block Device Reset

**Use when:** You need to re-run `mkfs.lustre` (e.g., changing filesystem
parameters or recovering from a corrupt superblock). VMs remain running.
**Data on the Lustre filesystem will be destroyed.**

**What it does:**
- Everything in L1
- Runs `wipefs -a /dev/vdb` on all server nodes, clearing the Lustre superblock

After L2, re-running the Ansible storage setup play will reformat and remount cleanly.

```bash
cd ansible/
ansible-playbook -i hosts.ini teardown_l2.yaml
```

---

## L3 — Full Infrastructure Destroy

**Use when:** You want to completely remove all VMs, networks, and disk images.
A subsequent `terraform apply` will rebuild from scratch.
**All VM state and data will be permanently destroyed.**

**What it does:**
- Destroys all libvirt VMs, their disk volumes, and cloud-init ISOs
- Removes the `lustre-mgmt`, `lustre-lnet0`, and `lustre-lnet1` networks
- Removes the `lustre-demo` storage pool and its directory contents

```bash
cd terraform/
terraform destroy
```

> Note: L3 does not delete the cached Rocky Linux base image from the pool path.
> On the next `terraform apply`, VMs will be provisioned from the cached image
> without re-downloading. To force a fresh image download, manually remove the
> base volume from the pool before applying.
