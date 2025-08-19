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

## REFERENCES

### GitHub Actions
- [Pass environment variables to shell script](https://github.com/appleboy/ssh-action?tab=readme-ov-file#pass-environment-variables-to-shell-script)
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions#calculating-minute-and-storage-spending)
- [Setting up budgets to control spending on metered products](https://docs.github.com/en/billing/tutorials/set-up-budgets)
- [How use of GitHub Actions is measured](https://docs.github.com/en/billing/concepts/product-billing/github-actions#how-use-of-github-actions-is-measured)

## Terraform
- [Provisioners](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax)
- [remote-exec Provisioner](https://developer.hashicorp.com/terraform/language/resources/provisioners/remote-exec)
- [File Provisioner](https://developer.hashicorp.com/terraform/language/resources/provisioners/file)
- [linode_instance](https://registry.terraform.io/providers/linode/linode/latest/docs/resources/instance#stackscript_id-1)


### Linux
- [Bash shell find out if a variable has NULL value OR not](https://www.cyberciti.biz/faq/bash-shell-find-out-if-a-variable-has-null-value-or-not/)
- [How to Check If a Variable is Empty/Null in Bash? [4 Methods]](https://linuxsimply.com/bash-scripting-tutorial/conditional-statements/if/if-empty-or-not/)

### Solving Issues
- [How to find whether or not a variable is empty in Bash](https://stackoverflow.com/questions/3061036/how-to-find-whether-or-not-a-variable-is-empty-in-bash)