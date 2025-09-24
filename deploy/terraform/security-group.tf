# security-group.tf

resource "openstack_networking_secgroup_v2" "web_extra" {
  name        = "web-extra"
  description = "Allow SSH and web ports for experiments"
}

# SSH
resource "openstack_networking_secgroup_rule_v2" "web_extra_ssh" {
  security_group_id = openstack_networking_secgroup_v2.web_extra.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
}

# HTTP (optional)
resource "openstack_networking_secgroup_rule_v2" "web_extra_http" {
  security_group_id = openstack_networking_secgroup_v2.web_extra.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
}

# Custom nginx port 8080
resource "openstack_networking_secgroup_rule_v2" "web_extra_8080" {
  security_group_id = openstack_networking_secgroup_v2.web_extra.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
}

