#!/bin/bash
#
# Author : Nathanael Frappart
#
# script to run before first terraform deployment
# this script will provision:
# - a resource group
# - a storage account
# - create a blob for terraform state file
# - a keyvault to store the blob key
# then, it will generate the terraform_login.sh script to use to securely connect your terminal to your subscription (ARM environment variables)


####################
# Connect to Azure #
####################

# login to azure
echo ""
echo "###################################################"
echo "# You will be rediected to Azure login page in 5s #"
echo "###################################################"
sleep 5
az login --output none

# list all subscriptions
echo "..."
echo "### Available susbscription list: ###"
az account list --output table

########################
# Set script variables #
########################

# input Subscription id
echo "..."
echo "### Enter subscription ID: ###"
read SUBSCRIPTION_ID

# select subscription for the session
az account set -s $SUBSCRIPTION_ID
SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)
echo ""
echo "### session is set to subscription named '$SUBSCRIPTION_NAME' ###" 

# set variables for resources names
echo "..."
echo "### Now we'll define the names for resources to be created ###"
echo "..."
echo "First, enter your company name (***alphanumerical lowercase only***):"
read COMPANY
COMPANY=${COMPANY//[^[:alnum:]]/}
COMPANY=${COMPANY,,}

echo "..."
echo "### Name for Resource Group ###"
echo "(default is rg-terraform-<YourCompany>): ###"
read RESOURCE_GROUP_NAME
if [ "$RESOURCE_GROUP_NAME" = "" ]; then
    RESOURCE_GROUP_NAME=rg-terraform-$COMPANY
fi
echo "..."
echo "### Location for Resource Group ###" 
echo "(default is 'westeurope'):"
read RESOURCE_GROUP_LOCATION
# check if location is valid
read -r -a LOCATIONS_LIST <<< $(az account list-locations --query "[*].name" -o tsv)
LOCATION_DEFAULT="westeurope"
for LOCATION in ${LOCATIONS_LIST[@]}; do
   if [ "$RESOURCE_GROUP_LOCATION" = "${LOCATION}" ]; then
     break; #if location is valid, then exit the loop
   fi
   RESOURCE_GROUP_LOCATION=$LOCATION_DEFAULT #if the input location value doesn't match, it is set to default value
done

STORAGE_ACCOUNT_NAME=tfstate$COMPANY #$SERIAL
CONTAINER_NAME=tfstate

SERVICE_PRINCIPAL_NAME=sp-terraform-$COMPANY

##########################
# Resources provisioning #
##########################

# create service principal with contributor role for terraform
echo "..."
echo "### Creating Service Principal in Azure AD for Terraform ###"
#read -r -a SP_TERRAFORM <<< $(az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --query "[appId,password]" -o tsv) #replace -A with -a to run in bash instead of zsh
mapfile -t SP_TERRAFORM< <(az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --role Contributor --query "[appId,password]" -o tsv)
SP_TERRAFORM_ID=${SP_TERRAFORM[0]}
SP_TERRAFORM_SECRET=${SP_TERRAFORM[1]}

# create resource group
echo "..."
echo "### Creating resource group ###"
az group create \
    -l $RESOURCE_GROUP_LOCATION \
    -n $RESOURCE_GROUP_NAME \
    -o none

# create storage account
echo "..."
echo "### Creating storage account ###"    
az storage account create \
    --name $STORAGE_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --sku Standard_LRS \
    --encryption-services blob \
    -o none

# get storage account key
echo "..."
echo "### Retrieving storage account key ###"   
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query [0].value -o tsv)

# create container for blob
echo "..."
echo "### Creating blob container ###"
az storage container create \
    --account-name $STORAGE_ACCOUNT_NAME \
    --name terraform \
    --account-key $STORAGE_ACCOUNT_KEY \
    -o none

# create keyvault to store secret
# - blob key
# - service principal client secret
echo "..."
echo "### Creating Keyvault 'kv-terraform-<companyname>' for terraform necessary secrets ###"
echo "(keyvault name might be truncated if length exceed 24 characters)"
KV_NAME=kv-terraform-$COMPANY
KV_NAME=${KV_NAME:0:24}
az keyvault create \
    --name $KV_NAME \
    --location $RESOURCE_GROUP_LOCATION \
    --resource-group $RESOURCE_GROUP_NAME \
    -o none

# add permission for sp to keyvault
echo "### Add permission for SP to keyvault ###"
az keyvault set-policy \
    --name $KV_NAME \
    --object-id $SP_TERRAFORM_ID \
    --secret-permissions backup delete get list purge recover restore set \
    --key-permissions backup create decrypt delete encrypt get import list purge recover restore sign unwrapKey update verify wrapKey  \
    --certificate-permissions backup create delete deleteissuers get getissuers import list listissuers managecontacts manageissuers purge recover restore setissuers update \
    -o none

# register blob key to keyvault
echo "### Save blob key in keyvault secret ###" 
az keyvault secret set \
    --name "$STORAGE_ACCOUNT_NAME-key" \
    --vault-name $KV_NAME \
    --value $STORAGE_ACCOUNT_KEY \
    -o none

# register service principal secret to keyvault
echo "### Save SP Client Secret in keyvault secret ###"
az keyvault secret set \
    --name $SERVICE_PRINCIPAL_NAME-secret \
    --vault-name $KV_NAME \
    --value $SP_TERRAFORM_SECRET \
    -o none

# register service principal id to keyvault
echo "### Save SP Client ID in keyvault secret ###"
az keyvault secret set \
    --name $SERVICE_PRINCIPAL_NAME-id \
    --vault-name $KV_NAME \
    --value $SP_TERRAFORM_ID \
    -o none

 # terraform provider file template
 echo "..."
 echo "..."
 echo "### The folowing text has been copied to a main.tf file to setup your backend"
 echo "### Then run terraform init to initialize backend ###"
 echo "
 provider "\""azurerm"\"" {
  features {}
 }
 terraform {
  required_providers {
    azurerm = {
      version = "\""~> 2.39.0"\""
    }
  }
  backend "\""azurerm"\"" {
    storage_account_name = "\""$STORAGE_ACCOUNT_NAME"\""
    container_name       = "\""terraform"\""
    key                  = "\""terraform.tfstate"\""
  }
 }
" > main.tf
cat main.tf

sleep 5
echo "..."
echo "..."
echo "### The script will now launch terraform_login.sh and go through authentication again ###"
echo "### after that, run 'terraform init' to initialise your backend ###"
sleep 5

# launch terraform login script
source terraform_login.sh
