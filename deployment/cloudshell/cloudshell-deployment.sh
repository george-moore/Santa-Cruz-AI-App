#!/bin/bash

# Exit the script on any error
set -e

# This script will automate the cloudShell deployment of all setup scripts for azure resources;
# This script can be run in different scenarios:
# Pass only required arguments to test the deployment-bundle-latest zip in Test storage account
# 	eg: ./cloudshell-deployment.sh --device-runtime "CPU" --website-password "Password" --rg-iot "iotresourcegroup" --rg-vm "vmresourcegroup" --device-architecture "X86"



# SAS URL of DeploymentBundle zip.
SAS_URL="https://unifiededgescenarios.blob.core.windows.net/people-detection/deployment-bundle-latest.zip?sp=r&st=2020-08-12T13:17:07Z&se=2020-12-30T21:17:07Z&spr=https&sv=2019-12-12&sr=b&sig=%2BakjkDanqU5CczPmIVXz3gn8Bu3MWjB0vZ2IEnJoUKE%3D"

PRINT_HELP="false"

printHelp() {
    echo "
    Mandatory Arguments
        --device-runtime        : AI execution hardware: set to 'CPU' for CPU-based dectector in cloud, 'MOVIDIUS' for Intel Myriad X VPU, or 'NVIDIA' to use Nvidia GPU
        --rg-iot                : Resource group name for IoT Hub, Storage Accounts and Web App
        --device-architecture   : Specify the CPU architecture of the Edge Device. Currently supported values are X86 and ARM64
    
    Optional Arguments
        --create-iothub         : Specify if you do not have an existing IoT Edge Device setup on IoT Hub.
        --rg-vm                 : Required if create-iothub is present. Resource group name for Edge Device vm. 
        --iothub-name           : Required if create-iothub is not present. Name of the existing IoT Hub. This IoT Hub must have a existing IoT Edge device setup in it. This IoT Hub must be present in rg-iot resource group.
        --device-name           : Required if create-iothub is not present. Name of the IoT Edge device in the IoT Hub.
        --website-password      : Password to access the web app
        --custom-deployment     : If passed, the script will download the deployment files locally and allow specifying values for all the variables
        --help                  : Show this message and exit
	
    Examples:

    1. Deploy app with existing IoT Edge device
    ./cloudshell-deployment.sh --device-runtime \"CPU\" --website-password \"Password\" --rg-iot \"iotresourcegroup\" --device-architecture \"X86\" --iothub-name \"azureeyeiot\" --device-name \"azureeye\"

    2. Deploy app without existing IoT Edge device
    ./cloudshell-deployment.sh --create-iothub --device-runtime \"CPU\" --website-password \"Password\" --rg-iot \"iotresourcegroup\" --device-architecture \"X86\" --rg-vm \"vmresourcegroup\"

    3. Custom deployment mode
    ./cloudshell-deployment.sh --custom-deployment
    "
}

downloadDeploymentBundle(){
    echo "Downloading deployment bundle zip"
    # Download the latest deployment-bundle.zip from storage account
    wget -O deployment-bundle-latest.zip "$SAS_URL"
    # Extracts all the files from zip in curent directory and overwrite existing ones
    echo "Unzipping the files"
    unzip -o deployment-bundle-latest.zip -d "deployment-bundle-latest"
    echo "Unzipped the files in directory deployment-bundle-latest"
}

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --website-password)
            PASSWORD_FOR_WEBSITE_LOGIN="$2"
            shift # past argument
            shift # past value
            ;;
        --rg-iot)
            RESOURCE_GROUP_IOT="$2"
            shift # past argument
            shift # past value
            ;;
        --device-architecture)
            EDGE_DEVICE_ARCHITECTURE="$2"
            shift # past argument
            shift # past value
            ;;
        --device-runtime)
            DETECTOR_MODULE_RUNTIME="$2"
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
        --create-iothub)
            CREATE_IOTHUB="true"
            shift # past argument
            ;;
        --custom-deployment)
            CUSTOM_DEPLOYMENT="true"
            shift # past argument
            ;;
		--help)
            PRINT_HELP="true"
            shift # past argument
            ;;
        *)    
            # unknown option
            echo "Unknown parameter passed: $1"
            printHelp
            exit 0
            ;;
    esac
done


if [ "$PRINT_HELP" == "true" ]; then
	printHelp
    exit 0
elif [ "$CUSTOM_DEPLOYMENT" == "true" ]; then
    downloadDeploymentBundle
    exit 0
fi

