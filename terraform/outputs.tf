output "management_ips" {
  description = "Static management IP for each cluster node. Use these values to populate ansible_host in ansible/hosts.ini."
  value = {
    mgs     = var.mgmt_ips.mgs
    mds1    = var.mgmt_ips.mds1
    mds2    = var.mgmt_ips.mds2
    oss1    = var.mgmt_ips.oss1
    oss2    = var.mgmt_ips.oss2
    oss3    = var.mgmt_ips.oss3
    oss4    = var.mgmt_ips.oss4
    client1 = var.mgmt_ips.client1
  }
}
