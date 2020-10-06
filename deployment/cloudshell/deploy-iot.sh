#!/usr/bin/env bash

# Stop execution on any error from azure cli
set -e

# Define helper function for logging
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

printf "\n%60s\n" " " | tr ' ' '-'
echo "Checking if the required variables are configured"
printf "%60s\n" " " | tr ' ' '-'

SETUP_VARIABLES_TEMPLATE_FILENAME="variables.template"

if [ ! -f "$SETUP_VARIABLES_TEMPLATE_FILENAME" ]; then
    echo "$(error) \"$SETUP_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\""
    exitWithError
fi

# The following comment is for ignoring the source file check for shellcheck, as it does not support variable source file names currently
# shellcheck source=variables.template
# Read variable values from SETUP_VARIABLES_TEMPLATE_FILENAME file in current directory
source "$SETUP_VARIABLES_TEMPLATE_FILENAME"

# Checking the existence and values of mandatory variables

# Setting default values for variable check stage
ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="true"
ARRAY_VARIABLES_WITHOUT_VALUES=()
ARRAY_NOT_DEFINED_VARIABLES=()

checkValue "RESOURCE_GROUP_IOT" "$RESOURCE_GROUP_IOT"
checkValue "IOTHUB_NAME" "$IOTHUB_NAME"
checkValue "DEVICE_NAME" "$DEVICE_NAME"

checkValue "DETECTOR_MODULE_RUNTIME" "$DETECTOR_MODULE_RUNTIME"
checkValue "EDGE_DEVICE_ARCHITECTURE" "$EDGE_DEVICE_ARCHITECTURE"

if [ -z "$LOCATION" ]; then
    LOCATION="West US 2"    
    # Writing the updated value back to variables file
    sed -i 's#^\(LOCATION[ ]*=\).*#\1\"'"$LOCATION"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$USE_EXISTING_RESOURCES" ]; then
    USE_EXISTING_RESOURCES="false"    
    # Writing the updated value back to variables file
    sed -i 's#^\(USE_EXISTING_RESOURCES[ ]*=\).*#\1\"'"$USE_EXISTING_RESOURCES"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$INSTALL_REQUIRED_PACKAGES" ]; then
    INSTALL_REQUIRED_PACKAGES="true"  
    # Writing the updated value back to variables file
    sed -i 's#^\(INSTALL_REQUIRED_PACKAGES[ ]*=\).*#\1\"'"$INSTALL_REQUIRED_PACKAGES"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"  
fi

# Generating a random suffix that will create a unique resource name based on the resource group name.
RANDOM_SUFFIX="$(echo "$RESOURCE_GROUP_IOT" | md5sum | cut -c1-4)"
RANDOM_NUMBER="${RANDOM:0:3}"

if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
    # Value is empty for STORAGE_ACCOUNT_NAME
    # Assign Default value and appending random suffix to it
    STORAGE_ACCOUNT_NAME="azureeyeadlsstorage"$RANDOM_SUFFIX
    # Writing the updated value back to variables file
    sed -i 's#^\(STORAGE_ACCOUNT_NAME[ ]*=\).*#\1\"'"$STORAGE_ACCOUNT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi


if [ -z "$MANIFEST_TEMPLATE_NAME" ]; then
    # Value is empty for MANIFEST_TEMPLATE_NAME;
    # Assign Default value
    MANIFEST_TEMPLATE_NAME="deployment.camera.template.json"
    # Writing the updated value back to variables file
    sed -i 's#^\(MANIFEST_TEMPLATE_NAME[ ]*=\).*#\1\"'"$MANIFEST_TEMPLATE_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME" ]; then
    # Value is empty for MANIFEST_ENVIRONMENT_VARIABLES_FILENAME;
    # Assign Default value
    MANIFEST_ENVIRONMENT_VARIABLES_FILENAME=".env"
    # Writing the updated value back to variables file
    sed -i 's#^\(MANIFEST_ENVIRONMENT_VARIABLES_FILENAME[ ]*=\).*#\1\"'"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

