# terraform-azure-init
**This repo is made of 2 bash scripts to jumpstart your terraform journey on Azure in better condition.**

**The first script 'init-azurebackend-blob.sh':**
- create storage account for blob to use as a terraform backend
- create service principal for terraform
- create keyvault to store SP ID and Secret, as well as storage container key
- generate main.tf with remote backend configuration so you can focus on testing resource provisioning, not configuration of terraform

**The second script 'terraform_login.sh':**
- logs you in azure with azcli
- retrieve SP ID and Secret, as well as storage container key and export them in terraform environment variables

The first time, you only have to run '. init-azurebackend-blob.sh' in bash (use the dot space syntax so the environment variables are set in the current context).
After that, just run '. terraform_login.sh' in bash when you want to use terraform CLI to provision resources.

The generated file will look as below, omitting all secrets, because the script uses environement variable paired with keyvault to keep your work secure.
```hcl
provider "azurerm" {
  features {}
 }
 terraform {
  required_providers {
    azurerm = {
      version = "~> 2.39.0"
    }
  }
  backend "azurerm" {
    storage_account_name = $STORAGE_ACCOUNT_NAME
    container_name       = "terraform"
    key                  = "terraform.tfstate"
  }
 }
 ```
**Work with your team !**
Just share the main.tf file and terraform_login.sh script with your team via your favorite VCS like GIT ;)
Enjoy terraforming your Azure infrastructure ! 
 
