#
# Author : Nathanael Frappart
#
# use ":set fileformat=unix" in VIM before saving to change encoding issue if occurs
echo ""
echo "###################################################"
echo "# You will be rediected to Azure login page in 5s #"
echo "###################################################"
sleep 5
az login --output none

# list all subscriptions
echo "..."
echo "Available susbscription list:"
az account list --output table

# input Subscription id
echo "..."
echo "Enter subscription ID:"
read SUBSCRIPTION_ID

az account set -s $SUBSCRIPTION_ID

# check if required variable are set
if [ -z $KV_NAME ]; then
  echo "please enter name of the KeyVault keeping SP ClientID, ClientSecret and Storage Account Key:"
  read KV_NAME
fi
if [ -z $SERVICE_PRINCIPAL_NAME ]; then
  echo "please enter terraform Service Principal Name"
  read SERVICE_PRINCIPAL_NAME
fi
if [ -z $STORAGE_ACCOUNT_NAME ]; then
  echo "please enter name of the storage account hosting terraform backend"
  read STORAGE_ACCOUNT_NAME
fi

echo "### Setting environment variables for terraform CLI ###"
export ARM_TENANT_ID=$(az account show --query tenantId --output tsv)
export ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
export ARM_CLIENT_ID=$(az keyvault secret show --vault-name $KV_NAME --name $SERVICE_PRINCIPAL_NAME-id --query value --output tsv)
export ARM_CLIENT_SECRET=$(az keyvault secret show --vault-name $KV_NAME --name $SERVICE_PRINCIPAL_NAME-secret --query value --output tsv)
export ARM_ACCESS_KEY=$(az keyvault secret show --vault-name $KV_NAME --name "$STORAGE_ACCOUNT_NAME-key" --query value --output tsv)

if [ -z "$ARM_ACCESS_KEY" ]
then
  echo ""
  echo "#########################################################"
  echo "# Failed to retrieve State access secrets from KeyVault #"
  echo "#########################################################"
  echo ""
else
  echo ""
  echo "###################################"
  echo "# Shell is now terraform ready :) #"
  echo "###################################"
  echo ""
fi