if [ -z "$DEPLOYMENT_NAME" ]; then
    # Value is empty for DEPLOYMENT_NAME;
    # Assign Default value
    DEPLOYMENT_NAME="eye-deployment"
    # Writing the updated value back to variables file
    sed -i 's#^\(DEPLOYMENT_NAME[ ]*=\).*#\1\"'"$DEPLOYMENT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
fi

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

if [ ! -f "${MANIFEST_ENVIRONMENT_VARIABLES_FILENAME}" ] || [ ! -f "${MANIFEST_TEMPLATE_NAME}" ]; then
    echo "$(error) \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\" and \"$MANIFEST_TEMPLATE_NAME\" files must be present in current directory: \"$PWD\""
    exitWithError
fi

# Check value of INSTALL_REQUIRED_PACKAGES.
# There are different installation steps for Cloud Shell as it does not allow root access to the script
if [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

    INSTALL_IOTEDGEDEV="true"
    if [ ! -z "$(command -v iotedgedev)" ]; then
        currentVersion=$(iotedgedev --version | cut -d ' ' -f3)
        requiredVersion="2.0.2"
        # Sort the current version and required version to get the lowest of the two and then then compare it with required version
        if [ "$(printf '%s\n' "$currentVersion" "$requiredVersion" | sort -V | head -n1)" == "$requiredVersion" ]; then
            # Current installed iotedgedev version is higher than required, no need to re-install
            INSTALL_IOTEDGEDEV="false"
        fi
    fi

    if [ "$INSTALL_IOTEDGEDEV" == "true" ]; then
        echo "$(info) Installing iotedgedev"

        # Install iotedgedev package, we are using 2.0.2 version as 2.1.4 requires pip upgrades in default CloudShell envrionment
        pip install iotedgedev==2.0.2
        # Add iotedgedev path to PATH variable
        echo "PATH=~/.local/bin:$PATH" >>~/.bashrc
        PATH=~/.local/bin:$PATH

        if [ -z "$(command -v iotedgedev)" ]; then
            echo "$(error) iotedgedev is not installed"
            exitWithError
        else
            echo "$(info) Installed iotedgedev"
        fi
    fi

    if [[ $(az extension list --query "[?name=='azure-iot'].name" --output tsv | wc -c) -eq 0 ]]; then
        echo "$(info) Installing azure-iot extension"
        az extension add --name azure-iot
    fi

    # jq and pip packages are pre-installed in the cloud shell
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Logging into Azure"
printf "%60s\n" " " | tr ' ' '-'

echo "Using existing CloudShell login for Azure CLI"

# Set Azure Subscription
printf "\n%60s\n" " " | tr ' ' '-'
echo "Connecting to Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

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

printf "\n%60s\n" " " | tr ' ' '-'
echo "Checking existence of Resource Group and IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# Check for existence of Resource Group for IoT Hub,
# and based on that either throw error or use the existing RG
if [ "$(az group exists --name "$RESOURCE_GROUP_IOT")" == true ]; then
    echo "$(info) Using existing Resource Group: \"$RESOURCE_GROUP_IOT\""
else
    echo "$(error) Resource Group \"$RESOURCE_GROUP_IOT\" does not exist"
    exitWithError
fi

# Check for existence of IoT Hub and Edge device in Resource Group for IoT Hub,
# and based on that either throw error or use the existing resources
if [ -z "$(az iot hub list --query "[?name=='$IOTHUB_NAME'].name" --resource-group "$RESOURCE_GROUP_IOT" -o tsv)" ]; then
    echo "$(error) IoT Hub \"$IOTHUB_NAME\" does not exist."
    exitWithError
else
    echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
fi

if [ -z "$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)" ]; then
    echo "$(error) Device \"$DEVICE_NAME\" does not exist in IoT Hub \"$IOTHUB_NAME\""
    exitWithError
else
    echo "$(info) Using existing Edge Device \"$IOTHUB_NAME\""
fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

DEFAULT_ROUTE_ROUTING_CONDITION="\$twin.moduleId = 'tracker' OR \$twin.moduleId = 'camerastream'"

# Adding default route in IoT hub. This is used to retrieve messages from IoT Hub
# as they are generated.
EXISTING_DEFAULT_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "[?name=='defaultroute'].name" --output tsv)
if [ -z "$EXISTING_DEFAULT_ROUTE" ]; then
    echo "$(info) Creating default IoT Hub route"
    az iot hub route create --name "defaultroute" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP_IOT" --endpoint-name "events" --enabled --condition "$DEFAULT_ROUTE_ROUTING_CONDITION" --output "none"