ARRAY_OF_MISSED_PARAMETERS=()
checkValue() {
    
    if [ -z "$2" ]; then
        # If the value is empty, add the variable name ($1) to ARRAY_OF_MISSED_PARAMETERS array 
        ARRAY_OF_MISSED_PARAMETERS+=("$1")
    fi
}

checkValue "--device-runtime" "$DETECTOR_MODULE_RUNTIME"
checkValue "--rg-iot" "$RESOURCE_GROUP_IOT"
checkValue "--device-architecture" "$EDGE_DEVICE_ARCHITECTURE"

if [ "$CREATE_IOTHUB" == "true" ]; then
    checkValue "--rg-vm" "$RESOURCE_GROUP_DEVICE"
else
    checkValue "--iothub-name" "$IOTHUB_NAME"
    checkValue "--device-name" "$DEVICE_NAME"
fi


if [ ${#ARRAY_OF_MISSED_PARAMETERS[*]} -gt 0 ]; then
    echo "Following required parameters are missing from the command: ${ARRAY_OF_MISSED_PARAMETERS[*]}"
    printHelp
    exit 0
fi

# Run downloadDeploymentBundle function to download the bundle zip
downloadDeploymentBundle

cd deployment-bundle-latest


# Update the variable.template file with values passed in arguments

sed -i 's#^\(DETECTOR_MODULE_RUNTIME[ ]*=\).*#\1\"'"$DETECTOR_MODULE_RUNTIME"'\"#g' "variables.template"

sed -i 's#^\(EDGE_DEVICE_ARCHITECTURE[ ]*=\).*#\1\"'"$EDGE_DEVICE_ARCHITECTURE"'\"#g' "variables.template"

sed -i 's#^\(RESOURCE_GROUP_DEVICE[ ]*=\).*#\1\"'"$RESOURCE_GROUP_DEVICE"'\"#g' "variables.template"

sed -i 's#^\(RESOURCE_GROUP_IOT[ ]*=\).*#\1\"'"$RESOURCE_GROUP_IOT"'\"#g' "variables.template"

sed -i 's#^\(PASSWORD_FOR_WEBSITE_LOGIN[ ]*=\).*#\1\"'"$PASSWORD_FOR_WEBSITE_LOGIN"'\"#g' "variables.template"

sed -i 's#^\(IOTHUB_NAME[ ]*=\).*#\1\"'"$IOTHUB_NAME"'\"#g' "variables.template"

sed -i 's#^\(DEVICE_NAME[ ]*=\).*#\1\"'"$DEVICE_NAME"'\"#g' "variables.template"

LOCATION="WEST US 2"

sed -i 's#^\(LOCATION[ ]*=\).*#\1\"'"$LOCATION"'\"#g' "variables.template"

USE_INTERACTIVE_LOGIN_FOR_AZURE="false"

sed -i 's#^\(USE_INTERACTIVE_LOGIN_FOR_AZURE[ ]*=\).*#\1\"'"$USE_INTERACTIVE_LOGIN_FOR_AZURE"'\"#g' "variables.template"

USE_EXISTING_RESOURCES="true"

sed -i 's#^\(USE_EXISTING_RESOURCES[ ]*=\).*#\1\"'"$USE_EXISTING_RESOURCES"'\"#g' "variables.template"

# Read variable values from updated variable.template file
source "variables.template"

# Provide all the script paths to run
VM_SCRIPT_PATH="./eye-vm-setup.sh"
DEPLOY_IOT_SCRIPT_PATH="./deploy-iot.sh"
FRONTEND_SCRIPT_PATH="./frontend-setup.sh"

if [ "$CREATE_IOTHUB" == "true" ]; then 

    # Run your scripts in order:
    printf "\n%60s\n" " " | tr ' ' '-'
    echo "Running Eye VM Setup script"
    printf "%60s\n" " " | tr ' ' '-'

    "$VM_SCRIPT_PATH"

    printf "\n%60s\n" " " | tr ' ' '-'
    echo "Completed Eye VM Setup script"
    printf "%60s\n" " " | tr ' ' '-'

fi

printf "\n%60s\n" " " | tr ' ' '-'
echo "Running Deploy IoT Setup script"
printf "%60s\n" " " | tr ' ' '-'

"$DEPLOY_IOT_SCRIPT_PATH"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Completed Deploy IoT Setup script"
printf "%60s\n" " " | tr ' ' '-'

printf "\n%60s\n" " " | tr ' ' '-'
echo "Running Frontend Setup script"
printf "%60s\n" " " | tr ' ' '-'

"$FRONTEND_SCRIPT_PATH"

printf "\n%60s\n" " " | tr ' ' '-'
echo "Completed Frontend Setup script"
printf "%60s\n" " " | tr ' ' '-'