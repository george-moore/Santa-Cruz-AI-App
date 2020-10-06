#!/usr/bin/env bash

# This script creates a Azure VM using a managed disk.
# It performs the following steps:
#	1. Login to Azure
#	2. Create an empty managed disk in ForUpload state
#	3. Generate a SAS Token for the managed disk
#	4. Copy the vhd blob file from a storage container to managed disk using AzCopy
#	5. Remove the SAS Token. This will changed the state from ForUpload to Unattached
#   6. Create a VM from managed disk.

# Stop execution on any error from azure cli
set -e

# Helper function
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}

# Define helper function for logging. This will change the Error text color to red
error() {
    echo "$(tput setaf 1)$(date +"%Y-%m-%d %T") [ERROR]"
}

exitWithError() {
    # Reset console color
    tput sgr0
    exit 1
}

##############################################################################
# Check existence and value of a variable
# The function checks if the provided variable exists and it is a non-empty value.
# If it doesn't exists it adds the variable name to ARRAY_NOT_DEFINED_VARIABLES array and if it exists but doesn't have value, variable name is added ARRAY_VARIABLES_WITHOUT_VALUES array.
# Globals:
#	ARRAY_VARIABLES_WITHOUT_VALUES
#	ARRAY_NOT_DEFINED_VARIABLES
#	ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY
# Arguments:
#	Name of the variable
#	Value of the variable
# Outputs:
#	No output
##############################################################################
checkValue() {
    # The first value passed to the function is the name of the variable
    # Check it's existence in file using -v
    if [ -v "$1" ]; then
        # The second value passed to the function is the actual value of the variable
        # Check if it is empty using -z
        if [ -z "$2" ]; then
            # If the value is empty, add the variable name ($1) to ARRAY_VARIABLES_WITHOUT_VALUES array and set ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY to false
            ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="false"
            ARRAY_VARIABLES_WITHOUT_VALUES+=("$1")
        fi
    else
        # If the variable is not defined, add the variable name to ARRAY_NOT_DEFINED_VARIABLES array and set ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY to false
        ARRAY_NOT_DEFINED_VARIABLES+=("$1")
        ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="false"
    fi
}

SETUP_VARIABLES_TEMPLATE_FILENAME="variables.template"

if [ ! -f "$SETUP_VARIABLES_TEMPLATE_FILENAME" ]; then
    echo "$(error) \"$SETUP_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\""
    exitWithError
fi

# The following comment is required for shellcheck, as it does not support variable source file names.
# shellcheck source=variables.template
# Read variable values from SETUP_VARIABLES_TEMPLATE_FILENAME file in current directory
source "$SETUP_VARIABLES_TEMPLATE_FILENAME"


if [ -z "$INSTALL_REQUIRED_PACKAGES" ]; then
    INSTALL_REQUIRED_PACKAGES="true"  
    # Writing the updated value back to variables file
    sed -i 's#^\(INSTALL_REQUIRED_PACKAGES[ ]*=\).*#\1\"'"$INSTALL_REQUIRED_PACKAGES"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"  
fi

