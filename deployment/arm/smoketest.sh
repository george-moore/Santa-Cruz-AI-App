#!/bin/bash

#List of checks done by script:
#1.  IoT Edge Service is running or not on Edge machine.
#2.  Resource Group for IoT Hub is present or not.
#3.  IoT Hub is present or not in Resource Group for IoT.
#4.  IoT Hub Device is present or not.
#5.  Default Route for built-in Event Hub endpoint is present or not in IoT Hub.
#6.  Storage account is present or not in the Resource Group for IoT.
#7.  Containers are present or not in Storage account.
#8.  Custom Data Lake Storage endpoint is present or not in IoT Hub.
#9.  Route to a Data Lake Storage account is present or not in IoT Hub.
#10. Data files are present or not in both 'detectoroutput' & still-images storage account containers.
#11. Deployment of manifest file is successfully applied to the edge device or not.
#12. Validating the runtimeStatus of each configured module on Edge device.
#13. App Service plan is present or not in Resource Group for IoT.
#14. Web App is present or not in Resource Group for IoT.
#15. Resource Group for VM is present or not.
#16. Mariner Disk is present or not in Resource Group for VM.
#17. Mariner VM is present or not in Resource Group for VM.


# Stop execution on any error in script execution
set -e

ANY_FAILURES_OCCURRED="false"


#-----------------------------------------------------------------------------------------
# Define helper function for logging. This will change the Error text color to red
printError() {
  echo "$(tput setaf 1)$1$(tput sgr0)"
  ANY_FAILURES_OCCURRED="true"
}

# To check whether the resource name contains prefix
match() {
if [[ "$1" =~ .*"$2".* ]]; then
  echo "1"
fi
}

# To find which resources have the prefix
search() {
local_variable="${1}"
shift
local_array=("${@}")
for name in "${local_array[@]}"
do
  flag=$(match "$name" "$local_variable")
  if [ "$flag" == 1 ]; then
     result="$name"
  fi
done
echo "$result"
}

#-----------------------------------------------------------------------------------------
USE_INTERACTIVE_LOGIN_FOR_AZURE="false"
INSTALL_REQUIRED_PACKAGES="true"


if [ -z "$USE_INTERACTIVE_LOGIN_FOR_AZURE" ]; then
  USE_INTERACTIVE_LOGIN_FOR_AZURE="true"
fi

if [ -z "$INSTALL_REQUIRED_PACKAGES" ]; then
  INSTALL_REQUIRED_PACKAGES="true" 
fi

# Set the variable value to decide, Whether to perform test for frontend app setup or not, Default is true.
RUN_WEBAPP_CHECKS="true"
# Set the variable value to decide, Whether to perform test for Mariner VM setup or not, Default is true.
RUN_VM_CHECKS="true"

IS_CURRENT_ENVIRONMENT_CLOUDSHELL="false"
if [ "$POWERSHELL_DISTRIBUTION_CHANNEL" == "CloudShell" ]; then
  IS_CURRENT_ENVIRONMENT_CLOUDSHELL="true"
fi



while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --rg-iot)
            RESOURCE_GROUP_IOT="$2"
            shift # past argument
            shift # past value
            ;;
        --rg-vm)
            RESOURCE_GROUP_DEVICE="$2"
            shift # past argument
            shift # past value
            ;;
        --iothub-name)
            IOTHUB_NAME="$2"
            shift # past argument
            shift # past value
            ;; 
        --device-name)
            DEVICE_NAME="$2"
            shift # past argument
            shift # past value
            ;;      
    esac
done

if [ -z "$RESOURCE_GROUP_DEVICE" ]; then
    RESOURCE_GROUP_DEVICE="$RESOURCE_GROUP_IOT"
fi 

# Check value of POWERSHELL_DISTRIBUTION_CHANNEL. This variable is present in Azure Cloud Shell environment.
# There are different installation steps for Cloud Shell as it does not allow root access to the script
if [ "$IS_CURRENT_ENVIRONMENT_CLOUDSHELL" == "true" ]; then

  if [ -z "$(command -v sshpass)" ]; then

    echo "[INFO] Installing sshpass"
    # Download the sshpass package to current machine
    apt-get download sshpass
    # Install sshpass package in current working directory
    dpkg -x sshpass*.deb ~
    # Add the executable directory path in PATH
    PATH=~/usr/bin:$PATH
    # Remove the package file
    rm sshpass*.deb

    if [ -z "$(command -v sshpass)" ]; then
      printError "sshpass is not installed"
      exit 1
    else
      echo "[INFO] Installed sshpass"
    fi
  fi

  if [[ $(az extension list --query "[?name=='azure-iot'].name" --output tsv | wc -c) -eq 0 ]]; then
    echo "[INFO] Installing azure-iot extension"
    az extension add --name azure-iot
  fi

  # jq and timeout are pre-installed in the cloud shell

