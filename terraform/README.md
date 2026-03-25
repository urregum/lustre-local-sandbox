# Terraform

Provisions the KVM infrastructure for the Lustre dev cluster using the
[libvirt provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest).

## Prerequisites

- libvirt installed and `libvirtd` running
- Current user in the `libvirt` group (`sudo usermod -aG libvirt $USER`)
- Terraform >= 1.6

## Current state

The following resources are defined:

| File | Resources |
|------|-----------|
| `providers.tf` | libvirt provider, Terraform version constraint |
| `variables.tf` | All configurable inputs with defaults |
| `networks.tf` | `lustre-demo` storage pool, `lustre-mgmt`/`lustre-lnet0`/`lustre-lnet1` networks |

VM resources (`libvirt_domain`, `libvirt_cloudinit_disk`, `libvirt_volume`) are
not yet implemented. See [docs/TODO.md](../docs/TODO.md).

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Key variables

Override defaults by creating a `terraform.tfvars` file (gitignored):

```hcl
# Example overrides
libvirt_pool_path   = "/data/lustre-demo"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
vm_user             = "myuser"
```

See `variables.tf` for the full list with descriptions and defaults.
