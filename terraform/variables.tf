variable "libvirt_pool_path" {
  description = "Absolute path on the KVM host for the lustre-demo storage pool"
  type        = string
  default     = "/var/lib/libvirt/lustre-demo"
}

variable "rocky_cloud_image_url" {
  description = "URL or local file path for the Rocky Linux 9.4 generic cloud image (.qcow2)"
  type        = string
  default     = "https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
}

variable "mgmt_network_cidr" {
  description = "CIDR for the management NAT network"
  type        = string
  default     = "10.0.100.0/24"
}

variable "lnet_network_cidr_0" {
  description = "CIDR for lustre-lnet0 (isolated). Hosts use static IPs in this range."
  type        = string
  default     = "192.168.100.0/16"
}

variable "lnet_network_cidr_1" {
  description = "CIDR for lustre-lnet1 (isolated). Hosts use static IPs in this range."
  type        = string
  default     = "192.168.100.0/16"
}

variable "boot_disk_gb" {
  description = "Boot disk size in GiB for all VMs"
  type        = number
  default     = 20
}

variable "data_disk_gb" {
  description = "Data disk size in GiB for server VMs (MGS, MDS, OSS)"
  type        = number
  default     = 5
}

variable "mgs" {
  description = "MGS VM resource configuration"
  type = object({
    vcpus  = number
    memory = number # MiB
  })
  default = {
    vcpus  = 2
    memory = 2048
  }
}

variable "mds" {
  description = "MDS VM resource configuration"
  type = object({
    vcpus  = number
    memory = number # MiB
    count  = number
  })
  default = {
    vcpus  = 2
    memory = 4096
    count  = 2
  }
}

variable "oss" {
  description = "OSS VM resource configuration"
  type = object({
    vcpus  = number
    memory = number # MiB
    count  = number
  })
  default = {
    vcpus  = 2
    memory = 2048
    count  = 4
  }
}

variable "client" {
  description = "Client VM resource configuration"
  type = object({
    vcpus  = number
    memory = number # MiB
  })
  default = {
    vcpus  = 2
    memory = 4096
  }
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to inject into VMs via cloud-init"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "vm_user" {
  description = "Username to create on VMs via cloud-init (must match ansible_user in group_vars/all.yml)"
  type        = string
  default     = "ansible"
}