else
    echo "$(info) Updating existing default IoT Hub route"
    az iot hub route update --name "defaultroute" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP_IOT" --endpoint-name "events" --enabled --condition "$DEFAULT_ROUTE_ROUTING_CONDITION" --output "none"
fi

# Check if the user provided name is valid and available in Azure
NAME_CHECK_JSON=$(az storage account check-name --name "$STORAGE_ACCOUNT_NAME")
IS_NAME_AVAILABLE=$(echo "$NAME_CHECK_JSON" | jq -r '.nameAvailable')

if [ "$IS_NAME_AVAILABLE" == "true" ]; then
    echo "$(info) Creating a storage account \"$STORAGE_ACCOUNT_NAME\""
    az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_IOT" --location "$LOCATION" --sku Standard_RAGRS --kind StorageV2 --enable-hierarchical-namespace true --default-action Allow --output "none"
    echo "$(info) Created storage account \"$STORAGE_ACCOUNT_NAME\""
else
    # Check the unavailability reason. If the user provided name is invalid, throw error with message received from Azure
    UNAVAILABILITY_REASON=$(echo "$NAME_CHECK_JSON" | jq -r '.reason')
    if [ "$UNAVAILABILITY_REASON" == "AccountNameInvalid" ]; then
        echo "$(error) UNAVAILABILITY_REASON: $(echo "$NAME_CHECK_JSON" | jq '.message')"
        exitWithError
    else
        # Check if the Storage Account exists in current resource group. This handles scenario, where a Storage Account exists but not in current resource group.
        # If it exists in current resource group, then we use existing storage account.
        EXISTENCE_IN_RG=$(az storage account list --subscription "$SUBSCRIPTION_ID" --resource-group "$RESOURCE_GROUP_IOT" --query "[?name=='$STORAGE_ACCOUNT_NAME'].{Name:name}" --output tsv)
        if [ "$USE_EXISTING_RESOURCES" == "true" ] && [ ! -z "$EXISTENCE_IN_RG" ]; then
            echo "$(info) Using existing storage account \"$STORAGE_ACCOUNT_NAME\""
        else
            echo "$(info) Storage account \"$STORAGE_ACCOUNT_NAME\" already exists"
            echo "$(info) Appending a random number \"$RANDOM_NUMBER\" to storage account name \"$STORAGE_ACCOUNT_NAME\""
            STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME::${#STORAGE_ACCOUNT_NAME}-4}
            STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME}${RANDOM_NUMBER}
            # Writing the updated value back to variables file
            sed -i 's#^\(STORAGE_ACCOUNT_NAME[ ]*=\).*#\1\"'"$STORAGE_ACCOUNT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
            echo "$(info) Creating storage account \"$STORAGE_ACCOUNT_NAME\""
            az storage account create --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_IOT" --location "$LOCATION" --sku Standard_RAGRS --kind StorageV2 --enable-hierarchical-namespace true --default-action Allow --output "none"
            echo "$(info) Created storage account \"$STORAGE_ACCOUNT_NAME\""
        fi
    fi
fi

# Get storage account key
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_IOT" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" | tr -d '"')

