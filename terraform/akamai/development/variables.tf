
variable "linode_poc_vm_token" {
  type        = string
  description = "Temporal token only to create Linode Instances. This value in define in environment"
  sensitive   = true
}

variable "root_pass" {
  type        = string
  description = "Root password for the Linode Instance"
  sensitive   = true
}

variable "developer_pass" {
  type        = string
  description = "Password for the developer user"
  sensitive   = true
}

variable "developer_name" {
  type = string
  description = "Developer username for the linode instance"
  default = "developer"  
}

variable "region" {
  type        = string
  description = "The region where the Linode instance will be created"
  default     = "us-ord"
}

variable "image" {
  type        = string
  description = "The image to use for the Linode instance"
  default     = "linode/ubuntu24.04"
}

variable "stackscript_username" {
    type = string
    description = "UDF username that execute the StackScript"
    default = "demo"
}

variable "stackscript_id" {
  type        = number
  description = "The ID of the StackScript to use"
  default     = 607433
}

variable "instance_type" {
  type        = string
  description = "The type/size of the Linode instance"
  default     = "g6-standard-4"
}

variable "instance_label" {
  type        = string
  description = "The label for the Linode instance"
  default     = "poc-docker-ubuntu-linode"
}

variable "instance_tags" {
  type        = list(string)
  description = "Tags to apply to the Linode instance"
  default     = ["poc", "docker", "ubuntu"]
}

variable "authorized_users" {
  type        = list(string)
  description = "List of Linode usernames that will receive root access to the instance"
  sensitive   = true
}