elif [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

  if [ ! -z "$(command -v apt)" ]; then
    PACKAGE_MANAGER="apt"
  elif [ ! -z "$(command -v dnf)" ]; then
    PACKAGE_MANAGER="dnf"
  elif [ ! -z "$(command -v yum)" ]; then
    PACKAGE_MANAGER="yum"
  elif [ ! -z "$(command -v zypper)" ]; then
    PACKAGE_MANAGER="zypper"
  fi

  if [ -z "$PACKAGE_MANAGER" ]; then
    echo "[WARNING] The current machine does not have any of the following package managers installed: apt, yum, dnf, zypper."
    echo "[WARNING] Package Installation step is being skipped. Please install the required packages manually"
  else

    echo "[INFO] Installing required packages"

    if [ -z "$(command -v sshpass)" ]; then

      echo "$(info) Installing sshpass"
      sudo "$PACKAGE_MANAGER" install -y sshpass
    fi

    if [ -z "$(command -v jq)" ]; then

      echo "$(info) Installing jq"
      sudo "$PACKAGE_MANAGER" install -y jq
    fi

    if [ -z "$(command -v timeout)" ]; then

      echo "$(info) Installing timeout"
      sudo "$PACKAGE_MANAGER" install -y timeout
      echo "$(info) Installed timeout"
    fi

    if [[ $(az extension list --query "[?name=='azure-iot'].name" --output tsv | wc -c) -eq 0 ]]; then
      echo "[INFO] Installing azure-iot extension"
      az extension add --name azure-iot
    fi

    echo "[INFO] Package Installation step is complete"
  fi
fi

# Getting the details of subscriptions which user has access, in case when value is not provided in variable.template
if [ -z "$SUBSCRIPTION_ID" ]; then
    # Value is empty for SUBSCRIPTION_ID
    # Assign Default value to current subscription
    subscriptions=$(az account list)
    
    SUBSCRIPTION_ID=$(az account list --query "[0].id" -o tsv)
    
    if [ ${#subscriptions[*]} -gt 0 ]; then
        echo "[WARNING] User has access to more than one subscription, by default using first subscription: \"$SUBSCRIPTION_ID\""
    fi
fi

echo "[INFO] Setting current subscription to $SUBSCRIPTION_ID"

az account set --subscription "$SUBSCRIPTION_ID"

echo "[INFO] Set current subscription to $SUBSCRIPTION_ID"

# creating array of resource names if more than one exists in the same resource group
mapfile -t IOTHUB_LIST < <(az iot hub list --resource-group "$RESOURCE_GROUP_IOT" --query "[?name].{Name:name}" --output tsv)
mapfile -t STORAGE_ACCOUNT_LIST < <(az storage account list -g "$RESOURCE_GROUP_IOT" --query "[?name].name" --output tsv)
mapfile -t APP_SERVICE_PLAN_LIST < <(az appservice plan list --resource-group "$RESOURCE_GROUP_IOT" --query "[?name].name" --output tsv)
mapfile -t WEB_APP_LIST < <(az webapp list --resource-group "$RESOURCE_GROUP_IOT" --query "[?name].name" --output tsv)

##  VARIABLES
DISK_NAME="mariner"
VM_NAME="marinervm"
IOTHUB_NAME=$(search "azureeyeiothub" "${IOTHUB_LIST[@]}")
DEVICE_NAME="azureEyeEdgeDevice"
STORAGE_ACCOUNT_NAME=$(search "uesstorage" "${STORAGE_ACCOUNT_LIST[@]}")
APP_SERVICE_PLAN_NAME=$(search "ues-eyeasp" "${APP_SERVICE_PLAN_LIST[@]}")
WEBAPP_NAME=$(search "ues-eyeapp" "${WEB_APP_LIST[@]}")

mapfile -t DEPLOYMENT_NAME_LIST < <(az iot edge deployment list --hub-name "$IOTHUB_NAME" --query "[?id].{Id:id}" --output tsv)
DEPLOYMENT_NAME=$(search "eye-deployment" "${DEPLOYMENT_NAME_LIST[@]}")


# Checks for Mariner VM setup;
if [ "$RUN_VM_CHECKS" == "true" ]; then

  # Check for Resource Group of VM, if it exists with the same name provided in variable template then pass the check else throw error
  if [ "$(az group exists --name "$RESOURCE_GROUP_DEVICE")" == "false" ]; then
    printError "Failed: Resource Group for VM \"$RESOURCE_GROUP_DEVICE\" is not present. "

  else
    echo "Passed: Resource Group for VM \"$RESOURCE_GROUP_DEVICE\" is present"
  fi

  # Check if Mariner Disk is created or not in Resource Group for VM;
  if [ -n "$(az disk list --resource-group "$RESOURCE_GROUP_DEVICE" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$DISK_NAME'].{Name:name}" --output tsv)" ]; then
    echo "Passed: Mariner Disk \"$DISK_NAME\" is present in Resource group \"$RESOURCE_GROUP_DEVICE\"."

  else
    printError "Failed: Mariner Disk \"$DISK_NAME\" is not present in Resource group \"$RESOURCE_GROUP_DEVICE\"."

  fi

  # Check if Mariner VM is created or not in Resource Group for VM;
  if [ -n "$(az vm list --resource-group "$RESOURCE_GROUP_DEVICE" --subscription "$SUBSCRIPTION_ID" --query "[?name=='$VM_NAME'].{Name:name}" --output tsv)" ]; then
    echo "Passed: Mariner VM \"$VM_NAME\" is present in Resource group \"$RESOURCE_GROUP_DEVICE\"."

  else
    printError "Failed: Mariner VM \"$VM_NAME\" is not present in Resource group \"$RESOURCE_GROUP_DEVICE\"."

  fi
fi

# Check for Resource Group of IoT Hub, if it exists with the same name provided in variable template then pass the check else throw error
if [ "$(az group exists -n "$RESOURCE_GROUP_IOT")" = false ]; then
  printError "Failed: Resource Group for IoT Hub \"$RESOURCE_GROUP_IOT\" is not present. "

else
  echo "Passed: Resource Group for IoT Hub \"$RESOURCE_GROUP_IOT\" is present"
fi

# Check for IoT Hub, if it exists with the same name as in variable template then pass the test else throw error
if [ -z "$(az iot hub list --resource-group "$RESOURCE_GROUP_IOT" --query "[?name=='$IOTHUB_NAME'].{Name:name}" -o tsv)" ]; then
  printError "Failed: IoT Hub \"$IOTHUB_NAME\" is not present. "

else

  echo "Passed: IoT Hub \"$IOTHUB_NAME\" is present"
fi

# Retrieve IoT Edge device name to check whether it has been registered on IoT Hub or not
DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)

# Check for IoT Edge Device identity on IoT Hub, if it exists with the same name as in variable template then pass the test else throw error
if [ -z "$DEVICE" ]; then
  printError "Failed: Device \"$DEVICE_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\". "

else

  echo "Passed: Device \"$DEVICE_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""
fi

# Check for Default Route for built-in Event Hub endpoint
EXISTING_DEFAULT_ROUTE=$(az iot hub route list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "[?name=='defaultroute'].name" --output tsv)
if [ -z "$EXISTING_DEFAULT_ROUTE" ]; then
  printError "Failed: Default Route for built-in Event Hub endpoint is not present in IoT Hub \"$IOTHUB_NAME\". "

else

  echo "Passed: Default Route for built-in Event Hub endpoint is present in IoT Hub \"$IOTHUB_NAME\""
fi

# Retrieve the name of Storage account to check if it exists
STORAGE_ACCOUNT=$(az storage account list -g "$RESOURCE_GROUP_IOT" --query "[?name=='$STORAGE_ACCOUNT_NAME'].name" -o tsv)

# Check for Storage account, if it exists with same name as in variable template then pass the test else throw error
if [ -z "$STORAGE_ACCOUNT" ]; then
  printError "Failed: Storage account \"$STORAGE_ACCOUNT_NAME\" is not present. "

else

  echo "Passed: Storage account \"$STORAGE_ACCOUNT_NAME\" is present"
fi

# Retrieve account key to check for container existence
STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_IOT" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" | tr -d '"')

DETECTOR_OUTPUT_CONTAINER_NAME="detectoroutput"
# Retrieve status of container existence
CONTAINER=$(az storage container exists --name "$DETECTOR_OUTPUT_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" -o tsv)

# Check for Container, if it exists with same name as in variable template pass the test else throw error
if [ "$CONTAINER" == "True" ]; then
  echo "Passed: Container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" is present in \"$STORAGE_ACCOUNT_NAME\" Storage account"

else
  printError "Failed: Container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" is not present in \"$STORAGE_ACCOUNT_NAME\" Storage account. "

fi

IMAGES_CONTAINER_NAME="still-images"
# Retrieve status of container existence
CONTAINER=$(az storage container exists --name "$IMAGES_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" -o tsv)

# Check for Container, if it exists with same name as in variable template pass the test else throw error
if [ "$CONTAINER" == "True" ]; then
  echo "Passed: Container \"$IMAGES_CONTAINER_NAME\" is present in \"$STORAGE_ACCOUNT_NAME\" Storage account"

else
  printError "Failed: Container \"$IMAGES_CONTAINER_NAME\" is not present in \"$STORAGE_ACCOUNT_NAME\" Storage account. "

fi

ADLS_ENDPOINT_NAME="adls-endpoint"

# Check for Data Lake Storage endpoint in IoT Hub, if it exists with the same name as in variable template pass the test else throw error
if [ -z "$(az iot hub routing-endpoint list -g "$RESOURCE_GROUP_IOT" --hub-name "$IOTHUB_NAME" --endpoint-type azurestoragecontainer --query "[?name=='$ADLS_ENDPOINT_NAME'].name" -o tsv)" ]; then
  printError "Failed: Data Lake Storage endpoint \"$ADLS_ENDPOINT_NAME\" is not present in IoT Hub \"$IOTHUB_NAME\". "

else

  echo "Passed: Data Lake Storage endpoint \"$ADLS_ENDPOINT_NAME\" is present in IoT Hub \"$IOTHUB_NAME\""
fi

IOTHUB_ADLS_ROUTENAME="adls-route"

# Check for Route to a Data Lake Storage account in IoT Hub, if it exists then pass the test else throw error
if [ -n "$(az iot hub route list -g "$RESOURCE_GROUP_IOT" --hub-name "$IOTHUB_NAME" --query "[?name=='$IOTHUB_ADLS_ROUTENAME'].name" -o tsv)" ]; then
  echo "Passed: Route to a Data Lake Storage account \"$IOTHUB_ADLS_ROUTENAME\" is present in IoT Hub \"$IOTHUB_NAME\" "

else
  printError "Failed: Route to a Data Lake Storage account \"$IOTHUB_ADLS_ROUTENAME\" is not present in IoT Hub \"$IOTHUB_NAME\". "

fi

# Retrieve the deployment details for applied deployments on IoT Hub
DEPLOYMENT_STATUS=$(az iot edge deployment show-metric -m appliedCount --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --metric-type system --query "result" -o tsv)

# Check if the current applied deployment is the one variables.template file, if it is pass the test else throw error
if [ "$DEPLOYMENT_STATUS" == "$DEVICE_NAME" ]; then
  echo "Passed: Deployment is Applied on Edge Device \"$DEVICE_NAME\" "

else
  printError "Failed: Deployment is not Applied on Edge Device \"$DEVICE_NAME\". "

fi

CURRENT_IP_ADDRESS=$(curl -s https://ip4.seeip.org/)

echo "$(info) Adding current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"
NSG_NAME="default-NSG"
# Create a NSG Rule to allow SSH for current machine
az network nsg rule create --name "AllowSSH" --nsg-name "$NSG_NAME" --priority 100 --resource-group "$RESOURCE_GROUP_DEVICE" --destination-port-ranges 22 --source-address-prefixes "$CURRENT_IP_ADDRESS" --output "none"

# Check the status of IoT Edge Service
EDGE_DEVICE_PUBLIC_IP=$(az vm show --show-details --resource-group "$RESOURCE_GROUP_DEVICE" --name "$VM_NAME" --query "publicIps" --output tsv)
EDGE_DEVICE_USERNAME="root"
EDGE_DEVICE_PASSWORD="p@ssw0rd"
# Use sshpass to run the check on a remote device
RUNNING_STATUS_COMMAND="sudo systemctl --type=service --state=running | grep -i \"iotedge\" "
INSTALLATION_STATUS_COMMAND="sudo systemctl --type=service | grep -i \"iotedge\" "

# Check if status of iotedge service is running on Edge Device
RUNNING_STATUS=$(sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_PUBLIC_IP" -o StrictHostKeyChecking=no "$RUNNING_STATUS_COMMAND")

# Check if iotedge service is installed on Edge Device
INSTALLATION_STATUS=$(sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_PUBLIC_IP" -o StrictHostKeyChecking=no "$INSTALLATION_STATUS_COMMAND")

if [ -n "$RUNNING_STATUS" ]; then
  echo "Passed: IoT Edge Service is installed and running on Edge Device"

else
  if [ -n "$INSTALLATION_STATUS" ]; then
    printError "Failed: IoT Edge Service is installed but not running on Edge Device. "

  else

    printError "Failed: IoT Edge Service is not installed on Edge Device. "

  fi
fi

# Retrieve all details of modules configured on Edge device
EDGE_AGENT_TWIN=$(az iot hub module-twin show --module-id "\$edgeAgent" --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME")
# Retrieve names of modules configured on Edge device
DEVICE_MODULES=$(echo "$EDGE_AGENT_TWIN" | jq -r '.properties.desired.modules' | jq -r 'to_entries[].key')
FAILED_STATUS_ARRAY=()

echo "[INFO] Checking modules status"
# Checking the runtimeStatus of each configured module on Edge device from IoT Hub
for DEVICE_MODULE in ${DEVICE_MODULES[*]}; do
  # Count 60 is no. retries for checking status after 2second interval
  for ((i = 1; i <= 60; i++)); do
    # Retrieve all the configured module details on Edge device from IoT Hub
    EDGE_AGENT_TWIN=$(az iot hub module-twin show --module-id "\$edgeAgent" --hub-name "$IOTHUB_NAME" --device-id "$DEVICE_NAME")
    MODULE_STATUS=$(echo "$EDGE_AGENT_TWIN" | jq -r .properties.reported.modules[\""$DEVICE_MODULE"\"].runtimeStatus)

    if [ "$MODULE_STATUS" == "running" ]; then
      break
    else
      sleep 2s
    fi
  done
  if [ "$MODULE_STATUS" != "running" ]; then
    FAILED_STATUS_ARRAY+=("$DEVICE_MODULE")
  fi
done

# Check for module status
# Print Success or Failure based on the length of array:
if [ "${#DEVICE_MODULES[*]}" -gt 0 ] && [ "${#FAILED_STATUS_ARRAY[*]}" -gt 0 ]; then
  printError "Failed: RuntimeStatus of following modules are not running on IoT Hub."
  printf '%s\n' "Modules: ${FAILED_STATUS_ARRAY[*]} "

else
  if [ "${#DEVICE_MODULES[*]}" -gt 0 ]; then
    echo "Passed: RuntimeStatus of following configured modules are running on IoT Hub."
    printf '%s\n' "Modules: ${DEVICE_MODULES[*]}"
  else
    printError "Failed: Modules are not yet configured on IoT Hub. "
  fi
fi

# Retrieve the file names and last modified date for files in data lake container
DETECTOR_OUTPUT_CONTAINER_DATA=$(az storage fs file list -f "$DETECTOR_OUTPUT_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[*].{name:name}" -o table)

# Check for data in data lake, if any files exist in container after setup pass the test else throw error
if [ -n "$DETECTOR_OUTPUT_CONTAINER_DATA" ]; then
  echo "Passed: Data is present in the container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account"
else
  printError "Failed: Data is not present in the container \"$DETECTOR_OUTPUT_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account. "

fi

# Retrieve the file names and last modified date for files in data lake container
IMAGES_CONTAINER_CONTAINER_DATA=$(az storage fs file list -f "$IMAGES_CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_ACCOUNT_KEY" --query "[*].{name:name}" -o table)

# Check for data in data lake, if any files exist in container after setup pass the test else throw error
if [ -n "$IMAGES_CONTAINER_CONTAINER_DATA" ]; then
  echo "Passed: Data is present in the container \"$IMAGES_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account"
else
  printError "Failed: Data is not present in the container \"$IMAGES_CONTAINER_NAME\" of \"$STORAGE_ACCOUNT_NAME\" Storage account. "

fi

# Checks for Frontend app setup in Resource Group:
if [ "$RUN_WEBAPP_CHECKS" == "true" ]; then

  # Check if App Service plan is created or not in Resource Group:
  if [ -n "$(az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "name" -o tsv)" ]; then

    echo "Passed: App Service plan \"$APP_SERVICE_PLAN_NAME\" is present in Resource group \"$RESOURCE_GROUP_IOT\"."

  else
    printError "Failed: App Service plan \"$APP_SERVICE_PLAN_NAME\" is not present in Resource group \"$RESOURCE_GROUP_IOT\". "

  fi

  # Check if Web App is created or not in Resource Group:
  if [ -n "$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "name" -o tsv)" ]; then

    echo "Passed: Web App \"$WEBAPP_NAME\" is present in Resource group \"$RESOURCE_GROUP_IOT\"."
  else

    printError "Failed: Web App \"$WEBAPP_NAME\" is not present in Resource group \"$RESOURCE_GROUP_IOT\". "

  fi
fi

if [ "$ANY_FAILURES_OCCURRED" == "true" ]; then
  printError "There were failures in smoke test checks"
  exit 1
else
  echo "All the checks have passed"
fi