DETECTOR_OUTPUT_CONTAINER_NAME="detectoroutput"
# Check if the storage container exists, use it if it already exists else create a new one
EXISTING_STORAGE_CONTAINER=$(az storage container list --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[?name=='$DETECTOR_OUTPUT_CONTAINER_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_STORAGE_CONTAINER" ]; then
    echo "$(info) Creating storage container \"$DETECTOR_OUTPUT_CONTAINER_NAME\""
    az storage container create --name "$DETECTOR_OUTPUT_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --public-access off --output "none"
    echo "$(info) Created storage container \"$DETECTOR_OUTPUT_CONTAINER_NAME\""
else
    echo "$(info) Using existing container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" in storage account \"$STORAGE_ACCOUNT_NAME\""
fi

IMAGES_CONTAINER_NAME="still-images"
# Check if the storage container exists, use it if it already exists else create a new one
EXISTING_STORAGE_CONTAINER=$(az storage container list --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[?name=='$IMAGES_CONTAINER_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_STORAGE_CONTAINER" ]; then
    echo "$(info) Creating storage container \"$IMAGES_CONTAINER_NAME\""
    az storage container create --name "$IMAGES_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --public-access off --output "none"
    echo "$(info) Created storage container \"$IMAGES_CONTAINER_NAME\""
else
    echo "$(info) Using existing container \"$IMAGES_CONTAINER_NAME\" in storage account \"$STORAGE_ACCOUNT_NAME\""
fi

# Retrieve connection string for storage account
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g "$RESOURCE_GROUP_IOT" -n "$STORAGE_ACCOUNT_NAME" --query connectionString -o tsv)

SAS_EXPIRY_DATE=$(date -u -d "1 year" '+%Y-%m-%dT%H:%MZ')
STORAGE_BLOB_SHARED_ACCESS_SIGNATURE=$(az storage account generate-sas --account-name "$STORAGE_ACCOUNT_NAME" --expiry "$SAS_EXPIRY_DATE" --permissions "rwacl" --resource-types "sco" --services "b" --connection-string "$STORAGE_CONNECTION_STRING" --output tsv)
STORAGE_CONNECTION_STRING_WITH_SAS="BlobEndpoint=https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/;SharedAccessSignature=${STORAGE_BLOB_SHARED_ACCESS_SIGNATURE}"

ADLS_ENDPOINT_NAME="adls-endpoint"

# Check if a azure storage endpoint with given name already exists in IoT Hub. If it doesn't exist create a new one.
# If it exists, check if all the properties are same as provided to current script. If the properties are same, use existing endpoint else create a new one
EXISTING_ENDPOINT=$(az iot hub routing-endpoint list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "*[?name=='$ADLS_ENDPOINT_NAME'].name" --output tsv)
if [ -z "$EXISTING_ENDPOINT" ]; then
    echo "$(info) Creating a custom endpoint $ADLS_ENDPOINT_NAME in IoT Hub for ADLS"
    # Create a custom-endpoint for storage account on IoT Hub
    az iot hub routing-endpoint create --resource-group "$RESOURCE_GROUP_IOT" --hub-name "$IOTHUB_NAME" --endpoint-name "$ADLS_ENDPOINT_NAME" --endpoint-type azurestoragecontainer --endpoint-resource-group "$RESOURCE_GROUP_IOT" --endpoint-subscription-id "$SUBSCRIPTION_ID" --connection-string "$STORAGE_CONNECTION_STRING" --container-name "$DETECTOR_OUTPUT_CONTAINER_NAME" --batch-frequency 60 --chunk-size 100 --encoding json --ff "{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}" --output "none"
else

    # check details of current endpoint
    EXISTING_ENDPOINT=$(az iot hub routing-endpoint list --resource-group "$RESOURCE_GROUP_IOT" --hub-name "$IOTHUB_NAME" --query "storageContainers[?name=='$ADLS_ENDPOINT_NAME']" --output json)

    IS_NEW_ENDPOINT_SAME_AS_EXISTING="false"
    if [ ! -z "$EXISTING_ENDPOINT" ]; then
        EXISTING_SA_RG=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].resourceGroup')
        EXISTING_SA_SUBSCRIPTION=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].subscriptionId')
        # Retrieve storage account from connection string using cut
        EXISTING_SA_NAME=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].connectionString' | cut -d';' -f 3 | cut -d'=' -f 2)
        EXISTING_SA_CONTAINER=$(echo "$EXISTING_ENDPOINT" | jq -r '.[0].containerName')

        if [ "$EXISTING_SA_RG" == "$RESOURCE_GROUP_IOT" ] && [ "$EXISTING_SA_SUBSCRIPTION" == "$SUBSCRIPTION_ID" ] && [ "$EXISTING_SA_NAME" == "$STORAGE_ACCOUNT_NAME" ] && [ "$EXISTING_SA_CONTAINER" == "$DETECTOR_OUTPUT_CONTAINER_NAME" ]; then
            IS_NEW_ENDPOINT_SAME_AS_EXISTING="true"
        fi
    fi
    if [ "$IS_NEW_ENDPOINT_SAME_AS_EXISTING" == "true" ]; then
        echo "$(info) Using existing endpoint \"$ADLS_ENDPOINT_NAME\""
    else
        echo "$(info) Custom endpoint \"$ADLS_ENDPOINT_NAME\" already exists in IoT Hub \"$IOTHUB_NAME\". It's configuration is different from the values provided to this script."
        echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to custom endpoint name \"$ADLS_ENDPOINT_NAME\""
        ADLS_ENDPOINT_NAME=${ADLS_ENDPOINT_NAME}${RANDOM_SUFFIX}

        # Writing the updated value back to variables file
        sed -i 's#^\(ADLS_ENDPOINT_NAME[ ]*=\).*#\1\"'"$ADLS_ENDPOINT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
        echo "$(info) Creating a custom endpoint \"$ADLS_ENDPOINT_NAME\" in IoT Hub for ADLS"
        # Create a custom-endpoint for storage account on IoT Hub
        az iot hub routing-endpoint create --resource-group "$RESOURCE_GROUP_IOT" --hub-name "$IOTHUB_NAME" --endpoint-name "$ADLS_ENDPOINT_NAME" --endpoint-type azurestoragecontainer --endpoint-resource-group "$RESOURCE_GROUP_IOT" --endpoint-subscription-id "$SUBSCRIPTION_ID" --connection-string "$STORAGE_CONNECTION_STRING" --container-name "$DETECTOR_OUTPUT_CONTAINER_NAME" --batch-frequency 60 --chunk-size 100 --encoding json --ff "{iothub}/{partition}/{YYYY}/{MM}/{DD}/{HH}/{mm}" --output "none"
        echo "$(info) Created custom endpoint \"$ADLS_ENDPOINT_NAME\""
    fi
