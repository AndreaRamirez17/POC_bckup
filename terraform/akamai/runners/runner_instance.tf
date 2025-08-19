terraform {
  required_providers {
    linode = {
      source = "linode/linode"
    }
  }
}

provider "linode" {
  token = var.linode_poc_vm_token
}

# linode
resource "linode_instance" "poc-runner" {
  region         = var.region
  image          = var.image
  #stackscript_id = var.stackscript_id
  type           = var.instance_type
  label          = var.instance_label
  tags           = var.instance_tags

  authorized_users = var.authorized_users
  root_pass       = var.root_pass

  # Add user_data for StackScript UDF fields
  # Add other UDF fields as needed by your StackScript
  #stackscript_data = {
  #  "user_name" = var.stackscript_username    
  #}

  provisioner "file" {
    source      = "./scripts/setup_ubuntu_instance.sh"
    destination = "/tmp/setup_ubuntu_instance.sh"
    connection {
      type     = "ssh"
      host     = self.ip_address
      user     = "root"
      password = var.root_pass
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup_ubuntu_instance.sh",
      "/tmp/setup_script.sh '${var.runner_name}' '${var.runner_pass}' ",
      "sleep 1"
    ]

    connection {
      type     = "ssh"
      host     = self.ip_address
      user     = "root"
      password = var.root_pass
    }
  }
}

# firewall
resource "linode_firewall" "runner_firewall" {
  label = "runner_firewall_label"
  
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["ff00::/8"]
  }

  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["ff00::/8"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
  linodes         = [linode_instance.poc-runner.id]
}
