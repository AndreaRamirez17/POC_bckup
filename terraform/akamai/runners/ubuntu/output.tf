
output "instance_id" {
    value = linode_instance.poc-ubuntu-runner-instance.id
    description = "The ID of the Linode instance"
}

output "instance_ip" {
    value = linode_instance.poc-ubuntu-runner-instance.ip_address
    description = "The public IP address of the Linode instance"
}

output "instance_label" {
    value = linode_instance.poc-ubuntu-runner-instance.label
    description = "The label of the Linode instance"
}

output "ssh_command" {
    value = "ssh root@${linode_instance.poc-ubuntu-runner-instance.ip_address}"
    description = "Command to SSH into the instance"
}