fi

IOTHUB_ADLS_ROUTENAME="adls-route"
ADLS_ROUTING_CONDITION="\$twin.moduleId = 'camerastream'"

# Check if a route exists with given name, update it if it already exists else create a new one
# Adding route to send messages to ADLS. This step creates an Azure Data Lake Storage account,
# and creates routing endpoints and routes in Iot Hub. Messages will spill into a data lake
# every one minute.
EXISTING_IOTHUB_ADLS_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --query "[?name=='$IOTHUB_ADLS_ROUTENAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_IOTHUB_ADLS_ROUTE" ]; then

    echo "$(info) Creating a route in IoT Hub for ADLS custom endpoint"
    # Create a route for storage endpoint on IoT Hub
    az iot hub route create --name "$IOTHUB_ADLS_ROUTENAME" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP_IOT" --endpoint-name "$ADLS_ENDPOINT_NAME" --enabled --condition "$ADLS_ROUTING_CONDITION" --output "none"
    echo "$(info) Created route \"$IOTHUB_ADLS_ROUTENAME\" in IoT Hub \"$IOTHUB_NAME\""
else

    echo "$(info) Updating existing route \"$IOTHUB_ADLS_ROUTENAME\""
    az iot hub route update --name "$IOTHUB_ADLS_ROUTENAME" --hub-name "$IOTHUB_NAME" --source devicemessages --resource-group "$RESOURCE_GROUP_IOT" --endpoint-name "$ADLS_ENDPOINT_NAME" --enabled --condition "$ADLS_ROUTING_CONDITION" --output "none"
    echo "$(info) Updated existing route \"$IOTHUB_ADLS_ROUTENAME\""
