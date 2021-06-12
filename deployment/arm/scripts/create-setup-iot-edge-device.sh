#!/bin/bash

# This script creates a new Edge Device in given IoT Hub and connects it to a Existing VM with IoT Edge runtime installed on it.

# Define helper function for logging
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}


echo "Installing packages"

echo "Installing sshpass"
apk add sshpass

echo "Installing iotedgedev"
pip install iotedgedev==2.1.4

echo "Updating az-cli"
pip install --upgrade azure-cli
pip install --upgrade azure-cli-telemetry

echo "installing azure iot extension"
az extension add --name azure-iot

pip3 install --upgrade jsonschema

echo "Installation complete"

# We're enabling exit on error after installation steps as there are some warnings and error thrown in installation steps which causes the script to fail
set -e

CURRENT_IP_ADDRESS=$(curl -s https://ip4.seeip.org/)

echo "$(info) Adding current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"

# Create a NSG Rule to allow SSH for current machine
az network nsg rule create --name "AllowSSH" --nsg-name "$NSG_NAME" --priority 100 --resource-group "$RESOURCE_GROUP_DEVICE" --destination-port-ranges 22 --source-address-prefixes "$CURRENT_IP_ADDRESS" --output "none"

echo "$(info) Added current machine IP address \"$CURRENT_IP_ADDRESS\" in Network Security Group firewall"

# Writing the Edge Device IP address value to variables file 
EDGE_DEVICE_PUBLIC_IP=$(az vm show --show-details --resource-group "$RESOURCE_GROUP_DEVICE" --name "$VM_NAME" --query "publicIps" --output tsv)

EDGE_DEVICE_USERNAME="root"
EDGE_DEVICE_PASSWORD="p@ssw0rd"

echo "The following are the details for the VM"
echo "IP Address: \"$EDGE_DEVICE_PUBLIC_IP\""
echo "Username: \"$EDGE_DEVICE_USERNAME\""
echo "Password: \"$EDGE_DEVICE_PASSWORD\""

# This step creates a new edge device in the IoT Hub account or will use an existing edge device
# if the USE_EXISTING_RESOURCES configuration variable is set to true.
printf "\n%60s\n" " " | tr ' ' '-'
echo "$(info) Configuring Edge Device in IoT Hub"
printf "%60s\n" " " | tr ' ' '-'

# If an Edge Device with given name already exists, use it else create a new one.
EXISTING_IOTHUB_DEVICE=$(az iot hub device-identity list --hub-name "$IOTHUB_NAME" --query "[?deviceId=='$DEVICE_NAME'].deviceId" -o tsv)
if [ -z "$EXISTING_IOTHUB_DEVICE" ]; then
    echo "$(info) Creating \"$DEVICE_NAME\" device in IoT Hub \"$IOTHUB_NAME\""
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
sleep 60
Command="sudo sed -i -e '/device_connection_string:/ s#\"[^\"][^\"]*\"#\"$EDGE_DEVICE_CONNECTION_STRING\"#' $CONFIG_FILE_PATH"
sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_PUBLIC_IP" -o StrictHostKeyChecking=no "$Command"
echo "$(info) Config.yaml update is complete"

echo "$(info) Restarting IoT Edge service"
# Restart the service on Edge device
sshpass -p "$EDGE_DEVICE_PASSWORD" ssh "$EDGE_DEVICE_USERNAME"@"$EDGE_DEVICE_PUBLIC_IP" -o StrictHostKeyChecking=no "sudo systemctl restart iotedge"
echo "$(info) IoT Edge service restart is complete"
