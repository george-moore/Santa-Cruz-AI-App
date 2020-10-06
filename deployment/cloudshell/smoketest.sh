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

# Define helper function for logging. This will change the Error text color to red
printError() {
  echo "$(tput setaf 1)$1$(tput sgr0)"
  ANY_FAILURES_OCCURRED="true"
}

SETUP_VARIABLES_TEMPLATE_FILENAME="variables.template"

if [ ! -f "$SETUP_VARIABLES_TEMPLATE_FILENAME" ]; then
  printError "\"$SETUP_VARIABLES_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\""
  exit 1
fi

# The following comment is for ignoring the source file check for shellcheck, as it does not support variable source file names currently
# shellcheck source=variables.template
# Read variable values from variables.template file in current directory
source "$SETUP_VARIABLES_TEMPLATE_FILENAME"

if [ -z "$INSTALL_REQUIRED_PACKAGES" ]; then
  INSTALL_REQUIRED_PACKAGES="true" 
fi

# Set the variable value to decide, Whether to perform test for frontend app setup or not, Default is true.
RUN_WEBAPP_CHECKS="true"
# Set the variable value to decide, Whether to perform test for Mariner VM setup or not, Default is true.
RUN_VM_CHECKS="true"

# Check value of INSTALL_REQUIRED_PACKAGES.
# There are different installation steps for Cloud Shell as it does not allow root access to the script
if [ "$INSTALL_REQUIRED_PACKAGES" == "true" ]; then

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
fi

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

echo "[INFO] Setting current subscription to $SUBSCRIPTION_ID"

az account set --subscription "$SUBSCRIPTION_ID"

echo "[INFO] Set current subscription to $SUBSCRIPTION_ID"

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
