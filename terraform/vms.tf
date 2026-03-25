locals {
  # Conversion factor: GiB to bytes for libvirt_volume size
  gib = 1073741824

  # Management IP lists indexed to match count.index for multi-instance roles
  mds_ips = [var.mgmt_ips.mds1, var.mgmt_ips.mds2]
  oss_ips = [var.mgmt_ips.oss1, var.mgmt_ips.oss2, var.mgmt_ips.oss3, var.mgmt_ips.oss4]
}

# ── Base OS image ─────────────────────────────────────────────────────────────
# Downloaded once into the pool; all VM boot disks are cloned from this volume.
# Re-downloaded only if the volume is destroyed (L3 teardown removes the pool).
resource "libvirt_volume" "rocky_base" {
  name   = "rocky-9-base.qcow2"
  pool   = libvirt_pool.lustre_demo.name
  source = var.rocky_cloud_image_url
  format = "qcow2"
}

# ── MGS ───────────────────────────────────────────────────────────────────────

resource "libvirt_volume" "mgs_boot" {
  name           = "mgs-boot.qcow2"
  pool           = libvirt_pool.lustre_demo.name
  base_volume_id = libvirt_volume.rocky_base.id
  size           = var.boot_disk_gb * local.gib
  format         = "qcow2"
}

