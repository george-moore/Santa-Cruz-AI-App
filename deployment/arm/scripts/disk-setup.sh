#!/bin/bash

# This script uploads the VHD file in an existing Managed Disk 

set -e
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}


CURRENT_DIRECTORY="$PWD"
wget https://aka.ms/downloadazcopy-v10-linux -O downloadazcopy-v10-linux
# unzipping the downloaded archive
tar -xvf downloadazcopy-v10-linux
# changing directory to fetch the azcopy executable
cd azcopy_linux*/
cp azcopy /usr/bin/
cd "$CURRENT_DIRECTORY"

# This is required as the az commands fail in ACI created by deploymentScript
echo "Updating az-cli"
pip install --upgrade azure-cli==2.11.0

echo "Installation complete"


VHD_URI="https://unifiededgescenarios.blob.core.windows.net/aedvhd/aedvhd-dev-1.0.MM5.20200603.2120.v0.0.5.vhd?sp=r&st=2020-09-02T09:41:33Z&se=2021-09-02T17:41:33Z&spr=https&sv=2019-12-12&sr=b&sig=3G5iPXBfC8%2BvBDfR5s5Y8UnSyZJp2u%2F10c4wiMM7lP8%3D"

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