# There are different installation steps for Cloud Shell as it does not allow root access to the script
# In Azure Cloud Shell, azcopy and jq are pre-installed so only install sshpass and azure-iot extension
if [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

    if [ -z "$(command -v sshpass)" ]; then

        echo "$(info) Installing sshpass"
        # Download the sshpass package to current machine
        apt-get download sshpass
        # Install sshpass package in current working directory
        dpkg -x sshpass*.deb ~
        # Add the executable directory path in PATH
        echo "PATH=~/usr/bin:$PATH" >>~/.bashrc
        PATH=~/usr/bin:$PATH
        # Remove the package file
        rm sshpass*.deb

        if [ -z "$(command -v sshpass)" ]; then
            echo "$(error) sshpass is not installed"
            exitWithError
        else
            echo "$(info) Installed sshpass"
        fi

    fi

    if [[ $(az extension list --query "[?name=='azure-iot'].name" --output tsv | wc -c) -eq 0 ]]; then
        echo "$(info) Installing azure-iot extension"
        az extension add --name azure-iot
    fi

    # azcopy, jq and timeout are pre-installed on cloud shell.
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Checking if the required variables are configured"
printf "%60s\n" " " | tr ' ' '-'

# Setting default values for variable check stage
ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="true"
ARRAY_VARIABLES_WITHOUT_VALUES=()
ARRAY_NOT_DEFINED_VARIABLES=()

# Checking the existence and values of mandatory variables

# Pass the name of the variable and it's value to the checkValue function
checkValue "RESOURCE_GROUP_DEVICE" "$RESOURCE_GROUP_DEVICE"
checkValue "RESOURCE_GROUP_IOT" "$RESOURCE_GROUP_IOT"

if [ -z "$USE_EXISTING_RESOURCES" ]; then
    USE_EXISTING_RESOURCES="false"    
    # Writing the updated value back to variables file
    sed -i 's#^\(USE_EXISTING_RESOURCES[ ]*=\).*#\1\"'"$USE_EXISTING_RESOURCES"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

# Generating a random suffix that will create a unique resource name based on the resource group name.
RANDOM_SUFFIX="$(echo "$RESOURCE_GROUP_IOT" | md5sum | cut -c1-4)"
RANDOM_NUMBER="${RANDOM:0:3}"

if [ -z "$LOCATION" ]; then
    # Value is empty for LOCATION
    # Assign Default value
    LOCATION="WEST US 2"
    # Writing the updated value back to variables file
    sed -i 's#^\(LOCATION[ ]*=\).*#\1\"'"$LOCATION"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$IOTHUB_NAME" ]; then
    # Value is empty for IOTHUB_NAME
    # Assign Default value and appending random suffix to it
    IOTHUB_NAME="azureeyeiothub"${RANDOM_SUFFIX}
    # Writing the updated value back to variables file
    sed -i 's#^\(IOTHUB_NAME[ ]*=\).*#\1\"'"$IOTHUB_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$DEVICE_NAME" ]; then
    # Value is empty for DEVICE_NAME
    # Assign Default value and appending random suffix to it
    DEVICE_NAME="azureeye"${RANDOM_SUFFIX}
    # Writing the updated value back to variables file
    sed -i 's#^\(DEVICE_NAME[ ]*=\).*#\1\"'"$DEVICE_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$DISK_NAME" ]; then
    # Value is empty for DISK_NAME;
    # Assign Default value
    DISK_NAME="mariner"
    # Writing the updated value back to variables file
    sed -i 's#^\(DISK_NAME[ ]*=\).*#\1\"'"$DISK_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$STORAGE_TYPE" ]; then
    # Value is empty for STORAGE_TYPE;
    # Assign Default value
    STORAGE_TYPE="Premium_LRS"
    # Writing the updated value back to variables file
    sed -i 's#^\(STORAGE_TYPE[ ]*=\).*#\1\"'"$STORAGE_TYPE"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$VM_NAME" ]; then
    # Value is empty for VM_NAME;
    # Assign Default value
    VM_NAME="marinervm"
    # Writing the updated value back to variables file
    sed -i 's#^\(VM_NAME[ ]*=\).*#\1\"'"$VM_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$VM_SIZE" ]; then
    # Value is empty for VM_SIZE;
    # Assign Default value
    VM_SIZE="Standard_DS2_v2"
    # Writing the updated value back to variables file
    sed -i 's#^\(VM_SIZE[ ]*=\).*#\1\"'"$VM_SIZE"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

# Generate NSG name by appending -nsg to VM name
NSG_NAME="${VM_NAME}-nsg"

# Check if all the variables are set up correctly
if [ "$ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY" == "false" ]; then
    # Check if there are any required variables which are not defined
    if [ "${#ARRAY_NOT_DEFINED_VARIABLES[@]}" -gt 0 ]; then
        echo "$(error) The following variables must be defined in the variables file"
        printf '%s\n' "${ARRAY_NOT_DEFINED_VARIABLES[@]}"
    fi
    # Check if there are any required variables which are empty
    if [ "${#ARRAY_VARIABLES_WITHOUT_VALUES[@]}" -gt 0 ]; then
        echo "$(error) The following variables must have a value in the variables file"
        printf '%s\n' "${ARRAY_VARIABLES_WITHOUT_VALUES[@]}"
    fi
    exitWithError
fi

echo "$(info) The required variables are defined and have a non-empty value"

