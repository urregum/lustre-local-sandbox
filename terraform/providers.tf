terraform {
  required_version = ">= 1.6.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

provider "libvirt" {
  # Connects to the local system libvirt daemon.
  # Requires the running user to be in the 'libvirt' group.
  uri = "qemu:///system"
}
