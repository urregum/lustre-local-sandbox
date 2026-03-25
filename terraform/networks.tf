# Storage pool for all VM disk images and the cached base OS image.
# Created once; persists across VM destroy/apply cycles unless explicitly removed.
resource "libvirt_pool" "lustre_demo" {
  name = "lustre-demo"
  type = "dir"
  path = var.libvirt_pool_path
}

# Management network — NAT mode.
# Provides: host-to-VM SSH access, VM outbound internet for package management.
resource "libvirt_network" "lustre_mgmt" {
  name      = "lustre-mgmt"
  mode      = "nat"
  addresses = [var.mgmt_network_cidr]
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled = true
  }
}

# LNet network 0 — isolated (no external routing).
# Static IPs assigned by Ansible via nmcli after provisioning.
resource "libvirt_network" "lustre_lnet0" {
  name      = "lustre-lnet0"
  mode      = "none"
  autostart = true
}

# LNet network 1 — isolated (no external routing).
# Static IPs assigned by Ansible via nmcli after provisioning.
resource "libvirt_network" "lustre_lnet1" {
  name      = "lustre-lnet1"
  mode      = "none"
  autostart = true
}
