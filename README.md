# Lustre Dev Blueprint

A repeatable KVM-based test environment for a Lustre parallel filesystem cluster,
with Ansible configuration and Terraform infrastructure provisioning. Intended as
a portfolio demo of building and automating a storage technology stack from scratch.

**Cluster topology:** 1 client, 1 MGS, 2 MDS, 4 OSS — all Rocky Linux 9.4 VMs.

See [docs/runbook.md](docs/runbook.md) for the full deployment walkthrough.

---

## Prerequisites

The following must be installed on the KVM host before starting:

| Tool | Minimum version | Notes |
|------|----------------|-------|
| KVM / libvirt | — | `libvirtd` must be running |
| Terraform | >= 1.6 | [install guide](https://developer.hashicorp.com/terraform/install) |
| Python | >= 3.9 | System Python on Rocky 9.4 |
| git | — | |

## Setup

**1. Clone the repository**

```bash
git clone <repo-url> lustre-dev-blueprint
cd lustre-dev-blueprint
```

**2. Create and activate a Python virtual environment**

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**3. Install the required Ansible collection**

```bash
ansible-galaxy collection install community.general
```

**4. Install pre-commit hooks**

```bash
pre-commit install
```

**5. Configure your inventory**

```bash
cp ansible/hosts.ini.example ansible/hosts.ini
```

Edit `ansible/hosts.ini` to set `ansible_host` for each node to its management
IP (from Terraform output after provisioning). The LNET IPs (`ip_enp7`, `ip_enp8`)
are pre-populated and match the Terraform network configuration.

`ansible/group_vars/all.yml` sets `ansible_user: ansible` by default, which
matches the Terraform `vm_user` default. If you override `vm_user` in
`terraform.tfvars`, set `ansible_user` to the same value here.

---

## Versioning

Versions follow `major.minor.feature` starting at `0.1.1`. The current version
is in the `VERSION` file. Git tags (`vX.Y.Z`) are applied at release points;
the initial tag is held until the first functional feature is complete.

## License

MIT — see [LICENSE](LICENSE).