# VHD_URI is the direct link for VHD file in storage account. The VHD file must be in the current subscription
VHD_URI="https://unifiededgescenarios.blob.core.windows.net/aedvhd/aedvhd-dev-1.0.MM5.20200603.2120.v0.0.5.vhd?sp=r&st=2020-09-01T09:47:08Z&se=2022-09-01T17:47:08Z&spr=https&sv=2019-12-12&sr=b&sig=jEum6oD8O5fESu%2BxO60VUijjGsMHkzo%2BZcvOl6L9ZnM%3D"
# Whether to create a rule in NSG for SSH or RDP.
# The following are the allowed values:
# 	NONE: Do not create any inbound security rule in NSG for RDP or SSH ports. (Recommended)
# 	SSH: Create an inbound security rule in NSG with priority 1000 for SSH port (22)
#	RDP: Create an inbound security rule in NSG with priority 1000 for RDP port (3389)
NSG_RULE="NONE"

echo "Using existing CloudShell login for Azure CLI"

# Getting the details of subscriptions which user has access, in case when value is not provided in variable.template
if [ -z "$SUBSCRIPTION_ID" ]; then
    # Value is empty for SUBSCRIPTION_ID
    # Assign Default value to current subscription
    subscriptions=$(az account list)
    
    SUBSCRIPTION_ID=$(az account list --query "[0].id" -o tsv)
    
    if [ ${#subscriptions[*]} -gt 1 ]; then
        echo "[WARNING] User has access to more than one subscription, by default using first subscription: \"$SUBSCRIPTION_ID\""
    fi

    # Writing the updated value back to variables file
    sed -i 's#^\(SUBSCRIPTION_ID[ ]*=\).*#\1\"'"$SUBSCRIPTION_ID"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

echo "$(info) Setting current subscription to \"$SUBSCRIPTION_ID\""
az account set --subscription "$SUBSCRIPTION_ID"
echo "$(info) Successfully set subscription to \"$SUBSCRIPTION_ID\""

# Create a new resource group for VM if it does not exist already.
# If it already exists then check value for USE_EXISTING_RESOURCES
# and based on that either throw error or use the existing RG
if [ "$(az group exists --name "$RESOURCE_GROUP_DEVICE")" == false ]; then
    echo "$(info) Creating a new Resource Group: \"$RESOURCE_GROUP_DEVICE\""
    az group create --name "$RESOURCE_GROUP_DEVICE" --location "$LOCATION" --output "none"
    echo "$(info) Successfully created resource group"
else
    if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
        echo "$(info) Using Existing Resource Group: \"$RESOURCE_GROUP_DEVICE\" for VM"
    else
        echo "$(error) Resource Group \"$RESOURCE_GROUP_DEVICE\" already exists"
        exitWithError
    fi
fi

# Check if the RESOURCE_GROUP_DEVICE name is same as RESOURCE_GROUP_IOT
# If it is same then use the existing resource group.
# Create a new resource group for other resources if it does not exist already.
# If it already exists then check value for USE_EXISTING_RESOURCES
# and based on that either throw error or use the existing RG
if [ "$RESOURCE_GROUP_DEVICE" == "$RESOURCE_GROUP_IOT" ]; then
    echo "$(info) Using Existing Resource Group: \"$RESOURCE_GROUP_IOT\" for IoT Hub"
else    
    if [ "$(az group exists --name "$RESOURCE_GROUP_IOT")" == false ]; then
        echo "$(info) Creating a new Resource Group: \"$RESOURCE_GROUP_IOT\""
        az group create --name "$RESOURCE_GROUP_IOT" --location "$LOCATION" --output "none"
        echo "$(info) Successfully created resource group \"$RESOURCE_GROUP_IOT\""
    else
        if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
            echo "$(info) Using Existing Resource Group: \"$RESOURCE_GROUP_IOT\" for IoT Hub"
        else
            echo "$(error) Resource Group \"$RESOURCE_GROUP_IOT\" already exists"
            exitWithError
        fi
    fi
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Managed disk \"$DISK_NAME\" setup"
printf "%60s\n" " " | tr ' ' '-'

# Check if disk already exists
EXISTING_DISK=$(az disk list --resource-group "$RESOURCE_GROUP_DEVICE" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$DISK_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_DISK" ]; then
    echo "$(info) Creating empty managed disk \"$DISK_NAME\""
    # The upload size bytes must be same as size of the VHD file
    az disk create -n "$DISK_NAME" -g "$RESOURCE_GROUP_DEVICE" -l "$LOCATION" --for-upload --upload-size-bytes 68719477248 --sku "$STORAGE_TYPE" --os-type "Linux" --hyper-v-generation "V2" --output "none"
    echo "$(info) Created empty managed disk \"$DISK_NAME\""
else
    echo "$(info) Managed Disk \"$DISK_NAME\" already exists in resource group \"$RESOURCE_GROUP_DEVICE\""
fi


# This section check the current disk state, if it is in ReadyToUpload state then grants access to the empty disk we created in the prior step through a temporary SAS token. We
# will use this token to allow azcopy to copy the private Mariner OS vhd file to another subscription. After the copy
# operation has completed, we revoke access to the disk in our environment to conclude the disk setup operation.
CURRENT_STATE=$(az disk list  --query "[?name=='$DISK_NAME'].diskState" --resource-group "$RESOURCE_GROUP_DEVICE" -o tsv)\

if [ "$CURRENT_STATE" == "Attached"  ]; then
    echo "$(info) Using existing Managed Disk \"$DISK_NAME\""
else
    echo "$(info) Fetching the SAS Token for temporary access to managed disk"
    SAS_URI=$(az disk grant-access -n "$DISK_NAME" -g "$RESOURCE_GROUP_DEVICE" --access-level Write --duration-in-seconds 86400)
    TOKEN=$(echo "$SAS_URI" | jq -r '.accessSas')
    echo "$(info) Retrieved the SAS Token"

    echo "$(info) Copying vhd file from source to destination"

    azcopy copy "$VHD_URI" "$TOKEN" --blob-type PageBlob
    echo "$(info) Copy is complete"

    echo "$(info) Revoking SAS token access for the managed disk"
    az disk revoke-access -n "$DISK_NAME" -g "$RESOURCE_GROUP_DEVICE" --output "none"
    echo "$(info) SAS REVOKED"

fi

echo "$(info) Managed disk setup is complete"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Virtual machine \"$VM_NAME\" setup"
printf "%60s\n" " " | tr ' ' '-'

# We check whether the Virtual machine with the provided name exists or not in the current resource group.
# If it doesn't exists, we will create a new virtual machine.
# If it exists, we check the os disk name. If it is same as the disk name provided, we use the existing virtual machine.
EXISTING_VM=$(az vm list --resource-group "$RESOURCE_GROUP_DEVICE" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$VM_NAME'].{Name:name}" --output tsv)


if [ -z "$EXISTING_VM" ]; then
    echo "$(info) Creating virtual machine \"$VM_NAME\""
    az vm create --name "$VM_NAME" --resource-group "$RESOURCE_GROUP_DEVICE" --attach-os-disk "$DISK_NAME" --os-type "linux" --location "$LOCATION" --nsg-rule "$NSG_RULE" --nsg "$NSG_NAME" --size "$VM_SIZE" --output "none"
    echo "$(info) Created virtual machine \"$VM_NAME\""
else
    OS_DISK_NAME=$(az vm list --query "[?name=='$VM_NAME'].storageProfile.osDisk.name" --resource-group "$RESOURCE_GROUP_DEVICE" -o tsv)
    if [ "$OS_DISK_NAME" == "$DISK_NAME" ]; then
        echo "$(info) Virtual machine \"$VM_NAME\" already exists in resource group \"$RESOURCE_GROUP_DEVICE\""
    else
        echo "$(info) Virtual machine \"$VM_NAME\" already exists in resource group \"$RESOURCE_GROUP_DEVICE\" but does not have the attached disk as \"$DISK_NAME\""
        exitWithError
    fi    
fi

CURRENT_IP_ADDRESS=$(curl -s https://ip4.seeip.org/)

echo "$(info) Adding current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"

# Create a NSG Rule to allow SSH for current machine
az network nsg rule create --name "AllowSSH" --nsg-name "$NSG_NAME" --priority 100 --resource-group "$RESOURCE_GROUP_DEVICE" --destination-port-ranges 22 --source-address-prefixes "$CURRENT_IP_ADDRESS" --output "none"

echo "$(info) Added current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"

# Writing the Edge Device IP address value to variables file
EDGE_DEVICE_PUBLIC_IP=$(az vm show --show-details --resource-group "$RESOURCE_GROUP_DEVICE" --name "$VM_NAME" --query "publicIps" --output tsv)
#sed -i 's#^\(EDGE_DEVICE_IP[ ]*=\).*#\1\"'"$EDGE_DEVICE_PUBLIC_IP"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"

EDGE_DEVICE_USERNAME="root"
EDGE_DEVICE_PASSWORD="p@ssw0rd"

echo "The following are the details for the VM"
echo "IP Address: \"$EDGE_DEVICE_PUBLIC_IP\""
echo "Username: \"$EDGE_DEVICE_USERNAME\""
echo "Password: \"$EDGE_DEVICE_PASSWORD\""


printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# We are checking if the IoTHub already exists by querying the list of IoT Hubs in current subscription.
# It will return a blank array if it does not exist. Create a new IoT Hub if it does not exist,
# if it already exists then check value for USE_EXISTING_RESOURCES. If it is set to yes, use existing IoT Hub.
EXISTING_IOTHUB=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)

if [ -z "$EXISTING_IOTHUB" ]; then
    echo "$(info) Creating a new IoT Hub \"$IOTHUB_NAME\""
    az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP_IOT" --output "none"
    echo "$(info) Created a new IoT hub \"$IOTHUB_NAME\""
else
    # Check if IoT Hub exists in current resource group. If it exist, we will use the existing IoT Hub.
    EXISTING_IOTHUB=$(az iot hub list --resource-group "$RESOURCE_GROUP_IOT" --query "[?name=='$IOTHUB_NAME'].{Name:name}" --output tsv)
    if [ "$USE_EXISTING_RESOURCES" == "true" ] && [ -n "$EXISTING_IOTHUB" ]; then
        echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
    else
        if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
            echo "$(info) \"$IOTHUB_NAME\" already exists in current subscription but it does not exist in resource group \"$RESOURCE_GROUP_IOT\""
        else
            echo "$(info) \"$IOTHUB_NAME\" already exists"
        fi
        echo "$(info) Appending a random number \"$RANDOM_NUMBER\" to \"$IOTHUB_NAME\""
        IOTHUB_NAME=${IOTHUB_NAME}${RANDOM_NUMBER}
        # Writing the updated value back to variables file
        sed -i 's#^\(IOTHUB_NAME[ ]*=\).*#\1\"'"$IOTHUB_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"

        echo "$(info) Creating a new IoT Hub \"$IOTHUB_NAME\""
        az iot hub create --name "$IOTHUB_NAME" --sku S1 --resource-group "$RESOURCE_GROUP_IOT" --output "none"
        echo "$(info) Created a new IoT hub \"$IOTHUB_NAME\""
    fi
fi

# This step creates a new edge device in the IoT Hub account or will use an existing edge device
# if the USE_EXISTING_RESOURCES configuration variable is set to true.
printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring Edge Device in IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# Check if a Edge Device with given name already exists in IoT Hub. Create a new one if it doesn't exist already.
EXISTING_IOTHUB_DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)
if [ -z "$EXISTING_IOTHUB_DEVICE" ]; then
    echo "$(info) Creating an Edge device \"$DEVICE_NAME\" in IoT Hub \"$IOTHUB_NAME\""
    az iot hub device-identity create --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME" --edge-enabled --output "none"
    echo "$(info) Created \"$DEVICE_NAME\" device in IoT Hub \"$IOTHUB_NAME\""
else
    echo "$(info) Using existing IoT Hub Edge Device \"$DEVICE_NAME\""
fi

# The following steps retrieves the connection string for the edge device an uses it to onboard
# the device using sshpass. This step may fail if the edge device's network firewall
# does not allow ssh access. Please make sure the edge device is on the local area
# network and is accepting ssh requests.
echo "$(info) Retrieving connection string for device \"$DEVICE_NAME\" from Iot Hub \"$IOTHUB_NAME\" and updating the IoT Edge service in edge device with this connection string"
EDGE_DEVICE_CONNECTION_STRING=$(az iot hub device-identity connection-string show --device-id "$DEVICE_NAME" --hub-name "$IOTHUB_NAME" --query "connectionString" -o tsv)

echo "$(info) Updating Config.yaml on edge device with the connection string from IoT Hub"
CONFIG_FILE_PATH="/etc/iotedge/config.yaml"
# Replace placeholder connection string with actual value for Edge device
# Using sshpass and ssh to update the value on Edge device
Command="sudo sed -i -e '/device_connection_string:/ s#\"[^\"][^\"]*\"#\"$EDGE_DEVICE_CONNECTION_STRING\"#' $CONFIG_FILE_PATH"
sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_PUBLIC_IP" -o StrictHostKeyChecking=no "$Command"
echo "$(info) Config.yaml update is complete"

echo "$(info) Restarting IoT Edge service"
# Restart the service on Edge device
sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_PUBLIC_IP" -o StrictHostKeyChecking=no "sudo systemctl restart iotedge"
echo "$(info) IoT Edge service restart is complete"