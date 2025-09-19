# -----------------------------------------------------------------------------
# Required providers (OpenTofu/Terraform + OpenStack provider)
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider (reads credentials from sourced OpenStack RC file)
# -----------------------------------------------------------------------------
provider "openstack" {}

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------
resource "openstack_networking_network_v2" "iac_network" {
  name           = "my-iac-network"
  admin_state_up = true
}

# -----------------------------------------------------------------------------
# Subnet
# -----------------------------------------------------------------------------
resource "openstack_networking_subnet_v2" "iac_subnet" {
  network_id = openstack_networking_network_v2.iac_network.id
  cidr       = "192.168.0.0/24"
  ip_version = 4
}

# -----------------------------------------------------------------------------
# Router (connect private subnet to the external network)
# -----------------------------------------------------------------------------
resource "openstack_networking_router_v2" "iac_router" {
  name           = "iac-router"
  admin_state_up = true
  # external_network_id should usually not be hardcoded (but for cumulus it is)
  external_network_id = "76879e07-c093-4a08-9664-c7aed800b723"
}

# -----------------------------------------------------------------------------
# Router interface (attach router to the subnet)
# -----------------------------------------------------------------------------
resource "openstack_networking_router_interface_v2" "iac_router_interface" {
  router_id = openstack_networking_router_v2.iac_router.id
  subnet_id = openstack_networking_subnet_v2.iac_subnet.id
}

# -----------------------------------------------------------------------------
# Security group (holds ingress/egress rules)
# -----------------------------------------------------------------------------
resource "openstack_networking_secgroup_v2" "iac_secgroup" {
  name        = "iac-sec-group"
  description = "Security group for IaC: SSH, HTTP, and egress"
}

# -----------------------------------------------------------------------------
# Security group rule: SSH ingress (port 22)
# -----------------------------------------------------------------------------
resource "openstack_networking_secgroup_rule_v2" "iac_secgroup_rule_ssh" {
  description       = "Allow SSH"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.iac_secgroup.id
}

# -----------------------------------------------------------------------------
# Security group rule: HTTP ingress (port 80)
# -----------------------------------------------------------------------------
resource "openstack_networking_secgroup_rule_v2" "iac_secgroup_rule_http" {
  description       = "Allow HTTP"
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.iac_secgroup.id
}

# -----------------------------------------------------------------------------
# Port (NIC) for the instance, with the security group applied on the port
# -----------------------------------------------------------------------------
resource "openstack_networking_port_v2" "iac_port" {
  name               = "iac-port"
  network_id         = openstack_networking_network_v2.iac_network.id
  admin_state_up     = true
  security_group_ids = [
    openstack_networking_secgroup_v2.iac_secgroup.id,
    openstack_networking_secgroup_v2.web_extra.id
    ]
}

# -----------------------------------------------------------------------------
# Floating IP (external/public address for the server)
# -----------------------------------------------------------------------------
# "pool" refers to the external network from which the floating IP is allocated.
# - Using pool = "public" means: "Give me a floating IP from the network named 'public'."
# - This is simpler and matches the lecture.
# - Alternative: use floating_network_id = "<UUID>" for the exact network ID.
#   That is more explicit and avoids breakage if the network is renamed.
# -----------------------------------------------------------------------------
resource "openstack_networking_floatingip_v2" "iac_floatip" {
  pool = "public"
}

# -----------------------------------------------------------------------------
# Compute instance
# -----------------------------------------------------------------------------
# Note: The SSH login user is not declared here. It depends on the image.
# - For the official Ubuntu cloud images → user is "ubuntu" (default baked into the image).
# - Other images may use different defaults: "centos", "debian", "fedora", etc.
# - OpenStack injects your public key into that default user's ~/.ssh/authorized_keys.
# - Your OpenStack API username (e.g. mu222cu-2dv013) is unrelated to VM SSH login.
# -----------------------------------------------------------------------------
resource "openstack_compute_instance_v2" "iac_server" {
  name = "iac-server-1"
  #  image_id     = "772b2dec-f649-4c57-bbc2-f3eaaad5f651" (image name used instead)
  image_name      = "Ubuntu server 24.04.3 autoupgrade"
  flavor_id       = "c1-r1-d10"
  key_pair        = "mu222cu-keypair"

  # security_groups here was deleted since port controls it.

  network {
    port = openstack_networking_port_v2.iac_port.id
  }

  depends_on = [openstack_networking_router_interface_v2.iac_router_interface]
}

# -----------------------------------------------------------------------------
# Associate the Floating IP to the instance's port
# -----------------------------------------------------------------------------
resource "openstack_networking_floatingip_associate_v2" "iac_fip_association" {
  floating_ip = openstack_networking_floatingip_v2.iac_floatip.address
  port_id     = openstack_networking_port_v2.iac_port.id
}

# -----------------------------------------------------------------------------
# Outputs (show the public IP, plus a ready-to-run SSH command)
# -----------------------------------------------------------------------------
# Note: Extra SSH options added because OpenStack floating IPs can be
# recycled. If the same IP was used for a different VM earlier, the saved host
# key in ~/.ssh/known_hosts would mismatch and block login.
#
# -o "UserKnownHostsFile=/dev/null"     → do not save host keys
# -o "StrictHostKeyChecking=no"         → skip warnings about changed host keys
# -i ~/.ssh/mu222cu-keypair-cumulus.pem → private key for this OpenStack tenant
# ubuntu@...                            → default login user for Ubuntu cloud image
# -----------------------------------------------------------------------------
output "my_public_ip" {
  value = openstack_networking_floatingip_v2.iac_floatip.address
}

output "iac_ssh_command" {
  value = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/mu222cu-keypair-cumulus.pem ubuntu@${openstack_networking_floatingip_v2.iac_floatip.address}"
}