resource "libvirt_volume" "mgs_data" {
  name   = "mgs-data.qcow2"
  pool   = libvirt_pool.lustre_demo.name
  size   = var.data_disk_gb * local.gib
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "mgs" {
  name = "mgs-cloudinit.iso"
  pool = libvirt_pool.lustre_demo.name
  user_data = templatefile("${path.module}/templates/cloud-init-user.tftpl", {
    hostname       = "mgs"
    vm_user        = var.vm_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    mgmt_ips       = var.mgmt_ips
  })
  network_config = templatefile("${path.module}/templates/cloud-init-network.tftpl", {
    mgmt_ip      = var.mgmt_ips.mgs
    mgmt_prefix  = var.mgmt_prefix
    mgmt_gateway = var.mgmt_gateway
  })
}

resource "libvirt_domain" "mgs" {
  name      = "mgs"
  vcpu      = var.mgs.vcpus
  memory    = var.mgs.memory
  autostart = false
  cloudinit = libvirt_cloudinit_disk.mgs.id

  network_interface {
    network_id = libvirt_network.lustre_mgmt.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet0.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet1.id
  }

  disk {
    volume_id = libvirt_volume.mgs_boot.id
  }
  disk {
    volume_id = libvirt_volume.mgs_data.id
  }

  boot_device {
    dev = ["hd"]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

# ── MDS ───────────────────────────────────────────────────────────────────────

resource "libvirt_volume" "mds_boot" {
  count          = var.mds.count
  name           = "mds${count.index + 1}-boot.qcow2"
  pool           = libvirt_pool.lustre_demo.name
  base_volume_id = libvirt_volume.rocky_base.id
  size           = var.boot_disk_gb * local.gib
  format         = "qcow2"
}

resource "libvirt_volume" "mds_data" {
  count  = var.mds.count
  name   = "mds${count.index + 1}-data.qcow2"
  pool   = libvirt_pool.lustre_demo.name
  size   = var.data_disk_gb * local.gib
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "mds" {
  count = var.mds.count
  name  = "mds${count.index + 1}-cloudinit.iso"
  pool  = libvirt_pool.lustre_demo.name
  user_data = templatefile("${path.module}/templates/cloud-init-user.tftpl", {
    hostname       = "mds${count.index + 1}"
    vm_user        = var.vm_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    mgmt_ips       = var.mgmt_ips
  })
  network_config = templatefile("${path.module}/templates/cloud-init-network.tftpl", {
    mgmt_ip      = local.mds_ips[count.index]
    mgmt_prefix  = var.mgmt_prefix
    mgmt_gateway = var.mgmt_gateway
  })
}

resource "libvirt_domain" "mds" {
  count     = var.mds.count
  name      = "mds${count.index + 1}"
  vcpu      = var.mds.vcpus
  memory    = var.mds.memory
  autostart = false
  cloudinit = libvirt_cloudinit_disk.mds[count.index].id

  network_interface {
    network_id = libvirt_network.lustre_mgmt.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet0.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet1.id
  }

  disk {
    volume_id = libvirt_volume.mds_boot[count.index].id
  }
  disk {
    volume_id = libvirt_volume.mds_data[count.index].id
  }

  boot_device {
    dev = ["hd"]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

# ── OSS ───────────────────────────────────────────────────────────────────────

resource "libvirt_volume" "oss_boot" {
  count          = var.oss.count
  name           = "oss${count.index + 1}-boot.qcow2"
  pool           = libvirt_pool.lustre_demo.name
  base_volume_id = libvirt_volume.rocky_base.id
  size           = var.boot_disk_gb * local.gib
  format         = "qcow2"
}

resource "libvirt_volume" "oss_data" {
  count  = var.oss.count
  name   = "oss${count.index + 1}-data.qcow2"
  pool   = libvirt_pool.lustre_demo.name
  size   = var.data_disk_gb * local.gib
  format = "qcow2"
}

resource "libvirt_cloudinit_disk" "oss" {
  count = var.oss.count
  name  = "oss${count.index + 1}-cloudinit.iso"
  pool  = libvirt_pool.lustre_demo.name
  user_data = templatefile("${path.module}/templates/cloud-init-user.tftpl", {
    hostname       = "oss${count.index + 1}"
    vm_user        = var.vm_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    mgmt_ips       = var.mgmt_ips
  })
  network_config = templatefile("${path.module}/templates/cloud-init-network.tftpl", {
    mgmt_ip      = local.oss_ips[count.index]
    mgmt_prefix  = var.mgmt_prefix
    mgmt_gateway = var.mgmt_gateway
  })
}

resource "libvirt_domain" "oss" {
  count     = var.oss.count
  name      = "oss${count.index + 1}"
  vcpu      = var.oss.vcpus
  memory    = var.oss.memory
  autostart = false
  cloudinit = libvirt_cloudinit_disk.oss[count.index].id

  network_interface {
    network_id = libvirt_network.lustre_mgmt.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet0.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet1.id
  }

  disk {
    volume_id = libvirt_volume.oss_boot[count.index].id
  }
  disk {
    volume_id = libvirt_volume.oss_data[count.index].id
  }

  boot_device {
    dev = ["hd"]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

# ── Client ────────────────────────────────────────────────────────────────────
# No data disk; Whamcloud client RPMs and MPI/IOR installed by Ansible.

resource "libvirt_volume" "client_boot" {
  name           = "client1-boot.qcow2"
  pool           = libvirt_pool.lustre_demo.name
  base_volume_id = libvirt_volume.rocky_base.id
  size           = var.boot_disk_gb * local.gib
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "client" {
  name = "client1-cloudinit.iso"
  pool = libvirt_pool.lustre_demo.name
  user_data = templatefile("${path.module}/templates/cloud-init-user.tftpl", {
    hostname       = "client1"
    vm_user        = var.vm_user
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    mgmt_ips       = var.mgmt_ips
  })
  network_config = templatefile("${path.module}/templates/cloud-init-network.tftpl", {
    mgmt_ip      = var.mgmt_ips.client1
    mgmt_prefix  = var.mgmt_prefix
    mgmt_gateway = var.mgmt_gateway
  })
}

resource "libvirt_domain" "client" {
  name      = "client1"
  vcpu      = var.client.vcpus
  memory    = var.client.memory
  autostart = false
  cloudinit = libvirt_cloudinit_disk.client.id

  network_interface {
    network_id = libvirt_network.lustre_mgmt.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet0.id
  }
  network_interface {
    network_id = libvirt_network.lustre_lnet1.id
  }

  disk {
    volume_id = libvirt_volume.client_boot.id
  }

  boot_device {
    dev = ["hd"]
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