fi

# if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
#     echo "$(info) Retrieve resource id for IoT Hub"
#     IOTHUB_RESOURCE_ID=$(az iot hub list --query "[?name=='$IOTHUB_NAME'].{resourceID:id}" --output tsv)

#     echo "$(info) Creating an Azure Monitor"
#     AZ_MONITOR_SP=$(az ad sp create-for-rbac --role="Monitoring Metrics Publisher" --name "$AZURE_MONITOR_SP_NAME" --scopes="$IOTHUB_RESOURCE_ID")
#     TELEGRAF_AZURE_TENANT_ID=$TENANT_ID
#     TELEGRAF_AZURE_CLIENT_ID=$(echo "$AZ_MONITOR_SP" | jq -r '.appId')
#     TELEGRAF_AZURE_CLIENT_SECRET=$(echo "$AZ_MONITOR_SP" | jq -r '.password')
#     echo "$(info) Azure Monitor creation is complete"
# fi

# This step uses the iotedgedev cli toolkit to inject defined environment variables into a predefined deployment manifest JSON
# file. Once an environment specific manifest has been generated, the script will deploy to the identified edge device.

# Create or replace .env file for generating manifest file and copy content from environment file from user to .env file
# We are copying the content to .env file as it's required by iotedgedev service

# if [ "$CREATE_AZURE_MONITOR" == "true" ]; then
#     echo "$(info) Updating Azure Monitor variables in \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\""
#     # Update Azure Monitor Values in env.template file
#     sed -i "s/^\(TELEGRF_AZURE_TENANT_ID\s*=\s*\).*\$/\1$TELEGRAF_AZURE_TENANT_ID/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
#     sed -i "s/^\(TELEGRF_AZURE_CLIENT_ID\s*=\s*\).*\$/\1$TELEGRAF_AZURE_CLIENT_ID/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
#     sed -i "s/^\(TELEGRF_AZURE_CLIENT_SECRET\s*=\s*\).*\$/\1$TELEGRAF_AZURE_CLIENT_SECRET/" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
#     echo "$(info) Completed Update of Azure Monitor variables in \"$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME\""
# fi


if [ "$DETECTOR_MODULE_RUNTIME" == "CPU" ]; then
    MODULE_RUNTIME="runc"
elif [ "$DETECTOR_MODULE_RUNTIME" == "NVIDIA" ]; then
    MODULE_RUNTIME="nvidia"
elif [ "$DETECTOR_MODULE_RUNTIME" == "MOVIDIUS" ]; then
    MODULE_RUNTIME="movidius"
fi

# Update the value of RUNTIME variable in environment variable file
sed -i 's#^\(RUNTIME[ ]*=\).*#\1\"'"$MODULE_RUNTIME"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
# Update the value of CAMERA_BLOB_SAS in the environment variable file with the SAS token for the images container
sed -i "s|\(^CAMERA_BLOB_SAS=\).*|CAMERA_BLOB_SAS=\"${STORAGE_CONNECTION_STRING_WITH_SAS//\&/\\\&}\"|g" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"

# This step updates the video stream if specified in the variables.template file. This
# is intended to let the user provide their own video stream instead of using the sample video provided as part of this repo.
if [ -z "$CUSTOM_VIDEO_SOURCE" ]; then
    echo "$(info) Using default sample video to edge device"
