#!/bin/bash

# This script generates a deployment manifest template and deploys it to an existing IoT Edge device

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

SAS_URL="https://unifiededgescenarios.blob.core.windows.net/arm-template/manifest-bundle.zip"


# Download the latest manifest-bundle.zip from storage account
wget -O manifest-bundle.zip "$SAS_URL"

echo "Downloading is done for latest files"

# Extracts all the files from zip in curent directory;
# overwrite existing ones
echo "Unzipping the files"
unzip -o manifest-bundle.zip -d "manifest-bundle"
cd manifest-bundle
echo "Unzipped the files in directory manifest-bundle"

echo "Installing packages"


echo "Installing iotedgedev"
pip install iotedgedev==2.1.4

echo "Updating az-cli"
pip install --upgrade azure-cli
pip install --upgrade azure-cli-telemetry

echo "installing azure iot extension"
az extension add --name azure-iot

pip3 install --upgrade jsonschema
apk add coreutils
echo "Installation complete"

# We're enabling exit on error after installation steps as there are some warnings and error thrown in installation steps which causes the script to fail
set -e


# Check for existence of IoT Hub and Edge device in Resource Group for IoT Hub,
# and based on that either throw error or use the existing resources
if [ -z "$(az iot hub list --query "[?name=='$IOTHUB_NAME'].name" --resource-group "$RESOURCE_GROUP_IOT" -o tsv)" ]; then
    echo "$(error) IoT Hub \"$IOTHUB_NAME\" does not exist."
    exit 1
else
    echo "$(info) Using existing IoT Hub \"$IOTHUB_NAME\""
fi

if [ -z "$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --resource-group "$RESOURCE_GROUP_IOT" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)" ]; then
    echo "$(error) Device \"$DEVICE_NAME\" does not exist in IoT Hub \"$IOTHUB_NAME\""
    exit 1
else
    echo "$(info) Using existing Edge Device \"$IOTHUB_NAME\""
fi


printf "\n%60s\n" " " | tr ' ' '-'
echo "Configuring IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# Retrieve connection string for storage account
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g "$RESOURCE_GROUP_IOT" -n "$STORAGE_ACCOUNT_NAME" --query connectionString -o tsv)

SAS_EXPIRY_DATE=$(date -u -d "1 year" '+%Y-%m-%dT%H:%MZ')
STORAGE_BLOB_SHARED_ACCESS_SIGNATURE=$(az storage account generate-sas --account-name "$STORAGE_ACCOUNT_NAME" --expiry "$SAS_EXPIRY_DATE" --permissions "rwacl" --resource-types "sco" --services "b" --connection-string "$STORAGE_CONNECTION_STRING" --output tsv)
STORAGE_CONNECTION_STRING_WITH_SAS="BlobEndpoint=https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/;SharedAccessSignature=${STORAGE_BLOB_SHARED_ACCESS_SIGNATURE}"



MANIFEST_TEMPLATE_NAME="deployment.camera.template.json"
MANIFEST_ENVIRONMENT_VARIABLES_FILENAME=".env"

if [ "$DETECTOR_MODULE_RUNTIME" == "CPU" ]; then
    MODULE_RUNTIME="runc"
elif [ "$DETECTOR_MODULE_RUNTIME" == "NVIDIA" ]; then
    MODULE_RUNTIME="nvidia"
elif [ "$DETECTOR_MODULE_RUNTIME" == "MOVIDIUS" ]; then
    MODULE_RUNTIME="movidius"
fi

# Update the value of RUNTIME variable in environment variable file
sed -i 's#^\(RUNTIME[ ]*=\).*#\1\"'"$MODULE_RUNTIME"'\"#g' "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"

# Retrieve connection string for storage account
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g "$RESOURCE_GROUP_IOT" -n "$STORAGE_ACCOUNT_NAME" --query connectionString -o tsv)


# Update the value of CAMERA_BLOB_SAS in the environment variable file with the SAS token for the images container
sed -i "s|\(^CAMERA_BLOB_SAS=\).*|CAMERA_BLOB_SAS=\"${STORAGE_CONNECTION_STRING_WITH_SAS//\&/\\\&}\"|g" "$MANIFEST_ENVIRONMENT_VARIABLES_FILENAME"

# This step updates the video stream if specified in the ARM template parameters. This
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

az iot edge deployment create --deployment-id "$DEPLOYMENT_NAME" --hub-name "$IOTHUB_NAME" --content "$PRE_GENERATED_MANIFEST_FILENAME" --target-condition "deviceId='$DEVICE_NAME'" --output "none"

echo "$(info) Deployed manifest file to IoT Hub. Your modules are being deployed to your device now. This may take some time."