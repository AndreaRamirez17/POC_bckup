# Terraform notes


## ! I M P O R T A N T ! , Before start, verify you have the following content in you .gitignore file
```bash
# Terraform files
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
crash.log

```

## General commands
```bash
terraform init

terraform plan

terraform apply

terraform apply -auto-approve

terraform destroy

terraform destroy -auto-approve
```

## Low Environment with Akamai (Linode)
```bash
# In project root directory go to the required directory development or testing

# Development to work with a virtual machine
cd ./terraform/akamai/development

# testing to work with Kubernetes
cd ./terraform/akamai/testing

```