else
    echo "$(info) Using custom video for edge deployment"

    if [[ "$CUSTOM_VIDEO_SOURCE" == rtsp://* ]]; then
        echo "$(info) RTSP URL: $CUSTOM_VIDEO_SOURCE"
        sed -i 's#^\(CROSSING_VIDEO_URL[ ]*=\).*#\1\"'"$CUSTOM_VIDEO_SOURCE"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"
    else
        echo "$(error) Custom video source was not of format \"rtsp://path/to/video\". Please provide a valid RTSP URL"
        exitWithError
    fi
fi

if [ "$EDGE_DEVICE_ARCHITECTURE" == "X86" ]; then
    PLATFORM_ARCHITECTURE="amd64"
elif [ "$EDGE_DEVICE_ARCHITECTURE" == "ARM64" ]; then
    PLATFORM_ARCHITECTURE="arm64v8"
fi

echo "$(info) Generating manifest file from template file"
# Generate manifest file
iotedgedev genconfig --file "$MANIFEST_TEMPLATE_NAME" --platform "$PLATFORM_ARCHITECTURE"

echo "$(info) Generated manifest file"

#Construct file path of the manifest file by getting file name of template file and replace 'template.' with '' if it has .json extension
#iotedgedev service used deployment.json filename if the provided file does not have .json extension
#We are prefixing ./config to the filename as iotedgedev service creates a config folder and adds the manifest file in that folder

# if .json then remove template. if present else deployment.json
if [[ "$MANIFEST_TEMPLATE_NAME" == *".json"* ]]; then
    # Check if the file name is like name.template.json, if it is construct new name as name.json
    # Remove last part (.json) from file name
    TEMPLATE_FILE_NAME="${MANIFEST_TEMPLATE_NAME%.*}"
    # Get the last part form file name and check if it is template
    IS_TEMPLATE="${TEMPLATE_FILE_NAME##*.}"
    if [ "$IS_TEMPLATE" == "template" ]; then
        # Get everything but the last part (.template) and append .json to construct new name
        TEMPLATE_FILE_NAME="${TEMPLATE_FILE_NAME%.*}.json"
        PRE_GENERATED_MANIFEST_FILENAME="./config/$(basename "$TEMPLATE_FILE_NAME")"
    else
        PRE_GENERATED_MANIFEST_FILENAME="./config/$(basename "$MANIFEST_TEMPLATE_NAME")"
    fi
else
    PRE_GENERATED_MANIFEST_FILENAME="./config/deployment.json"
fi

if [ ! -f "$PRE_GENERATED_MANIFEST_FILENAME" ]; then
    echo "$(error) Manifest file \"$PRE_GENERATED_MANIFEST_FILENAME\" does not exist. Please check config folder under current directory: \"$PWD\" to see if manifest file is generated or not"
fi

# This step deploys the configured deployment manifest to the edge device. After completed,
# the device will begin to pull edge modules and begin executing workloads (including sending
# messages to the cloud for further processing, visualization, etc).
# Check if a deployment with given name, already exists in IoT Hub. If it doesn't exist create a new one.
# If it exists, append a random number to user given deployment name and create a deployment.

EXISTING_DEPLOYMENT_NAME=$(az iot edge deployment list --hub-name "$IOTHUB_NAME" --query "[?id=='$DEPLOYMENT_NAME'].{Id:id}" --output tsv)
if [ -z "$EXISTING_DEPLOYMENT_NAME" ]; then
    echo "$(info) Deploying \"$PRE_GENERATED_MANIFEST_FILENAME\" manifest file to \"$DEVICE_NAME\" Edge device"
    az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'" --output "none"
else
    echo "$(info) Deployment \"$DEPLOYMENT_NAME\" already exists in IoT Hub \"$IOTHUB_NAME\""
    echo "$(info) Appending a random number \"$RANDOM_NUMBER\" to Deployment name \"$DEPLOYMENT_NAME\""
    DEPLOYMENT_NAME=${DEPLOYMENT_NAME}${RANDOM_NUMBER}
    # Writing the updated value back to variables file
    sed -i 's#^\(DEPLOYMENT_NAME[ ]*=\).*#\1\"'"$DEPLOYMENT_NAME"'\"#g' "$SETUP_VARIABLES_TEMPLATE_FILENAME"
    echo "$(info) Deploying \"$PRE_GENERATED_MANIFEST_FILENAME\" manifest file to \"$DEVICE_NAME\" Edge device"
    az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'" --output "none"
fi
echo "$(info) Deployed manifest file to IoT Hub. Your modules are being deployed to your device now. This may take some time."
