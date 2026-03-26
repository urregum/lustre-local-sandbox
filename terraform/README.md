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

Copy `terraform.tfvars.example` to `terraform.tfvars` (gitignored) and
uncomment any values that differ from your environment. The most common
override is `mgmt_ips` when `10.0.100.0/24` conflicts with an existing
network on the host:

```hcl
mgmt_network_cidr = "10.0.100.0/24"
mgmt_gateway      = "10.0.100.1"

mgmt_ips = {
  mgs     = "10.0.100.10"
  mds1    = "10.0.100.11"
  mds2    = "10.0.100.12"
  oss1    = "10.0.100.13"
  oss2    = "10.0.100.14"
  oss3    = "10.0.100.15"
  oss4    = "10.0.100.16"
  client1 = "10.0.100.20"
}
```

See `variables.tf` for the full list with descriptions and defaults.
